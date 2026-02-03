#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Ralph-Gastown System Health Dashboard

.DESCRIPTION
    Real-time monitoring dashboard showing:
    - Watchdog status and uptime
    - Recent log entries
    - System metrics
    - Alert history
    - Test results

.EXAMPLE
    .\ralph-dashboard.ps1

.EXAMPLE
    .\ralph-dashboard.ps1 -RefreshInterval 10 -ShowHistory
#>

[CmdletBinding()]
param(
    [Parameter()]
    [int]$RefreshInterval = 5,
    
    [Parameter()]
    [switch]$ShowHistory,
    
    [Parameter()]
    [switch]$OneShot
)

function Clear-Screen {
    if ($host.Name -eq 'ConsoleHost') {
        Clear-Host
    }
}

function Write-DashboardHeader {
    param([string]$Title, [System.ConsoleColor]$Color = "Cyan")
    Write-Host "========================================" -ForegroundColor $Color
    Write-Host $Title -ForegroundColor $Color
    Write-Host "========================================" -ForegroundColor $Color
}

function Get-WatchdogStatus {
    try {
        $task = Get-ScheduledTask -TaskName "RalphWatchdog-Production" -ErrorAction SilentlyContinue
        if (-not $task) {
            $task = Get-ScheduledTask -TaskName "RalphWatchdog" -ErrorAction SilentlyContinue
        }
        
        if ($task) {
            $info = Get-ScheduledTaskInfo -TaskName $task.TaskName
            return @{
                Name = $task.TaskName
                State = $task.State
                LastRun = $info.LastRunTime
                NextRun = $info.NextRunTime
                LastResult = $info.LastTaskResult
                IsRunning = ($info.LastTaskResult -eq 0)
            }
        }
    } catch {
        return @{ Error = $_ }
    }
    return $null
}

function Get-RecentLogs {
    param([int]$Lines = 10)
    
    $logFile = ".ralph/logs/watchdog.log"
    if (Test-Path $logFile) {
        return Get-Content $logFile -Tail $Lines
    }
    return @("No log file found")
}

function Get-Metrics {
    $metricsFile = ".ralph/metrics/watchdog-metrics.json"
    if (Test-Path $metricsFile) {
        return Get-Content $metricsFile | ConvertFrom-Json
    }
    return $null
}

function Get-RecentAlerts {
    param([int]$Count = 5)
    
    $alertsDir = ".ralph/alerts"
    if (Test-Path $alertsDir) {
        return Get-ChildItem $alertsDir -Filter "*.json" |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First $Count |
            ForEach-Object {
                $alert = Get-Content $_.FullName | ConvertFrom-Json
                [PSCustomObject]@{
                    Time = [DateTime]::Parse($alert.timestamp).ToString("HH:mm:ss")
                    Severity = $alert.severity
                    Subject = $alert.subject
                }
            }
    }
    return @()
}

function Get-DiskUsage {
    $logDir = ".ralph/logs"
    if (Test-Path $logDir) {
        $size = (Get-ChildItem $logDir -Recurse -File | Measure-Object -Property Length -Sum).Sum
        $count = (Get-ChildItem $logDir -Recurse -File).Count
        return @{
            SizeMB = [math]::Round($size / 1MB, 2)
            FileCount = $count
        }
    }
    return @{ SizeMB = 0; FileCount = 0 }
}

function Show-Dashboard {
    Clear-Screen
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-DashboardHeader -Title "RALPH-GASTOWN SYSTEM DASHBOARD - $timestamp"
    
    # Watchdog Status
    Write-Host ""
    Write-DashboardHeader -Title "WATCHDOG STATUS" -Color "Yellow"
    $status = Get-WatchdogStatus
    if ($status) {
        if ($status.Error) {
            Write-Host "Error: $($status.Error)" -ForegroundColor Red
        } else {
            $stateColor = if ($status.IsRunning) { "Green" } else { "Red" }
            Write-Host "Task:      $($status.Name)" -ForegroundColor White
            Write-Host "State:     $($status.State)" -ForegroundColor $stateColor
            Write-Host "Last Run:  $($status.LastRun)" -ForegroundColor White
            Write-Host "Next Run:  $($status.NextRun)" -ForegroundColor White
            Write-Host "Result:    $(if ($status.IsRunning) { 'SUCCESS' } else { 'FAILED' })" -ForegroundColor $stateColor
        }
    } else {
        Write-Host "No watchdog task found!" -ForegroundColor Red
    }
    
    # Metrics
    Write-Host ""
    Write-DashboardHeader -Title "SYSTEM METRICS" -Color "Yellow"
    $metrics = Get-Metrics
    if ($metrics) {
        $uptime = [math]::Round($metrics.uptime, 2)
        Write-Host "Version:       $($metrics.version)" -ForegroundColor White
        Write-Host "Uptime:        $uptime hours" -ForegroundColor White
        Write-Host "Total Runs:    $($metrics.metrics.Runs)" -ForegroundColor White
        Write-Host "Beads Processed: $($metrics.metrics.BeadsProcessed)" -ForegroundColor White
        Write-Host "Nudges:        $($metrics.metrics.Nudges)" -ForegroundColor White
        Write-Host "Restarts:      $($metrics.metrics.Restarts)" -ForegroundColor White
        Write-Host "Failures:      $($metrics.metrics.Failures)" -ForegroundColor $(if($metrics.metrics.Failures -gt 0){"Red"}else{"Green"})
        Write-Host "Alerts Sent:   $($metrics.metrics.AlertsSent)" -ForegroundColor White
    } else {
        Write-Host "No metrics available" -ForegroundColor Yellow
    }
    
    # Disk Usage
    Write-Host ""
    Write-DashboardHeader -Title "DISK USAGE" -Color "Yellow"
    $usage = Get-DiskUsage
    Write-Host "Log Size:      $($usage.SizeMB) MB" -ForegroundColor White
    Write-Host "Log Files:     $($usage.FileCount)" -ForegroundColor White
    
    # Recent Alerts
    Write-Host ""
    Write-DashboardHeader -Title "RECENT ALERTS" -Color "Yellow"
    $alerts = Get-RecentAlerts -Count 5
    if ($alerts) {
        $alerts | Format-Table -AutoSize | Out-Host
    } else {
        Write-Host "No alerts in last period" -ForegroundColor Green
    }
    
    # Recent Logs
    if ($ShowHistory) {
        Write-Host ""
        Write-DashboardHeader -Title "RECENT LOG ENTRIES" -Color "Yellow"
        $logs = Get-RecentLogs -Lines 10
        $logs | ForEach-Object {
            if ($_ -match "ERROR") {
                Write-Host $_ -ForegroundColor Red
            } elseif ($_ -match "WARN") {
                Write-Host $_ -ForegroundColor Yellow
            } elseif ($_ -match "SUCCESS") {
                Write-Host $_ -ForegroundColor Green
            } else {
                Write-Host $_ -ForegroundColor Gray
            }
        }
    }
    
    # Footer
    Write-Host ""
    Write-Host "Press Ctrl+C to exit" -ForegroundColor DarkGray
    if (-not $OneShot) {
        Write-Host "Refreshing every $RefreshInterval seconds..." -ForegroundColor DarkGray
    }
}

# Main loop
if ($OneShot) {
    Show-Dashboard
} else {
    try {
        while ($true) {
            Show-Dashboard
            Start-Sleep -Seconds $RefreshInterval
        }
    } catch {
        # Clean exit on Ctrl+C
        Write-Host "`nDashboard stopped." -ForegroundColor Yellow
    }
}
