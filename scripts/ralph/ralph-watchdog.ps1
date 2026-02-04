#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Ralph Watchdog for Gastown - Always-on nudging and restart system.

.DESCRIPTION
    Monitors hooks for stuck work and nudges/restarts workers:
    1. Scans all hooks for "work assigned but no progress"
    2. Detects stale sessions (no activity for N minutes)
    3. Nudges polite agents that stopped themselves
    4. Restarts workers with fresh context

    This implements Phase 4 of the Ralph-Gastown integration.

    PREREQUISITES:
    - Gastown CLI (gt): https://github.com/nicklynch10/gastown-cli
    - Beads CLI (bd): OPTIONAL - Ralph works in standalone mode

.PARAMETER WatchInterval
    Seconds between watchdog scans (default: 60)

.PARAMETER StaleThreshold
    Minutes of inactivity before considering a hook stale (default: 30)

.PARAMETER MaxRestarts
    Maximum restarts per bead (default: 5)

.PARAMETER DryRun
    Show what would be done without making changes

.EXAMPLE
    .\ralph-watchdog.ps1

.EXAMPLE
    .\ralph-watchdog.ps1 -WatchInterval 30 -StaleThreshold 15 -Verbose
#>

[CmdletBinding()]
param(
    [Parameter()]
    [int]$WatchInterval = 300,  # 5 minutes default

    [Parameter()]
    [int]$StaleThreshold = 30,

    [Parameter()]
    [int]$MaxRestarts = 5,

    [Parameter()]
    [switch]$DryRun,

    [Parameter()]
    [switch]$RunOnce
)

#region Constants

$WATCHDOG_VERSION = "1.1.0"

# Determine project root - use environment variable, PSScriptRoot, or current directory
$ProjectRoot = if ($env:RALPH_PROJECT_ROOT) { 
    $env:RALPH_PROJECT_ROOT 
} elseif ($PSScriptRoot) {
    # Scripts are in scripts/ralph/, so go up two levels
    Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
} else {
    Get-Location
}

$LogDir = Join-Path $ProjectRoot ".ralph\logs"
$MetricsDir = Join-Path $ProjectRoot ".ralph\metrics"
$LogFile = Join-Path $LogDir "watchdog.log"
$MetricsFile = Join-Path $MetricsDir "watchdog-metrics.json"

#endregion

#region Prerequisites Check

function Test-Prerequisites {
    # gt is recommended but not strictly required
    $gt = Get-Command gt -ErrorAction SilentlyContinue
    if (-not $gt) {
        Write-WatchLog "Gastown CLI (gt) not found - some features may be limited" "WARN"
    }
    
    # bd is optional - Ralph works in standalone mode
    $bd = Get-Command bd -ErrorAction SilentlyContinue
    if (-not $bd) {
        Write-WatchLog "Beads CLI (bd) not found - using standalone mode" "INFO"
    }
    
    return $true
}

#endregion

#region Logging

function Write-WatchLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $prefix = "[WATCHDOG]"
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN"  { "Yellow" }
        "NUDGE" { "Cyan" }
        "RESTART" { "Magenta" }
        "SUCCESS" { "Green" }
        default { "White" }
    }
    Write-Host "[$timestamp] $prefix [$Level] $Message" -ForegroundColor $color
    
    # Write to log file with retry for file locking
    $logEntry = "[$timestamp] $prefix [$Level] $Message"
    $maxRetries = 5
    $retryDelay = 100  # milliseconds
    
    # Ensure log directory exists
    if (-not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
    }
    
    for ($i = 0; $i -lt $maxRetries; $i++) {
        try {
            # Use StreamWriter with exclusive access for atomic writes
            $writer = [System.IO.StreamWriter]::new($LogFile, $true)
            $writer.WriteLine($logEntry)
            $writer.Close()
            $writer.Dispose()
            break
        }
        catch {
            if ($i -eq $maxRetries - 1) {
                # Last retry failed, write to console only
                Write-Host "[WARN] Could not write to log file: $_" -ForegroundColor Yellow
            }
            else {
                Start-Sleep -Milliseconds $retryDelay
            }
        }
    }
}

#endregion

#region Metrics

function Get-Metrics {
    if (Test-Path $MetricsFile) {
        try {
            $content = Get-Content $MetricsFile -Raw -Encoding UTF8 | ConvertFrom-Json
            return $content
        }
        catch {
            Write-WatchLog "Failed to load metrics: $_" "WARN"
        }
    }
    
    # Return default metrics
    return @{
        total_runs = 0
        beads_processed = 0
        nudges_sent = 0
        restarts_done = 0
        failures = 0
        last_run = $null
        start_time = (Get-Date -Format "o")
    }
}

function Update-Metrics {
    param(
        [int]$Runs = 0,
        [int]$BeadsProcessed = 0,
        [int]$Nudges = 0,
        [int]$Restarts = 0,
        [int]$Failures = 0
    )
    
    $metrics = Get-Metrics
    
    # Update cumulative counters
    $metrics.total_runs = $metrics.total_runs + $Runs
    $metrics.beads_processed = $metrics.beads_processed + $BeadsProcessed
    $metrics.nudges_sent = $metrics.nudges_sent + $Nudges
    $metrics.restarts_done = $metrics.restarts_done + $Restarts
    $metrics.failures = $metrics.failures + $Failures
    $metrics.last_run = (Get-Date -Format "o")
    $metrics.version = $WATCHDOG_VERSION
    
    # Ensure directory exists
    if (-not (Test-Path $MetricsDir)) {
        New-Item -ItemType Directory -Force -Path $MetricsDir | Out-Null
    }
    
    # Write with retry
    $maxRetries = 5
    for ($i = 0; $i -lt $maxRetries; $i++) {
        try {
            $metrics | ConvertTo-Json -Depth 5 | Out-File -FilePath $MetricsFile -Encoding utf8 -Force
            break
        }
        catch {
            if ($i -eq $maxRetries - 1) {
                Write-WatchLog "Failed to write metrics: $_" "WARN"
            }
            else {
                Start-Sleep -Milliseconds 100
            }
        }
    }
}

#endregion

#region Bead Operations

function Get-LocalBeads {
    $beadsDir = Join-Path $ProjectRoot ".ralph\beads"
    if (-not (Test-Path $beadsDir)) {
        return @()
    }
    
    $beads = @()
    $files = Get-ChildItem -Path $beadsDir -Filter "*.json" -ErrorAction SilentlyContinue
    
    foreach ($file in $files) {
        try {
            $content = Get-Content $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
            $content | Add-Member -NotePropertyName "_source" -NotePropertyValue "local" -Force
            $content | Add-Member -NotePropertyName "_file" -NotePropertyValue $file.FullName -Force
            $beads += $content
        }
        catch {
            Write-WatchLog "Failed to parse bead file $($file.Name): $_" "WARN"
        }
    }
    
    return $beads
}

function Get-HookedBeads {
    # First try local beads
    $localBeads = Get-LocalBeads | Where-Object { $_.status -eq "hooked" -or $_.status -eq "in_progress" }
    
    # Then try bd CLI
    try {
        $bdOutput = & bd list --status hooked --json 2>&1
        if ($LASTEXITCODE -eq 0 -and $bdOutput -and $bdOutput -notmatch "^Error") {
            $bdBeads = $bdOutput | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($bdBeads) {
                return @($localBeads) + @($bdBeads) | Sort-Object id -Unique
            }
        }
    }
    catch {
        # bd CLI failed, use local beads only
    }
    
    return $localBeads
}

function Get-PendingBeads {
    # Get beads that need processing (pending status)
    $localBeads = Get-LocalBeads | Where-Object { $_.status -eq "pending" -or -not $_.status }
    return $localBeads
}

function Get-BeadActivity {
    param([string]$BeadId)
    
    try {
        # Try local file first
        $localBeadPath = Join-Path $ProjectRoot ".ralph\beads\$BeadId.json"
        if (Test-Path $localBeadPath) {
            $bead = Get-Content $localBeadPath -Raw -Encoding UTF8 | ConvertFrom-Json
        }
        else {
            $bead = & bd show $BeadId --json 2>&1 | ConvertFrom-Json -ErrorAction SilentlyContinue
        }
        
        if (-not $bead) {
            return $null
        }
        
        # Parse ralph_meta for activity
        $meta = @{}
        if ($bead.ralph_meta) {
            $meta = $bead.ralph_meta
        }
        elseif ($bead.description -and $bead.description -match "ralph_meta:\s*(\{[^}]+\})") {
            $metaJson = $Matches[1]
            $meta = $metaJson | ConvertFrom-Json -ErrorAction SilentlyContinue
        }
        
        # Get last activity time
        $lastActivity = if ($bead.updated_at) { $bead.updated_at } else { $bead.created_at }
        if ($meta.last_attempt) {
            $lastActivity = $meta.last_attempt
        }
        
        # Calculate staleness
        $lastActivityTime = [DateTime]::Parse($lastActivity)
        $staleMinutes = ([DateTime]::UtcNow - $lastActivityTime).TotalMinutes
        
        return @{
            BeadId = $BeadId
            LastActivity = $lastActivity
            StaleMinutes = $staleMinutes
            IsStale = $staleMinutes -gt $StaleThreshold
            AttemptCount = if ($meta.attempt_count) { $meta.attempt_count } else { 0 }
            Assignee = $bead.assignee
            HasVerifierResults = ($meta.verifier_results -ne $null)
            Status = $bead.status
        }
    }
    catch {
        return $null
    }
}

function Update-BeadStatus {
    param(
        [string]$BeadId,
        [string]$Status,
        [string]$Assignee = $null
    )
    
    $localBeadPath = Join-Path (Join-Path (Join-Path "." ".ralph") "beads") "$BeadId.json"
    if (Test-Path $localBeadPath) {
        try {
            $content = Get-Content $localBeadPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $content | Add-Member -NotePropertyName "status" -NotePropertyValue $Status -Force
            $content | Add-Member -NotePropertyName "last_updated" -NotePropertyValue (Get-Date -Format "o") -Force
            if ($Assignee) {
                $content | Add-Member -NotePropertyName "assignee" -NotePropertyValue $Assignee -Force
            }
            $content | ConvertTo-Json -Depth 10 | Out-File -FilePath $localBeadPath -Encoding utf8 -Force
            Write-WatchLog "Updated bead $BeadId status to: $Status"
        }
        catch {
            Write-WatchLog "Failed to update bead status: $_" "WARN"
        }
    }
}

#endregion

#region Worker Management

function Get-AgentSessionStatus {
    param([string]$AgentId)
    
    # For now, assume sessions are active (would need town root detection for tmux)
    return @{ IsActive = $true; Reason = "Session assumed active" }
}

function Send-Nudge {
    param(
        [string]$BeadId,
        [hashtable]$Activity,
        [string]$AgentId
    )
    
    Write-WatchLog "Nudging $AgentId for $BeadId (stale for $($Activity.StaleMinutes) min)" "NUDGE"
    
    if ($DryRun) {
        Write-WatchLog "  [DRY RUN] Would send nudge to $AgentId"
        return $true
    }
    
    try {
        # Build nudge message
        $nudgeMsg = @"
RALPH WATCHDOG NUDGE

Bead: $BeadId
Stale for: $($Activity.StaleMinutes) minutes
Last attempt: $($Activity.LastActivity)

Please check your hook and continue work.
Run: gt hook
"@

        # Send via gt mail
        $rig = ($AgentId -split '/')[0]
        & gt mail send "$rig/$AgentId" -s "WATCHDOG: Nudge - $BeadId" -m $nudgeMsg 2>&1 | Out-Null
        
        Write-WatchLog "  Nudge sent successfully" "SUCCESS"
        return $true
    }
    catch {
        Write-WatchLog "  Failed to send nudge: $_" "ERROR"
        return $false
    }
}

function Restart-Worker {
    param(
        [string]$BeadId,
        [hashtable]$Activity,
        [string]$AgentId
    )
    
    Write-WatchLog "Restarting worker for $BeadId" "RESTART"
    
    if ($Activity.AttemptCount -ge $MaxRestarts) {
        Write-WatchLog "  Max restarts ($MaxRestarts) reached, escalating to witness" "WARN"
        Update-BeadStatus -BeadId $BeadId -Status "failed"
        
        if (-not $DryRun) {
            $rig = ($AgentId -split '/')[0]
            try {
                & gt mail send "$rig/witness" -s "ESCALATION: Max restarts for $BeadId" `
                    -m "Bead $BeadId has reached $MaxRestarts restart attempts.`n`nManual intervention required." 2>&1 | Out-Null
            }
            catch {
                Write-WatchLog "  Failed to send escalation: $_" "WARN"
            }
        }
        return $false
    }
    
    if ($DryRun) {
        Write-WatchLog "  [DRY RUN] Would restart worker and re-sling $BeadId"
        return $true
    }
    
    try {
        # Unhook current assignment
        Update-BeadStatus -BeadId $BeadId -Status "open" -Assignee ""
        
        # Re-sling to new worker
        $rig = ($AgentId -split '/')[0]
        & gt sling $BeadId $rig 2>&1 | Out-Null
        
        Write-WatchLog "  Worker restarted and bead re-slung" "SUCCESS"
        return $true
    }
    catch {
        Write-WatchLog "  Failed to restart: $_" "ERROR"
        return $false
    }
}

function Process-StaleHook {
    param([hashtable]$Activity)
    
    $beadId = $Activity.BeadId
    $agentId = $Activity.Assignee
    
    Write-WatchLog "Processing stale hook: $beadId assigned to $agentId"
    Write-WatchLog "  Stale for: $($Activity.StaleMinutes) min"
    Write-WatchLog "  Attempts: $($Activity.AttemptCount)"
    
    if (-not $agentId) {
        Write-WatchLog "  No assignee, skipping" "WARN"
        return @{ Action = "none"; Reason = "no_assignee" }
    }
    
    # Check agent session
    $session = Get-AgentSessionStatus -AgentId $agentId
    
    if (-not $session.IsActive) {
        Write-WatchLog "  Agent session inactive" "WARN"
        $result = Restart-Worker -BeadId $beadId -Activity $Activity -AgentId $agentId
        return @{ Action = "restart"; Success = $result; Reason = "inactive_session" }
    }
    elseif ($Activity.StaleMinutes -gt ($StaleThreshold * 2)) {
        Write-WatchLog "  Very stale (>2x threshold), restarting" "WARN"
        $result = Restart-Worker -BeadId $beadId -Activity $Activity -AgentId $agentId
        return @{ Action = "restart"; Success = $result; Reason = "very_stale" }
    }
    else {
        # Just nudge
        $result = Send-Nudge -BeadId $beadId -Activity $Activity -AgentId $agentId
        return @{ Action = "nudge"; Success = $result; Reason = "stale" }
    }
}

function Invoke-ExecutorOnBead {
    param([string]$BeadId)
    
    Write-WatchLog "Invoking executor on bead $BeadId"
    
    if ($DryRun) {
        Write-WatchLog "  [DRY RUN] Would execute: .\scripts\ralph\ralph-executor.ps1 -BeadId $BeadId"
        return @{ Success = $true; Output = "DRY RUN" }
    }
    
    try {
        $executorPath = Join-Path $ProjectRoot "scripts\ralph\ralph-executor.ps1"
        if (-not (Test-Path $executorPath)) {
            Write-WatchLog "  Executor not found at $executorPath" "ERROR"
            return @{ Success = $false; Output = "Executor not found" }
        }
        
        # Mark bead as in_progress before running executor
        Update-BeadStatus -BeadId $BeadId -Status "in_progress"
        
        # Run executor and capture output
        $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $executorPath -BeadId $BeadId 2>&1
        $exitCode = $LASTEXITCODE
        
        if ($exitCode -eq 0) {
            Write-WatchLog "  Executor completed successfully" "SUCCESS"
            Update-BeadStatus -BeadId $BeadId -Status "completed"
            return @{ Success = $true; Output = $output }
        }
        else {
            Write-WatchLog "  Executor failed with exit code $exitCode" "ERROR"
            Write-WatchLog "  Output: $($output -join "`n")" "ERROR"
            Update-BeadStatus -BeadId $BeadId -Status "failed"
            return @{ Success = $false; Output = $output; ExitCode = $exitCode }
        }
    }
    catch {
        Write-WatchLog "  Executor invocation failed: $_" "ERROR"
        Update-BeadStatus -BeadId $BeadId -Status "failed"
        return @{ Success = $false; Output = $_.Exception.Message }
    }
}

#endregion

#region Main Loop

function Watch-Iteration {
    Write-WatchLog "Starting watchdog iteration"
    
    $hooked = Get-HookedBeads
    $pending = Get-PendingBeads
    
    Write-WatchLog "Found $($hooked.Count) hooked/in_progress beads, $($pending.Count) pending beads"
    
    $processed = 0
    $nudged = 0
    $restarted = 0
    $failures = 0
    
    # Process hooked beads (stale detection)
    foreach ($bead in $hooked) {
        $activity = Get-BeadActivity -BeadId $bead.id
        
        if (-not $activity) {
            continue
        }
        
        $processed++
        
        if ($activity.IsStale) {
            $result = Process-StaleHook -Activity $activity
            
            if ($result.Action -eq "restart") {
                $restarted++
            }
            elseif ($result.Action -eq "nudge") {
                $nudged++
            }
        }
        elseif ($activity.Status -eq "hooked" -and $activity.AttemptCount -eq 0) {
            # New hooked bead - try to execute
            $execResult = Invoke-ExecutorOnBead -BeadId $bead.id
            if (-not $execResult.Success) {
                $failures++
            }
        }
    }
    
    # Process pending beads (auto-execute)
    foreach ($bead in $pending) {
        Write-WatchLog "Processing pending bead: $($bead.id)"
        $execResult = Invoke-ExecutorOnBead -BeadId $bead.id
        $processed++
        if (-not $execResult.Success) {
            $failures++
        }
    }
    
    # Update metrics
    Update-Metrics -Runs 1 -BeadsProcessed $processed -Nudges $nudged -Restarts $restarted -Failures $failures
    
    Write-WatchLog "Iteration complete: $processed processed, $nudged nudged, $restarted restarted, $failures failures"
}

function Start-Watchdog {
    Write-WatchLog "========================================"
    Write-WatchLog "RALPH WATCHDOG STARTED v$WATCHDOG_VERSION"
    Write-WatchLog "Watch interval: ${WatchInterval}s"
    Write-WatchLog "Stale threshold: ${StaleThreshold}min"
    Write-WatchLog "Max restarts: $MaxRestarts"
    Write-WatchLog "Dry run: $DryRun"
    Write-WatchLog "========================================"
    
    if ($RunOnce) {
        Watch-Iteration
        return
    }
    
    while ($true) {
        Watch-Iteration
        Write-WatchLog "Sleeping for ${WatchInterval}s..."
        Start-Sleep -Seconds $WatchInterval
    }
}

#endregion

#region Entry Point

# Ensure directories exist
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
}
if (-not (Test-Path $MetricsDir)) {
    New-Item -ItemType Directory -Force -Path $MetricsDir | Out-Null
}

# Check prerequisites first
if (-not (Test-Prerequisites)) {
    exit 1
}

Start-Watchdog

#endregion
