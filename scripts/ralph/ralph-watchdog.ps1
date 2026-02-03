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
    - Beads CLI (bd): https://github.com/nicklynch10/beads-cli

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
    [int]$WatchInterval = 60,

    [Parameter()]
    [int]$StaleThreshold = 30,

    [Parameter()]
    [int]$MaxRestarts = 5,

    [Parameter()]
    [switch]$DryRun,

    [Parameter()]
    [switch]$RunOnce
)

#region Prerequisites Check

function Test-Prerequisites {
    $missing = @()
    
    if (-not (Get-Command gt -ErrorAction SilentlyContinue)) {
        $missing += "gt (Gastown CLI)"
    }
    if (-not (Get-Command bd -ErrorAction SilentlyContinue)) {
        $missing += "bd (Beads CLI)"
    }
    
    if ($missing.Count -gt 0) {
        Write-Host "========================================" -ForegroundColor Red
        Write-Host "  MISSING PREREQUISITES                " -ForegroundColor Red
        Write-Host "========================================" -ForegroundColor Red
        Write-Host ""
        Write-Host "The following required tools are missing:" -ForegroundColor Yellow
        foreach ($tool in $missing) {
            Write-Host "  - $tool" -ForegroundColor Red
        }
        Write-Host ""
        Write-Host "Installation:" -ForegroundColor Cyan
        Write-Host "  1. Gastown CLI (gt):" -ForegroundColor White
        Write-Host "     go install github.com/nicklynch10/gastown-cli/cmd/gt@latest" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  2. Beads CLI (bd):" -ForegroundColor White
        Write-Host "     go install github.com/nicklynch10/beads-cli/cmd/bd@latest" -ForegroundColor Gray
        Write-Host ""
        return $false
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
}

#endregion

#region Hook Monitoring

function Get-HookedBeads {
    try {
        # Get all beads with status=hooked
        $hooked = & bd list --status hooked --json 2>&1 | ConvertFrom-Json -ErrorAction SilentlyContinue
        return $hooked
    }
    catch {
        return @()
    }
}

function Get-BeadActivity {
    param([string]$BeadId)
    
    try {
        $bead = & bd show $BeadId --json 2>&1 | ConvertFrom-Json -ErrorAction SilentlyContinue
        
        # Parse ralph_meta for activity
        $meta = @{}
        if ($bead.description -and $bead.description -match "ralph_meta:\s*(\{[^}]+\})") {
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

function Get-AgentSessionStatus {
    param([string]$AgentId)
    
    # Check if agent has active session
    try {
        # Parse agent ID (format: rig/polecats/name or rig/crew/name)
        $parts = $AgentId -split '/'
        if ($parts.Count -lt 2) {
            return @{ IsActive = $false; Reason = "Invalid agent ID format" }
        }
        
        $rig = $parts[0]
        $type = $parts[1]
        $name = if ($parts.Count -ge 3) { $parts[2] } else { "" }
        
        # Check for tmux session (simplified - would need town root detection)
        # This is a placeholder for actual session detection
        return @{ IsActive = $true; Reason = "Session assumed active" }
    }
    catch {
        return @{ IsActive = $false; Reason = "Error: $_" }
    }
}

#endregion

#region Nudge/Restart Logic

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
        
        if (-not $DryRun) {
            $rig = ($AgentId -split '/')[0]
            & gt mail send "$rig/witness" -s "ESCALATION: Max restarts for $BeadId" `
                -m "Bead $BeadId has reached $MaxRestarts restart attempts.`n`nManual intervention required." 2>&1 | Out-Null
        }
        return $false
    }
    
    if ($DryRun) {
        Write-WatchLog "  [DRY RUN] Would restart worker and re-sling $BeadId"
        return $true
    }
    
    try {
        # Get current bead data for re-sling
        $bead = & bd show $BeadId --json 2>&1 | ConvertFrom-Json -ErrorAction SilentlyContinue
        $rig = ($AgentId -split '/')[0]
        
        # Unhook current assignment
        & bd update $BeadId --status=open --assignee="" 2>&1 | Out-Null
        
        # Re-sling to new worker
        & gt sling $BeadId $rig 2>&1
        
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
        return
    }
    
    # Check agent session
    $session = Get-AgentSessionStatus -AgentId $agentId
    
    if (-not $session.IsActive) {
        Write-WatchLog "  Agent session inactive" "WARN"
        Restart-Worker -BeadId $beadId -Activity $Activity -AgentId $agentId
    }
    elseif ($Activity.StaleMinutes -gt ($StaleThreshold * 2)) {
        Write-WatchLog "  Very stale (>2x threshold), restarting" "WARN"
        Restart-Worker -BeadId $beadId -Activity $Activity -AgentId $agentId
    }
    else {
        # Just nudge
        Send-Nudge -BeadId $beadId -Activity $Activity -AgentId $agentId
    }
}

#endregion

#region Main Loop

function Watch-Iteration {
    Write-WatchLog "Scanning hooks..."
    
    $hooked = Get-HookedBeads
    Write-WatchLog "Found $($hooked.Count) hooked beads"
    
    $processed = 0
    $nudged = 0
    $restarted = 0
    
    foreach ($bead in $hooked) {
        $activity = Get-BeadActivity -BeadId $bead.id
        
        if (-not $activity) {
            continue
        }
        
        $processed++
        
        if ($activity.IsStale) {
            Process-StaleHook -Activity $activity
            
            if ($activity.StaleMinutes -gt ($StaleThreshold * 2)) {
                $restarted++
            }
            else {
                $nudged++
            }
        }
    }
    
    Write-WatchLog "Iteration complete: $processed processed, $nudged nudged, $restarted restarted"
}

function Start-Watchdog {
    Write-WatchLog "========================================"
    Write-WatchLog "RALPH WATCHDOG STARTED"
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

# Check prerequisites first
if (-not (Test-Prerequisites)) {
    exit 1
}

Start-Watchdog

#endregion
