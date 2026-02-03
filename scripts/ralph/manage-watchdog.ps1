# Ralph Watchdog Manager
# Run this to check status, start, stop, or restart the watchdog

param(
    [Parameter()]
    [ValidateSet("status", "start", "stop", "restart", "remove")]
    [string]$Action = "status"
)

Write-Host "=== Ralph Watchdog Manager ===" -ForegroundColor Cyan

switch ($Action) {
    "status" {
        $task = Get-ScheduledTask -TaskName "RalphWatchdog" -ErrorAction SilentlyContinue
        if ($task) {
            $taskInfo = Get-ScheduledTaskInfo -TaskName "RalphWatchdog"
            Write-Host "Status: $($task.State)" -ForegroundColor $(if ($task.State -eq "Running") { "Green" } else { "Yellow" })
            Write-Host "Next Run: $($taskInfo.NextRunTime)"
            Write-Host "Last Run: $($taskInfo.LastRunTime)"
            Write-Host "Last Result: $($taskInfo.LastTaskResult)"
        } else {
            Write-Host "RalphWatchdog task not found!" -ForegroundColor Red
        }
    }
    "start" {
        Start-ScheduledTask -TaskName "RalphWatchdog"
        Write-Host "✓ RalphWatchdog started" -ForegroundColor Green
    }
    "stop" {
        Stop-ScheduledTask -TaskName "RalphWatchdog"
        Write-Host "✓ RalphWatchdog stopped" -ForegroundColor Yellow
    }
    "restart" {
        Stop-ScheduledTask -TaskName "RalphWatchdog" -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        Start-ScheduledTask -TaskName "RalphWatchdog"
        Write-Host "✓ RalphWatchdog restarted" -ForegroundColor Green
    }
    "remove" {
        Unregister-ScheduledTask -TaskName "RalphWatchdog" -Confirm:$false
        Write-Host "✓ RalphWatchdog removed" -ForegroundColor Yellow
    }
}

Write-Host "==============================" -ForegroundColor Cyan
