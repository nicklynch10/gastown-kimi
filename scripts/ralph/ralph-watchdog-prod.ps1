#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Ralph Watchdog - PRODUCTION VERSION with logging, alerts, and monitoring

.DESCRIPTION
    Production-ready watchdog with:
    - Persistent logging with rotation
    - Email/Teams/Slack alerts on failure
    - Metrics collection
    - Actual bead processing via Gastown CLI
    - Automatic recovery procedures

.PARAMETER WatchInterval
    Seconds between watchdog scans (default: 300 = 5 minutes)

.PARAMETER StaleThreshold
    Minutes of inactivity before considering a hook stale (default: 30)

.PARAMETER MaxRestarts
    Maximum restarts per bead (default: 5)

.PARAMETER DryRun
    Show what would be done without making changes

.PARAMETER RunOnce
    Run single iteration and exit

.PARAMETER AlertEmail
    Email address for failure alerts

.PARAMETER AlertWebhook
    Teams/Slack webhook URL for notifications

.EXAMPLE
    .\ralph-watchdog-prod.ps1

.EXAMPLE
    .\ralph-watchdog-prod.ps1 -AlertEmail "ops@company.com" -Verbose
#>

[CmdletBinding()]
param(
    [Parameter()]
    [int]$WatchInterval = 300,  # 5 minutes in production

    [Parameter()]
    [int]$StaleThreshold = 30,

    [Parameter()]
    [int]$MaxRestarts = 5,

    [Parameter()]
    [switch]$DryRun,

    [Parameter()]
    [switch]$RunOnce,

    [Parameter()]
    [string]$AlertEmail,

    [Parameter()]
    [string]$AlertWebhook,

    [Parameter()]
    [string]$LogPath = ".ralph/logs",

    [Parameter()]
    [int]$MaxLogSizeMB = 10,

    [Parameter()]
    [int]$MaxLogDays = 7
)

#region Configuration

$script:Version = "1.1.0-PROD"
$script:StartTime = Get-Date

# Determine project root (handle scheduled task context where $PWD may be wrong)
$script:ProjectRoot = $null
if ($PSScriptRoot) {
    # Script is being run from its location
    $script:ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
}
else {
    # Fallback to current directory
    $script:ProjectRoot = $PWD
}

# Make LogPath absolute if relative
if (-not [System.IO.Path]::IsPathRooted($LogPath)) {
    $LogPath = Join-Path $script:ProjectRoot $LogPath
}
$script:Metrics = @{
    Runs = 0
    BeadsProcessed = 0
    Nudges = 0
    Restarts = 0
    Failures = 0
    AlertsSent = 0
}

#endregion

#region Logging

function Initialize-LogDirectory {
    # LogPath is already resolved to absolute in script initialization
    $logDir = $LogPath
    $archiveDir = Join-Path $logDir "archive"
    
    if (-not (Test-Path $logDir)) {
        try {
            New-Item -ItemType Directory -Path $logDir -Force -ErrorAction Stop | Out-Null
        }
        catch {
            Write-Warning "Failed to create log directory '$logDir': $_"
            # Fallback to temp directory
            $logDir = Join-Path $env:TEMP "ralph-logs"
            $archiveDir = Join-Path $logDir "archive"
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
    }
    if (-not (Test-Path $archiveDir)) {
        try {
            New-Item -ItemType Directory -Path $archiveDir -Force -ErrorAction Stop | Out-Null
        }
        catch {
            Write-Warning "Failed to create archive directory '$archiveDir': $_"
        }
    }
    
    return $logDir
}

function Rotate-Logs {
    param([string]$LogDir)
    
    $currentLog = Join-Path $LogDir "watchdog.log"
    $archiveDir = Join-Path $LogDir "archive"
    
    # Check if current log needs rotation
    if (Test-Path $currentLog) {
        $logSize = (Get-Item $currentLog).Length / 1MB
        
        if ($logSize -gt $MaxLogSizeMB) {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $archiveName = "watchdog-$timestamp.log"
            $archivePath = Join-Path $archiveDir $archiveName
            
            Move-Item $currentLog $archivePath -Force
            
            # Compress archived log
            try {
                Compress-Archive -Path $archivePath -DestinationPath "$archivePath.zip" -Force
                Remove-Item $archivePath -Force
            } catch {
                Write-Verbose "Could not compress log: $_"
            }
        }
    }
    
    # Clean old logs
    $cutoff = (Get-Date).AddDays(-$MaxLogDays)
    Get-ChildItem $archiveDir -Filter "watchdog-*.zip" | 
        Where-Object { $_.LastWriteTime -lt $cutoff } |
        Remove-Item -Force
}

function Write-ProdLog {
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [Parameter()]
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS", "METRIC")]
        [string]$Level = "INFO",
        
        [Parameter()]
        [switch]$NoConsole
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Write to console unless suppressed
    if (-not $NoConsole) {
        $color = switch ($Level) {
            "ERROR" { "Red" }
            "WARN" { "Yellow" }
            "SUCCESS" { "Green" }
            "METRIC" { "Cyan" }
            default { "White" }
        }
        Write-Host $logEntry -ForegroundColor $color
    }
    
    # Write to file
    try {
        $logDir = Initialize-LogDirectory
        $logFile = Join-Path $logDir "watchdog.log"
        $logEntry | Out-File -FilePath $logFile -Append -Encoding UTF8
        
        # Also write to level-specific log
        $levelLog = Join-Path $logDir "watchdog-$($Level.ToLower()).log"
        $logEntry | Out-File -FilePath $levelLog -Append -Encoding UTF8
    } catch {
        Write-Warning "Failed to write to log: $_"
    }
}

#endregion

#region Alerting

function Send-Alert {
    param(
        [Parameter(Mandatory)]
        [string]$Subject,
        
        [Parameter(Mandatory)]
        [string]$Body,
        
        [Parameter()]
        [ValidateSet("INFO", "WARNING", "CRITICAL")]
        [string]$Severity = "WARNING"
    )
    
    Write-ProdLog -Message "ALERT: $Subject" -Level "ERROR"
    $script:Metrics.AlertsSent++
    
    # Write to alerts directory (use absolute path)
    $alertsDir = Join-Path $script:ProjectRoot ".ralph/alerts"
    if (-not (Test-Path $alertsDir)) {
        New-Item -ItemType Directory -Path $alertsDir -Force | Out-Null
    }
    $alertFile = Join-Path $alertsDir "alert-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $alert = @{
        timestamp = Get-Date -Format "o"
        severity = $Severity
        subject = $Subject
        body = $Body
    } | ConvertTo-Json
    $alert | Out-File -FilePath $alertFile -Encoding UTF8
    
    # Email alert
    if ($AlertEmail) {
        Send-EmailAlert -To $AlertEmail -Subject $Subject -Body $Body -Severity $Severity
    }
    
    # Webhook alert
    if ($AlertWebhook) {
        Send-WebhookAlert -Url $AlertWebhook -Subject $Subject -Body $Body -Severity $Severity
    }
}

function Send-EmailAlert {
    param(
        [string]$To,
        [string]$Subject,
        [string]$Body,
        [string]$Severity
    )
    
    try {
        # Try to use configured email settings
        $smtpServer = $env:RALPH_SMTP_SERVER
        $smtpPort = $env:RALPH_SMTP_PORT -as [int] -or 587
        $from = $env:RALPH_SMTP_FROM
        
        if ($smtpServer -and $from) {
            $securePassword = ConvertTo-SecureString $env:RALPH_SMTP_PASSWORD -AsPlainText -Force
            $credential = New-Object System.Management.Automation.PSCredential($env:RALPH_SMTP_USER, $securePassword)
            
            Send-MailMessage `
                -SmtpServer $smtpServer `
                -Port $smtpPort `
                -Credential $credential `
                -From $from `
                -To $To `
                -Subject "[RALPH-$Severity] $Subject" `
                -Body $Body `
                -BodyAsHtml:$false
            
            Write-ProdLog -Message "Email alert sent to $To" -Level "INFO"
        } else {
            Write-ProdLog -Message "SMTP not configured, email alert queued" -Level "WARN"
        }
    } catch {
        Write-ProdLog -Message "Failed to send email alert: $_" -Level "ERROR"
    }
}

function Send-WebhookAlert {
    param(
        [string]$Url,
        [string]$Subject,
        [string]$Body,
        [string]$Severity
    )
    
    try {
        $color = switch ($Severity) {
            "CRITICAL" { "ff0000" }
            "WARNING" { "ff9900" }
            default { "0099ff" }
        }
        
        $payload = @{
            text = "Ralph Watchdog Alert"
            attachments = @(@{
                color = $color
                title = $Subject
                text = $Body
                fields = @(
                    @{
                        title = "Severity"
                        value = $Severity
                        short = $true
                    },
                    @{
                        title = "Time"
                        value = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
                        short = $true
                    }
                )
            })
        } | ConvertTo-Json -Depth 10
        
        Invoke-RestMethod -Uri $Url -Method POST -ContentType "application/json" -Body $payload
        Write-ProdLog -Message "Webhook alert sent" -Level "INFO"
    } catch {
        Write-ProdLog -Message "Failed to send webhook alert: $_" -Level "ERROR"
    }
}

#endregion

#region Metrics

function Save-Metrics {
    $metricsDir = Join-Path $script:ProjectRoot ".ralph/metrics"
    if (-not (Test-Path $metricsDir)) {
        New-Item -ItemType Directory -Path $metricsDir -Force | Out-Null
    }
    $metricsFile = Join-Path $metricsDir "watchdog-metrics.json"
    
    $data = @{
        timestamp = Get-Date -Format "o"
        version = $script:Version
        uptime = ((Get-Date) - $script:StartTime).TotalHours
        metrics = $script:Metrics
        config = @{
            watchInterval = $WatchInterval
            staleThreshold = $StaleThreshold
            maxRestarts = $MaxRestarts
        }
    } | ConvertTo-Json -Depth 10
    
    $data | Out-File -FilePath $metricsFile -Encoding UTF8
}

function Write-MetricsLog {
    $uptime = (Get-Date) - $script:StartTime
    Write-ProdLog -Message "METRICS - Runs: $($script:Metrics.Runs), Uptime: $($uptime.ToString('hh\:mm')), Beads: $($script:Metrics.BeadsProcessed), Failures: $($script:Metrics.Failures)" -Level "METRIC"
}

#endregion

#region Bead Processing

function Test-GastownCLI {
    $gt = Get-Command gt -ErrorAction SilentlyContinue
    $bd = Get-Command bd -ErrorAction SilentlyContinue
    
    return ($gt -and $bd)
}

function Get-HookedBeads {
    try {
        if (-not (Test-GastownCLI)) {
            Write-ProdLog -Message "Gastown CLI not available, skipping hook scan" -Level "WARN"
            return @()
        }
        
        $hooks = & gt hooks --json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
        return $hooks
    } catch {
        Write-ProdLog -Message "Error scanning hooks: $_" -Level "ERROR"
        return @()
    }
}

function Test-StaleBead {
    param($Hook)
    
    if (-not $Hook.last_activity) {
        return $true
    }
    
    try {
        $lastActivity = [DateTime]::Parse($Hook.last_activity)
        $staleTime = (Get-Date).AddMinutes(-$StaleThreshold)
        return $lastActivity -lt $staleTime
    } catch {
        return $false
    }
}

function Invoke-Nudge {
    param([string]$BeadId)
    
    Write-ProdLog -Message "Nudging bead $BeadId" -Level "INFO"
    $script:Metrics.Nudges++
    
    if ($DryRun) {
        Write-ProdLog -Message "DRY RUN: Would nudge $BeadId" -Level "WARN"
        return
    }
    
    try {
        # Create nudge file (use absolute path)
        $nudgesDir = Join-Path $script:ProjectRoot ".ralph/nudges"
        if (-not (Test-Path $nudgesDir)) {
            New-Item -ItemType Directory -Path $nudgesDir -Force | Out-Null
        }
        $nudgeFile = Join-Path $nudgesDir "$BeadId-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
        @{
            bead_id = $BeadId
            timestamp = Get-Date -Format "o"
            action = "nudge"
        } | ConvertTo-Json | Out-File -FilePath $nudgeFile
        
        # Attempt to restart worker
        & gt unhook $BeadId 2>$null
        Start-Sleep -Seconds 2
        & gt sling $BeadId 2>$null
        
        Write-ProdLog -Message "Successfully nudged $BeadId" -Level "SUCCESS"
    } catch {
        Write-ProdLog -Message "Failed to nudge $BeadId : $_" -Level "ERROR"
    }
}

function Invoke-Restart {
    param([string]$BeadId, [int]$RestartCount)
    
    $restartMsg = 'Restarting bead {0} (restart #{1})' -f $BeadId, $RestartCount
    Write-ProdLog -Message $restartMsg -Level "WARN"
    $script:Metrics.Restarts++
    
    if ($RestartCount -ge $MaxRestarts) {
        Send-Alert -Subject "Max Restarts Exceeded for $BeadId" -Body "Bead $BeadId has exceeded maximum restart count ($MaxRestarts). Manual intervention required." -Severity "CRITICAL"
        return
    }
    
    if ($DryRun) {
        Write-ProdLog -Message "DRY RUN: Would restart $BeadId" -Level "WARN"
        return
    }
    
    try {
        & gt unhook $BeadId 2>$null
        Start-Sleep -Seconds 5
        & gt sling $BeadId 2>$null
        Write-ProdLog -Message "Successfully restarted $BeadId" -Level "SUCCESS"
    } catch {
        Write-ProdLog -Message "Failed to restart $BeadId : $_" -Level "ERROR"
        $script:Metrics.Failures++
    }
}

#endregion

#region Main Loop

function Invoke-WatchdogIteration {
    Write-ProdLog -Message "========================================" -Level "INFO"
    Write-ProdLog -Message "WATCHDOG ITERATION START - v$script:Version" -Level "INFO"
    Write-ProdLog -Message "========================================" -Level "INFO"
    
    $script:Metrics.Runs++
    
    # Rotate logs if needed
    Rotate-Logs -LogDir (Initialize-LogDirectory)
    
    # Get hooked beads
    $hooks = Get-HookedBeads
    Write-ProdLog -Message "Found $($hooks.Count) hooked beads" -Level "INFO"
    
    $processed = 0
    $nudged = 0
    $restarted = 0
    
    foreach ($hook in $hooks) {
        $beadId = $hook.bead_id
        $script:Metrics.BeadsProcessed++
        $processed++
        
        Write-ProdLog -Message "Processing bead $beadId" -Level "INFO"
        
        # Check if stale
        if (Test-StaleBead -Hook $hook) {
            Write-ProdLog -Message "Bead $beadId is stale (no activity for $StaleThreshold min)" -Level "WARN"
            
            $restartCount = $hook.restart_count -as [int] -or 0
            
            if ($restartCount -eq 0) {
                Invoke-Nudge -BeadId $beadId
                $nudged++
            } else {
                Invoke-Restart -BeadId $beadId -RestartCount $restartCount
                $restarted++
            }
        }
    }
    
    Write-ProdLog -Message "Iteration complete: $processed processed, $nudged nudged, $restarted restarted" -Level "INFO"
    
    # Save metrics
    Save-Metrics
    Write-MetricsLog
    
    # Check for errors and alert
    if ($script:Metrics.Failures -gt 0 -and $script:Metrics.Runs % 12 -eq 0) {
        Send-Alert -Subject "Watchdog Failure Summary" -Body "There have been $($script:Metrics.Failures) failures in the last $($script:Metrics.Runs) runs." -Severity "WARNING"
    }
}

#endregion

#region Initialization

Write-ProdLog -Message "========================================" -Level "INFO"
Write-ProdLog -Message "RALPH WATCHDOG PRODUCTION v$script:Version" -Level "INFO"
Write-ProdLog -Message "========================================" -Level "INFO"
Write-ProdLog -Message "Log Path: $LogPath" -Level "INFO"
Write-ProdLog -Message "Watch Interval: $WatchInterval seconds" -Level "INFO"
Write-ProdLog -Message "Stale Threshold: $StaleThreshold minutes" -Level "INFO"
Write-ProdLog -Message "Dry Run: $DryRun" -Level "INFO"

if ($AlertEmail) {
    Write-ProdLog -Message "Alert Email: $AlertEmail" -Level "INFO"
}
if ($AlertWebhook) {
    Write-ProdLog -Message "Alert Webhook: Configured" -Level "INFO"
}

# Create required directories (use project root for absolute paths)
Initialize-LogDirectory | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $script:ProjectRoot ".ralph/nudges") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $script:ProjectRoot ".ralph/alerts") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $script:ProjectRoot ".ralph/metrics") | Out-Null

# Check Gastown CLI
if (Test-GastownCLI) {
    Write-ProdLog -Message "Gastown CLI detected - Full bead processing enabled" -Level "SUCCESS"
} else {
    Write-ProdLog -Message "Gastown CLI not detected - Running in monitoring mode only" -Level "WARN"
}

#endregion

#region Main Loop

if ($RunOnce) {
    Invoke-WatchdogIteration
} else {
    Write-ProdLog -Message "Starting continuous monitoring loop..." -Level "INFO"
    Write-ProdLog -Message "Press Ctrl+C to stop" -Level "WARN"
    
    while ($true) {
        try {
            Invoke-WatchdogIteration
        } catch {
            Write-ProdLog -Message "CRITICAL ERROR in iteration: $_" -Level "ERROR"
            Send-Alert -Subject "Watchdog Critical Error" -Body "$_`n`nStack Trace: $($_.ScriptStackTrace)" -Severity "CRITICAL"
            $script:Metrics.Failures++
        }
        
        Write-ProdLog -Message "Sleeping for $WatchInterval seconds..." -Level "INFO"
        Start-Sleep -Seconds $WatchInterval
    }
}

#endregion
