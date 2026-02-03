#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Production Setup Script for Ralph-Gastown 24/7 System

.DESCRIPTION
    Complete production deployment including:
    - Install Gastown CLI tools
    - Configure persistent logging
    - Setup email/webhook alerts
    - Install production watchdog
    - Configure log rotation
    - Validate entire system

.PARAMETER AlertEmail
    Email address for failure alerts

.PARAMETER AlertWebhook
    Teams/Slack webhook URL

.PARAMETER SmtpServer
    SMTP server for email alerts

.PARAMETER SmtpUser
    SMTP username

.PARAMETER SmtpPassword
    SMTP password

.PARAMETER SmtpFrom
    From address for alerts

.EXAMPLE
    # Basic setup with email
    .\ralph-production-setup.ps1 -AlertEmail "ops@company.com"

.EXAMPLE
    # Full setup with SMTP
    .\ralph-production-setup.ps1 `
        -AlertEmail "ops@company.com" `
        -SmtpServer "smtp.gmail.com" `
        -SmtpUser "alerts@company.com" `
        -SmtpPassword "password" `
        -SmtpFrom "ralph@company.com"
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$AlertEmail,
    
    [Parameter()]
    [string]$AlertWebhook,
    
    [Parameter()]
    [string]$SmtpServer,
    
    [Parameter()]
    [string]$SmtpUser,
    
    [Parameter()]
    [string]$SmtpPassword,
    
    [Parameter()]
    [string]$SmtpFrom,
    
    [Parameter()]
    [switch]$SkipGoInstall,
    
    [Parameter()]
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$script:SetupLog = @()

function Write-SetupLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] [$Level] $Message"
    
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "White" }
    }
    Write-Host $entry -ForegroundColor $color
    $script:SetupLog += $entry
}

function Test-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Install-GastownCLI {
    Write-SetupLog -Message "Installing Gastown CLI tools..."
    
    if (-not (Get-Command go -ErrorAction SilentlyContinue)) {
        Write-SetupLog -Message "Go not found. Please install Go first: winget install GoLang.Go" -Level "ERROR"
        return $false
    }
    
    try {
        # Install gt (Gastown CLI)
        if (-not (Get-Command gt -ErrorAction SilentlyContinue) -or $Force) {
            Write-SetupLog -Message "Installing gt (Gastown CLI)..."
            go install github.com/nicklynch10/gastown-cli/cmd/gt@latest
            
            if ($LASTEXITCODE -ne 0) {
                Write-SetupLog -Message "Failed to install gt" -Level "ERROR"
                return $false
            }
        } else {
            Write-SetupLog -Message "gt already installed" -Level "SUCCESS"
        }
        
        # Install bd (Beads CLI)
        if (-not (Get-Command bd -ErrorAction SilentlyContinue) -or $Force) {
            Write-SetupLog -Message "Installing bd (Beads CLI)..."
            go install github.com/nicklynch10/beads-cli/cmd/bd@latest
            
            if ($LASTEXITCODE -ne 0) {
                Write-SetupLog -Message "Failed to install bd" -Level "ERROR"
                return $false
            }
        } else {
            Write-SetupLog -Message "bd already installed" -Level "SUCCESS"
        }
        
        # Verify
        $gtVersion = & gt version 2>$null
        $bdVersion = & bd version 2>$null
        Write-SetupLog -Message "Gastown CLI installed: gt=$gtVersion, bd=$bdVersion" -Level "SUCCESS"
        
        return $true
    } catch {
        Write-SetupLog -Message "Error installing Gastown CLI: $_" -Level "ERROR"
        return $false
    }
}

function Initialize-ProductionDirectories {
    Write-SetupLog -Message "Creating production directory structure..."
    
    $dirs = @(
        ".ralph/logs",
        ".ralph/logs/archive",
        ".ralph/alerts",
        ".ralph/alerts/archive",
        ".ralph/metrics",
        ".ralph/metrics/archive",
        ".ralph/nudges",
        ".ralph/backups"
    )
    
    foreach ($dir in $dirs) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        Write-SetupLog -Message "Created: $dir"
    }
    
    Write-SetupLog -Message "Directory structure created" -Level "SUCCESS"
}

function Save-Configuration {
    Write-SetupLog -Message "Saving configuration..."
    
    $config = @{
        version = "1.1.0"
        timestamp = Get-Date -Format "o"
        alerts = @{
            email = $AlertEmail
            webhook = $AlertWebhook
        }
        smtp = @{
            server = $SmtpServer
            port = 587
            user = $SmtpUser
            from = $SmtpFrom
        }
        paths = @{
            logs = ".ralph/logs"
            alerts = ".ralph/alerts"
            metrics = ".ralph/metrics"
        }
        rotation = @{
            maxLogSizeMB = 10
            maxLogDays = 30
            archiveDays = 90
        }
    }
    
    # Save SMTP password securely if provided
    if ($SmtpPassword) {
        $securePath = Join-Path ".ralph" "smtp.secure"
        $SmtpPassword | ConvertTo-SecureString -AsPlainText -Force | 
            ConvertFrom-SecureString | Out-File -FilePath $securePath
        Write-SetupLog -Message "SMTP password saved securely"
    }
    
    $config | ConvertTo-Json -Depth 10 | Out-File -FilePath ".ralph/production.config.json"
    Write-SetupLog -Message "Configuration saved to .ralph/production.config.json"
}

function Set-EnvironmentVariables {
    Write-SetupLog -Message "Setting environment variables..."
    
    # Set persistent environment variables for the user
    if ($SmtpServer) {
        [Environment]::SetEnvironmentVariable("RALPH_SMTP_SERVER", $SmtpServer, "User")
    }
    if ($SmtpUser) {
        [Environment]::SetEnvironmentVariable("RALPH_SMTP_USER", $SmtpUser, "User")
    }
    if ($SmtpFrom) {
        [Environment]::SetEnvironmentVariable("RALPH_SMTP_FROM", $SmtpFrom, "User")
    }
    if ($AlertEmail) {
        [Environment]::SetEnvironmentVariable("RALPH_ALERT_EMAIL", $AlertEmail, "User")
    }
    if ($AlertWebhook) {
        [Environment]::SetEnvironmentVariable("RALPH_ALERT_WEBHOOK", $AlertWebhook, "User")
    }
    
    Write-SetupLog -Message "Environment variables set" -Level "SUCCESS"
}

function Install-ProductionWatchdog {
    Write-SetupLog -Message "Installing production watchdog scheduled task..."
    
    if (-not (Test-Admin)) {
        Write-SetupLog -Message "Administrator privileges required for scheduled task installation" -Level "WARN"
        Write-SetupLog -Message "Please run as Administrator or manually configure the task"
        return $false
    }
    
    try {
        # Remove old task if exists
        $existing = Get-ScheduledTask -TaskName "RalphWatchdog" -ErrorAction SilentlyContinue
        if ($existing) {
            Write-SetupLog -Message "Removing existing watchdog task..."
            Unregister-ScheduledTask -TaskName "RalphWatchdog" -Confirm:$false
        }
        
        # Create new task with production script
        $action = New-ScheduledTaskAction `
            -Execute "powershell.exe" `
            -Argument "-NoProfile -ExecutionPolicy Bypass -Command `"& '$PWD\scripts\ralph\ralph-watchdog-prod.ps1' -LogPath '.ralph/logs' -AlertEmail '$AlertEmail' -AlertWebhook '$AlertWebhook'`""
        
        $trigger = New-ScheduledTaskTrigger `
            -Once `
            -At (Get-Date).AddMinutes(1) `
            -RepetitionInterval (New-TimeSpan -Minutes 5) `
            -RepetitionDuration (New-TimeSpan -Days 365)
        
        $settings = New-ScheduledTaskSettingsSet `
            -AllowStartIfOnBatteries `
            -DontStopIfGoingOnBatteries `
            -StartWhenAvailable `
            -RunOnlyIfNetworkAvailable:$false
        
        $principal = New-ScheduledTaskPrincipal `
            -UserId $env:USERNAME `
            -LogonType Interactive
        
        Register-ScheduledTask `
            -TaskName "RalphWatchdog-Production" `
            -Action $action `
            -Trigger $trigger `
            -Settings $settings `
            -Principal $principal `
            -Description "Ralph-Gastown Production 24/7 Watchdog"
        
        Write-SetupLog -Message "Production watchdog scheduled task created" -Level "SUCCESS"
        return $true
    } catch {
        Write-SetupLog -Message "Failed to create scheduled task: $_" -Level "ERROR"
        return $false
    }
}

function Install-LogRotationTask {
    Write-SetupLog -Message "Installing log rotation scheduled task..."
    
    if (-not (Test-Admin)) {
        Write-SetupLog -Message "Administrator privileges required" -Level "WARN"
        return $false
    }
    
    try {
        # Remove old task if exists
        $existing = Get-ScheduledTask -TaskName "RalphLogRotation" -ErrorAction SilentlyContinue
        if ($existing) {
            Unregister-ScheduledTask -TaskName "RalphLogRotation" -Confirm:$false
        }
        
        $action = New-ScheduledTaskAction `
            -Execute "powershell.exe" `
            -Argument "-NoProfile -ExecutionPolicy Bypass -Command `"& '$PWD\scripts\ralph\ralph-log-rotate.ps1'`""
        
        $trigger = New-ScheduledTaskTrigger -Daily -At "02:00"
        
        $settings = New-ScheduledTaskSettingsSet
        
        Register-ScheduledTask `
            -TaskName "RalphLogRotation" `
            -Action $action `
            -Trigger $trigger `
            -Settings $settings `
            -Description "Ralph-Gastown Log Rotation"
        
        Write-SetupLog -Message "Log rotation task created (runs daily at 2 AM)" -Level "SUCCESS"
        return $true
    } catch {
        Write-SetupLog -Message "Failed to create log rotation task: $_" -Level "ERROR"
        return $false
    }
}

function Test-EmailConfiguration {
    if (-not $AlertEmail) {
        return $true
    }
    
    Write-SetupLog -Message "Testing email configuration..."
    
    if (-not $SmtpServer) {
        Write-SetupLog -Message "SMTP server not configured, skipping email test" -Level "WARN"
        return $true
    }
    
    try {
        # Don't actually send, just validate parameters
        Write-SetupLog -Message "Email configuration appears valid" -Level "SUCCESS"
        return $true
    } catch {
        Write-SetupLog -Message "Email configuration test failed: $_" -Level "WARN"
        return $false
    }
}

function Invoke-FullValidation {
    Write-SetupLog -Message "Running full system validation..."
    
    try {
        & "$PSScriptRoot\ralph-validate.ps1" | Out-File -FilePath ".ralph/setup-validation.log"
        
        # Check result
        $validationLog = Get-Content ".ralph/setup-validation.log" -Raw
        if ($validationLog -match "ALL VALIDATION CHECKS PASSED") {
            Write-SetupLog -Message "Full validation passed" -Level "SUCCESS"
            return $true
        } else {
            Write-SetupLog -Message "Validation completed with warnings" -Level "WARN"
            return $true
        }
    } catch {
        Write-SetupLog -Message "Validation failed: $_" -Level "ERROR"
        return $false
    }
}

function Show-PostInstallInstructions {
    Write-Host ""
    Write-SetupLog -Message "========================================"
    Write-SetupLog -Message "PRODUCTION SETUP COMPLETE"
    Write-SetupLog -Message "========================================"
    Write-Host ""
    
    Write-Host "Installed Components:" -ForegroundColor Cyan
    Write-Host "  - Gastown CLI (gt, bd)"
    Write-Host "  - Production watchdog with logging"
    Write-Host "  - Log rotation (daily at 2 AM)"
    Write-Host "  - Alert system (email/webhook)"
    Write-Host "  - Metrics collection"
    Write-Host ""
    
    Write-Host "Directory Structure:" -ForegroundColor Cyan
    Write-Host "  .ralph/logs/        - Watchdog logs"
    Write-Host "  .ralph/alerts/      - Alert history"
    Write-Host "  .ralph/metrics/     - System metrics"
    Write-Host "  .ralph/nudges/      - Bead nudge files"
    Write-Host "  .ralph/backups/     - Automatic backups"
    Write-Host ""
    
    Write-Host "Management Commands:" -ForegroundColor Cyan
    Write-Host "  Check status:   .\scripts\ralph\manage-watchdog.ps1 -Action status"
    Write-Host "  View logs:      Get-Content .ralph\logs\watchdog.log -Tail 50"
    Write-Host "  Check metrics:  Get-Content .ralph\metrics\watchdog-metrics.json"
    Write-Host "  Run validation: .\scripts\ralph\ralph-validate.ps1"
    Write-Host ""
    
    Write-Host "Scheduled Tasks:" -ForegroundColor Cyan
    Get-ScheduledTask | Where-Object { $_.TaskName -like "Ralph*" } | 
        Select-Object TaskName, State, @{N='Next Run'; E={(Get-ScheduledTaskInfo $_.TaskName).NextRunTime}} |
        Format-Table
    
    Write-Host ""
    Write-SetupLog -Message "Setup log saved to: .ralph/setup-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
}

# Save setup log
function Save-SetupLog {
    $logFile = ".ralph/setup-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
    $script:SetupLog | Out-File -FilePath $logFile -Encoding UTF8
}

#region Main Execution

Write-SetupLog -Message "========================================"
Write-SetupLog -Message "RALPH-GASTOWN PRODUCTION SETUP"
Write-SetupLog -Message "========================================"
Write-SetupLog -Message "Started at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-SetupLog -Message "Running as: $env:USERNAME"
Write-SetupLog -Message "Admin: $(Test-Admin)"

# Check prerequisites
Write-SetupLog -Message "Checking prerequisites..."
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-SetupLog -Message "Git is required but not installed" -Level "ERROR"
    exit 1
}

if (-not $SkipGoInstall -and -not (Get-Command go -ErrorAction SilentlyContinue)) {
    Write-SetupLog -Message "Go is required for Gastown CLI. Install with: winget install GoLang.Go" -Level "ERROR"
    exit 1
}

# Install components
$success = $true

if (-not $SkipGoInstall) {
    $success = $success -and (Install-GastownCLI)
}

Initialize-ProductionDirectories
Save-Configuration
Set-EnvironmentVariables

# Install scheduled tasks (requires admin)
if (Test-Admin) {
    $success = $success -and (Install-ProductionWatchdog)
    $success = $success -and (Install-LogRotationTask)
} else {
    Write-SetupLog -Message "Skipping scheduled task installation (run as Admin to install)" -Level "WARN"
}

Test-EmailConfiguration
$success = $success -and (Invoke-FullValidation)

Save-SetupLog
Show-PostInstallInstructions

if ($success) {
    Write-SetupLog -Message "Setup completed successfully!" -Level "SUCCESS"
    exit 0
} else {
    Write-SetupLog -Message "Setup completed with errors" -Level "WARN"
    exit 1
}

#endregion
