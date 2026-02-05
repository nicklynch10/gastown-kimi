#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Sets up the Ralph 24/7 Watchdog as a Windows Scheduled Task.

.DESCRIPTION
    This script installs the RalphWatchdog scheduled task that:
    - Runs every 5 minutes
    - Monitors for stale beads (in_progress > 30 min)
    - Nudges or restarts stuck workers
    - Runs automatically in the background

.PARAMETER Uninstall
    Remove the scheduled task instead of installing it.

.PARAMETER Check
    Just check the status, don't install.

.EXAMPLE
    .\setup-watchdog.ps1
    # Installs the watchdog

.EXAMPLE
    .\setup-watchdog.ps1 -Uninstall
    # Removes the watchdog

.EXAMPLE
    .\setup-watchdog.ps1 -Check
    # Shows current status
#>

[CmdletBinding()]
param(
    [switch]$Uninstall,
    [switch]$Check
)

$TaskName = "RalphWatchdog"
$ErrorActionPreference = "Stop"

# Colors
$Green = "Green"
$Red = "Red"
$Yellow = "Yellow"
$Cyan = "Cyan"

# Get the watchdog script path
$ScriptPath = $MyInvocation.MyCommand.Path
$ScriptDir = Split-Path $ScriptPath -Parent
$WatchdogScript = Join-Path $ScriptDir "ralph-watchdog.ps1"

# Determine project root (parent of scripts/ralph/)
$ProjectRoot = Split-Path (Split-Path $ScriptDir -Parent) -Parent

function Write-Status {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Get-WatchdogStatus {
    try {
        $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop
        $info = $task | Get-ScheduledTaskInfo
        
        Write-Status "`n=== RalphWatchdog Status ===" $Cyan
        Write-Status "Task Name: $($task.TaskName)"
        Write-Status "State: $($task.State)"
        Write-Status "Last Run: $($info.LastRunTime)"
        Write-Status "Next Run: $($info.NextRunTime)"
        Write-Status "Last Result: $($info.LastTaskResult)"
        
        if ($info.LastTaskResult -eq 0) {
            Write-Status "Status: HEALTHY" $Green
        } else {
            Write-Status "Status: ERROR (code $($info.LastTaskResult))" $Red
        }
        
        return $true
    }
    catch {
        Write-Status "Watchdog not installed" $Yellow
        return $false
    }
}

function Install-Watchdog {
    Write-Status "Installing RalphWatchdog scheduled task..." $Cyan
    
    # Check if watchdog script exists
    if (-not (Test-Path $WatchdogScript)) {
        Write-Status "ERROR: Watchdog script not found at: $WatchdogScript" $Red
        exit 1
    }
    
    Write-Status "Found watchdog script: $WatchdogScript"
    
    # Remove existing task if present
    try {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
        Write-Status "Removed existing task" $Yellow
    }
    catch {
        # Task didn't exist
    }
    
    # Create the scheduled task
    try {
        $Action = New-ScheduledTaskAction -Execute "powershell.exe" `
            -Argument "-ExecutionPolicy Bypass -File `"$WatchdogScript`" -RunOnce" `
            -WorkingDirectory $ProjectRoot
        
        # Trigger: Run every 5 minutes indefinitely
        $Trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) `
            -RepetitionInterval (New-TimeSpan -Minutes 5) `
            -RepetitionDuration (New-TimeSpan -Days 3650)
        
        # Settings: Run even on battery, don't stop, start when available
        # Note: -RunOnlyIfNetworkAvailable is a switch (flag), not a boolean parameter.
        # In PowerShell 5.1, switches cannot be set to $false - they are either present ($true) or omitted ($false).
        $Settings = New-ScheduledTaskSettingsSet `
            -AllowStartIfOnBatteries `
            -DontStopIfGoingOnBatteries `
            -StartWhenAvailable
        
        # Principal: Run as current user with highest privileges
        $Principal = New-ScheduledTaskPrincipal `
            -UserId $env:USERNAME `
            -RunLevel Highest
        
        # Register the task (PowerShell 5.1 compatible -Force:$true syntax)
        Register-ScheduledTask -TaskName $TaskName `
            -Action $Action `
            -Trigger $Trigger `
            -Settings $Settings `
            -Principal $Principal `
            -Force:$true | Out-Null
        
        Write-Status "Task registered successfully" $Green
        
        # Start the task now
        Start-ScheduledTask -TaskName $TaskName
        Write-Status "Watchdog started" $Green
        
        # Wait a moment and check status
        Start-Sleep -Seconds 2
        Get-WatchdogStatus
        
        Write-Status "`n=== Setup Complete ===" $Green
        Write-Status "The watchdog will run every 5 minutes automatically."
        Write-Status "It monitors for stale beads and nudges/restarts them."
        Write-Status "`nTo check status: Get-ScheduledTask -TaskName '$TaskName'"
        Write-Status "To stop: Stop-ScheduledTask -TaskName '$TaskName'"
        Write-Status "To remove: Unregister-ScheduledTask -TaskName '$TaskName' -Confirm:`$false"
    }
    catch {
        Write-Status "ERROR: Failed to create scheduled task: $_" $Red
        exit 1
    }
}

function Uninstall-Watchdog {
    Write-Status "Removing RalphWatchdog scheduled task..." $Yellow
    
    try {
        Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction Stop
        Write-Status "Watchdog removed successfully" $Green
    }
    catch {
        Write-Status "ERROR: Failed to remove task: $_" $Red
        exit 1
    }
}

# Main
Write-Status "`n=== Ralph 24/7 Watchdog Setup ===" $Cyan

if ($Check) {
    Get-WatchdogStatus
}
elseif ($Uninstall) {
    Uninstall-Watchdog
}
else {
    Install-Watchdog
}
