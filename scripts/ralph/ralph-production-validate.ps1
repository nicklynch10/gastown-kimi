#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Production Validation for Ralph-Gastown System
.DESCRIPTION
    Validates production deployment including CLI, directories, tasks, logging, alerts, metrics
#>

[CmdletBinding()]
param([switch]$Detailed, [switch]$Fix)

$ErrorActionPreference = "Continue"
$script:Passed = 0
$script:Failed = 0
$script:Warnings = 0

function Test-Result {
    param([string]$Category, [string]$Test, [bool]$Passed, [string]$Message = "", [switch]$Warning)
    
    if ($Warning) {
        $script:Warnings++
        $icon = "!"
        $color = "Yellow"
    } elseif ($Passed) {
        $script:Passed++
        $icon = "+"
        $color = "Green"
    } else {
        $script:Failed++
        $icon = "X"
        $color = "Red"
    }
    
    Write-Host "[$icon] $Category - $Test" -ForegroundColor $color
    if ($Message -and $Detailed) {
        Write-Host "    $Message" -ForegroundColor DarkGray
    }
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "PRODUCTION VALIDATION" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Test Gastown CLI
Write-Host "`n--- Gastown CLI ---" -ForegroundColor Yellow
$gt = Get-Command gt -ErrorAction SilentlyContinue
Test-Result -Category "CLI" -Test "gt command" -Passed ($null -ne $gt)
$bd = Get-Command bd -ErrorAction SilentlyContinue
Test-Result -Category "CLI" -Test "bd command" -Passed ($null -ne $bd)

# Test Directories
Write-Host "`n--- Directory Structure ---" -ForegroundColor Yellow
$dirs = @(".ralph", ".ralph/logs", ".ralph/logs/archive", ".ralph/alerts", ".ralph/metrics")
foreach ($dir in $dirs) {
    $exists = Test-Path $dir
    Test-Result -Category "Dir" -Test $dir -Passed $exists
    if (-not $exists -and $Fix) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        Write-Host "  Created: $dir" -ForegroundColor DarkYellow
    }
}

# Test Scheduled Tasks
Write-Host "`n--- Scheduled Tasks ---" -ForegroundColor Yellow
$task = Get-ScheduledTask -TaskName "RalphWatchdog" -ErrorAction SilentlyContinue
Test-Result -Category "Task" -Test "RalphWatchdog" -Passed ($null -ne $task)

# Test Logging
Write-Host "`n--- Logging ---" -ForegroundColor Yellow
$logFile = ".ralph/logs/watchdog.log"
Test-Result -Category "Log" -Test "Main log exists" -Passed (Test-Path $logFile)
$rotateScript = "scripts/ralph/ralph-log-rotate.ps1"
Test-Result -Category "Log" -Test "Rotation script" -Passed (Test-Path $rotateScript)

# Test Scripts
Write-Host "`n--- Core Scripts ---" -ForegroundColor Yellow
$scripts = @("ralph-master.ps1", "ralph-watchdog-prod.ps1", "ralph-log-rotate.ps1", "ralph-dashboard.ps1")
foreach ($script in $scripts) {
    $path = "scripts/ralph/$script"
    $exists = Test-Path $path
    Test-Result -Category "Script" -Test $script -Passed $exists
    
    if ($exists) {
        try {
            $content = Get-Content $path -Raw
            [void][scriptblock]::Create($content)
            Test-Result -Category "Parse" -Test $script -Passed $true
        } catch {
            Test-Result -Category "Parse" -Test $script -Passed $false -Message $_.Exception.Message
        }
    }
}

# Test Metrics
Write-Host "`n--- Metrics ---" -ForegroundColor Yellow
$metricsFile = ".ralph/metrics/watchdog-metrics.json"
Test-Result -Category "Metrics" -Test "Metrics file" -Passed (Test-Path $metricsFile)

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "VALIDATION SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
$total = $script:Passed + $script:Failed + $script:Warnings
Write-Host "Total: $total"
Write-Host "Passed: $script:Passed" -ForegroundColor Green
Write-Host "Failed: $script:Failed" -ForegroundColor $(if($script:Failed -gt 0){"Red"}else{"Green"})
Write-Host "Warnings: $script:Warnings" -ForegroundColor $(if($script:Warnings -gt 0){"Yellow"}else{"Green"})

if ($script:Failed -eq 0) {
    Write-Host "`nPRODUCTION SYSTEM READY" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`nPRODUCTION SYSTEM HAS ISSUES" -ForegroundColor Red
    exit 1
}
