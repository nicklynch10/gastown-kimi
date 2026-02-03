# 24/7 Zero Human SDLC - Setup Guide

> Complete setup instructions for new machines running the Gastown + Ralph autonomous development system.

---

## Prerequisites

| Tool | Install Command | Verify |
|------|-----------------|--------|
| Git | `winget install Git.Git` | `git --version` |
| Go | `winget install GoLang.Go` | `go version` |
| Kimi CLI | `pip install kimi-cli` | `kimi --version` |
| PowerShell | Included with Windows | `$PSVersionTable.PSVersion` (need 5.1+) |

---

## Quick Start (5 Minutes)

### 1. Clone and Enter Directory

```powershell
git clone https://github.com/nicklynch10/gastown-kimi.git
cd gastown-kimi
```

### 2. Set Kimi API Key

```powershell
# Set permanently (requires new PowerShell window)
[Environment]::SetEnvironmentVariable("KIMI_API_KEY", "your-api-key-here", "User")

# Verify
kimi --version
```

### 3. Build Gastown CLI

```powershell
# Build gt.exe from source
go build -o $env:USERPROFILE\go\bin\gt.exe ./cmd/gt

# Create bd wrapper
@'
@echo off
gt bead %*
'@ | Out-File -FilePath "$env:USERPROFILE\go\bin\bd.cmd" -Encoding ASCII

# Add to PATH if needed
$goBin = "$env:USERPROFILE\go\bin"
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($currentPath -notlike "*$goBin*") {
    [Environment]::SetEnvironmentVariable("Path", "$currentPath;$goBin", "User")
}
```

### 4. Install Watchdog (Scheduled Task)

**Open PowerShell as Administrator**, then run:

```powershell
cd "C:\Users\$env:USERNAME\Desktop\Coding Projects\KimiGasTown"

# Run the setup script
.\scripts\ralph\setup-watchdog.ps1
```

Or manually:

```powershell
# Create scheduled task (runs every 5 minutes)
$watchdogPath = "C:\Users\$env:USERNAME\Desktop\Coding Projects\KimiGasTown\scripts\ralph\ralph-watchdog.ps1"
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"$watchdogPath`" -RunOnce"
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration (New-TimeSpan -Days 3650)
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable $false
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Highest

Register-ScheduledTask -TaskName "RalphWatchdog" -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force

# Start now
Start-ScheduledTask -TaskName "RalphWatchdog"
```

### 5. Verify Everything Works

```powershell
# Run full validation (56 tests)
.\scripts\ralph\ralph-validate.ps1

# Run live material tests (26 tests)
.\scripts\ralph\test\ralph-live-test.ps1

# Run demo application
.\examples\ralph-demo\test.ps1

# Check watchdog status
Get-ScheduledTask -TaskName "RalphWatchdog"
```

---

## Managing the Watchdog

### Check Status
```powershell
Get-ScheduledTask -TaskName "RalphWatchdog"
Get-ScheduledTask -TaskName "RalphWatchdog" | Get-ScheduledTaskInfo
```

### Stop Watchdog
```powershell
Stop-ScheduledTask -TaskName "RalphWatchdog"
```

### Start Watchdog
```powershell
Start-ScheduledTask -TaskName "RalphWatchdog"
```

### Remove Watchdog Completely
```powershell
Unregister-ScheduledTask -TaskName "RalphWatchdog" -Confirm:$false
```

---

## Troubleshooting

### "go: command not found"
```powershell
winget install GoLang.Go
# Restart PowerShell after installation
```

### "kimi: command not found"
```powershell
pip install kimi-cli
# Restart PowerShell after installation
```

### "gt: command not found"
```powershell
# Build it
go build -o $env:USERPROFILE\go\bin\gt.exe ./cmd/gt

# Or add go/bin to PATH manually
$env:Path += ";$env:USERPROFILE\go\bin"
```

### "Execution of scripts is disabled"
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Watchdog task fails to start
Check the task history in Task Scheduler GUI (taskschd.msc), or run manually to see errors:
```powershell
& "C:\Users\$env:USERNAME\Desktop\Coding Projects\KimiGasTown\scripts\ralph\ralph-watchdog.ps1" -RunOnce -Verbose
```

---

## File Locations

| Component | Path |
|-----------|------|
| Ralph Scripts | `scripts/ralph/*.ps1` |
| Ralph Modules | `scripts/ralph/*.psm1` |
| Bead Formulas | `.beads/formulas/*.toml` |
| Demo App | `examples/ralph-demo/` |
| Test Suite | `scripts/ralph/test/*.ps1` |
| gt.exe | `%USERPROFILE%\go\bin\gt.exe` |
| bd.cmd | `%USERPROFILE%\go\bin\bd.cmd` |

---

## What's Running 24/7?

After setup, the **RalphWatchdog** scheduled task:

- Runs every **5 minutes**
- Scans for beads stuck in `in_progress` for > 30 minutes
- Sends "nudges" to stale work
- Restarts workers if they're stuck
- Logs all activity

You don't need to do anything - it runs automatically in the background.

---

## Daily Usage Commands

```powershell
# Check system status
.\scripts\ralph\ralph-master.ps1 -Command status

# Create a new bead (work item)
.\scripts\ralph\ralph-master.ps1 -Command create-bead -Intent "Fix login bug"

# Run executor on a bead
.\scripts\ralph\ralph-master.ps1 -Command run -Bead gt-abc123

# Check governance (gates)
.\scripts\ralph\ralph-master.ps1 -Command govern
```

---

## Need Help?

Run the validation script to check your setup:
```powershell
.\scripts\ralph\ralph-validate.ps1 -Detailed
```

Check the main documentation:
- `README.md` - Overview
- `RALPH_INTEGRATION.md` - Technical details
- `QUICKSTART.md` - Quick reference
