# 24/7 SDLC Setup Guide

> **Configure Ralph-Gastown for continuous 24/7 operation**

This guide walks through setting up a fully automated 24/7 SDLC system that monitors, tests, and manages development work continuously.

## Overview

The 24/7 system consists of:

1. **Watchdog** - Scheduled task that runs every 5 minutes
2. **Gates** - Automated quality checks that block bad code
3. **Patrol** - Continuous testing that finds issues
4. **Beads** - Work items with verifiable Definition of Done

```
+---------------------------------------------------+
|  24/7 RALPH-GASTOWN SYSTEM                        |
+---------------------------------------------------+
|                                                   |
|  +-----------+     +-----------+     +---------+ |
|  | Watchdog  |---->|  Beads    |---->| Executor| |
|  | (5 min)   |     |  (Work)   |     | (DoD)   | |
|  +-----------+     +-----------+     +---------+ |
|       |                                    |      |
|       v                                    v      |
|  +-----------+     +-----------+     +---------+ |
|  |  Patrol   |     |  Gates    |     | Evidence| |
|  | (Tests)   |     | (Quality) |     | (Proof) | |
|  +-----------+     +-----------+     +---------+ |
|                                                   |
+---------------------------------------------------+
```

## Prerequisites

- Windows 10/11
- PowerShell 5.1+
- Administrator access (for scheduled task)
- Gastown CLI (`gt`)
- Beads CLI (`bd`)

## Installation

### 1. Install Watchdog as Scheduled Task

```powershell
# Open PowerShell as Administrator
Set-Location C:\Users\Nick Lynch\Desktop\Coding Projects\KimiGasTown

# Run setup
.\scripts\ralph\setup-watchdog.ps1
```

This creates a Windows Scheduled Task named "RalphWatchdog" that runs every 5 minutes.

### 2. Verify Installation

```powershell
# Check task status
.\scripts\ralph\manage-watchdog.ps1 -Action status

# Expected output:
# Watchdog Status: Running
# Next Run: [timestamp]
```

### 3. Initial Health Check

```powershell
# Run full validation
.\scripts\ralph\ralph-validate.ps1

# Expected: 56/56 tests pass
```

## System Components

### Watchdog Operation

The watchdog performs these actions every 5 minutes:

1. **Scan Hooks** - Find stuck or stale work
2. **Check Gates** - Verify quality gates are green
3. **Nudge Workers** - Restart polite agents that stopped
4. **Escalate** - Alert on persistent failures

### Managing the Watchdog

```powershell
# Check status
.\scripts\ralph\manage-watchdog.ps1 -Action status

# View recent history
.\scripts\ralph\manage-watchdog.ps1 -Action history

# Stop temporarily
.\scripts\ralph\manage-watchdog.ps1 -Action stop

# Restart
.\scripts\ralph\manage-watchdog.ps1 -Action restart

# Disable (removes scheduled task)
.\scripts\ralph\manage-watchdog.ps1 -Action disable
```

### Manual Watchdog Run

```powershell
# Run once for testing (dry run - no changes)
.\scripts\ralph\ralph-watchdog.ps1 -RunOnce -DryRun -Verbose

# Run once with actual changes
.\scripts\ralph\ralph-watchdog.ps1 -RunOnce -Verbose
```

## Creating 24/7 Workflows

### 1. Create a Smoke Test Gate

Gates block feature work if they fail:

```powershell
# Create gate bead
.\scripts\ralph\ralph-master.ps1 -Command create-gate -Type smoke

# Or manually:
bd create --title "[GATE] Smoke Tests" --type gate --priority 0
```

### 2. Create Feature Beads with DoD

```powershell
# Create feature with verifiers
.\scripts\ralph\ralph-master.ps1 -Command create-bead `
    -Intent "Implement user authentication"

# The bead includes:
# - Intent (what to do)
# - DoD verifiers (how to verify)
# - Constraints (max iterations, time budget)
```

### 3. Set Up Patrol (Continuous Testing)

```powershell
# Start patrol molecule
.\scripts\ralph\ralph-master.ps1 -Command patrol -Rig myproject

# Patrol will:
# - Run tests every N minutes
# - Create bug beads on failure
# - Attach screenshots and traces
```

## Monitoring

### Watchdog Logs

```powershell
# View latest log
Get-Content .ralph\logs\watchdog.log -Tail 50

# Search for errors
Select-String -Path .ralph\logs\watchdog.log -Pattern "ERROR"

# View today's log
Get-Content ".ralph\logs\watchdog-$(Get-Date -Format 'yyyyMMdd').log" -Tail 100
```

### System Health Dashboard

```powershell
# Quick status check
.\scripts\ralph\ralph-master.ps1 -Command status

# Governor status (gates and policies)
.\scripts\ralph\ralph-master.ps1 -Command govern
```

### Scheduled Task Monitoring

```powershell
# View task info
Get-ScheduledTask -TaskName "RalphWatchdog" | Get-ScheduledTaskInfo

# View recent runs
Get-WinEvent -FilterHashtable @{
    LogName = 'Microsoft-Windows-TaskScheduler/Operational'
    ID = 102, 103
} -MaxEvents 10 | Select-Object TimeCreated, Message
```

## Configuration

### Watchdog Settings

Edit `scripts/ralph/setup-watchdog.ps1` to customize:

```powershell
# Default settings:
$WatchInterval = 300       # 5 minutes between scans
$StaleThreshold = 30       # 30 minutes until considered stale
$MaxRestarts = 5           # Max restarts per bead
```

### Bead Constraints

Default constraints for beads:

```json
{
  "constraints": {
    "max_iterations": 10,
    "time_budget_minutes": 60,
    "retry_backoff_seconds": 30
  }
}
```

## Troubleshooting

### Watchdog Not Running

```powershell
# Check if task exists
Get-ScheduledTask -TaskName "RalphWatchdog" -ErrorAction SilentlyContinue

# Recreate task
.\scripts\ralph\setup-watchdog.ps1

# Check for PowerShell errors
Get-WinEvent -FilterHashtable @{
    LogName = 'Windows PowerShell'
    Level = 2  # Error
} -MaxEvents 20
```

### High CPU Usage

If watchdog is consuming too much CPU:

```powershell
# Increase scan interval
# Edit setup-watchdog.ps1 and change $WatchInterval to 600 (10 min)

# Restart with new settings
.\scripts\ralph\manage-watchdog.ps1 -Action restart
```

### Stuck Beads

If beads appear stuck:

```powershell
# Manual intervention
.\scripts\ralph\ralph-master.ps1 -Command status

# Check specific bead
bd show gt-<bead-id>

# Unhook if needed
gt unhook gt-<bead-id>
```

### Logs Growing Too Large

```powershell
# Enable log rotation (built-in)
# Logs auto-rotate daily

# Clean old logs
Get-ChildItem .ralph\logs\watchdog-*.log | 
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) } |
    Remove-Item
```

## Best Practices

### 1. Gate Everything

Always create gates before features:

```
1. Create smoke gate
2. Run gate - verify it passes
3. Create feature beads
4. Feature work blocked if gate fails
```

### 2. Small Beads

Keep beads small and focused:

- **Good**: "Add email validation to login form"
- **Bad**: "Implement entire authentication system"

### 3. Fast Verifiers

Keep verifiers under 5 minutes:

```json
{
  "verifiers": [
    { "timeout_seconds": 120 },  // Good
    { "timeout_seconds": 600 }   // Too slow
  ]
}
```

### 4. Evidence Required

Always require evidence:

```json
{
  "dod": {
    "evidence_required": true
  }
}
```

## Recovery Procedures

### Full System Restart

```powershell
# 1. Stop watchdog
.\scripts\ralph\manage-watchdog.ps1 -Action stop

# 2. Clear stuck hooks
$stuck = gt hooks --json | ConvertFrom-Json | Where-Object { $_.stale }
foreach ($hook in $stuck) {
    gt unhook $hook.bead_id
}

# 3. Restart watchdog
.\scripts\ralph\manage-watchdog.ps1 -Action start

# 4. Verify health
.\scripts\ralph\ralph-validate.ps1
```

### Reset All State

```powershell
# WARNING: Destructive - removes all Ralph state
Remove-Item -Recurse -Force .ralph
Remove-Item -Recurse -Force .beads\work
.\scripts\ralph\ralph-master.ps1 -Command init
```

## Performance Tuning

### For Large Projects

```powershell
# Increase watchdog interval
$WatchInterval = 600  # 10 minutes

# Reduce stale threshold
$StaleThreshold = 15  # 15 minutes

# Limit concurrent beads
$MaxConcurrent = 3
```

### For Many Beads

```powershell
# Parallel execution
$Parallel = $true
$MaxParallel = 4

# Prioritize lanes
$LanePriority = @("gate", "bug", "feature")
```

## Security Considerations

### Scheduled Task Permissions

The watchdog task runs as the installing user. To change:

```powershell
# View current principal
Get-ScheduledTask -TaskName "RalphWatchdog" | 
    Select-Object -ExpandProperty Principal

# Change to specific user
$task = Get-ScheduledTask -TaskName "RalphWatchdog"
$task.Principal.UserId = "DOMAIN\User"
$task | Set-ScheduledTask
```

### API Keys

Store sensitive data securely:

```powershell
# Use Windows Credential Manager
# Or environment variables
[Environment]::SetEnvironmentVariable(
    "KIMI_API_KEY", 
    "your-key", 
    "User"
)
```

## Support

### Getting Help

```powershell
# Command help
.\scripts\ralph\ralph-master.ps1 -Command help

# Validation with details
.\scripts\ralph\ralph-validate.ps1 -Detailed

# Check prerequisites
.\scripts\ralph\ralph-prereq-check.ps1
```

### Documentation

- [Quick Start](QUICKSTART.md)
- [Integration Guide](../reference/RALPH_INTEGRATION.md)
- [API Reference](../reference/KIMI_INTEGRATION.md)
- [Troubleshooting](../../AGENTS.md#troubleshooting)

---

**Version:** 1.0.0  
**Last Updated:** 2026-02-03
