#Requires -Version 5.1
<#
.SYNOPSIS
    Run all Task Manager tests
.DESCRIPTION
    Comprehensive test runner for the Task Manager application.
    Can be invoked as a Ralph verifier.
.EXAMPLE
    .\Run-AllTests.ps1
    
    .\Run-AllTests.ps1 -Verbose
#>

[CmdletBinding()]
param(
    [switch]$PassThru
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  TASK MANAGER TEST SUITE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$testPath = $PSScriptRoot
$modulePath = Join-Path $testPath "..\TaskManager.psm1"

# Verify module exists
if (-not (Test-Path $modulePath)) {
    Write-Error "TaskManager module not found at: $modulePath"
    exit 1
}

# Import module
Write-Host "[INFO] Importing TaskManager module..." -ForegroundColor White
try {
    Import-Module $modulePath -Force -Verbose:$false
    Write-Host "[OK] Module imported successfully" -ForegroundColor Green
} catch {
    Write-Error "Failed to import module: $_"
    exit 1
}

Write-Host ""

# Run tests
$results = @()
$testFiles = Get-ChildItem -Path $testPath -Filter "*.Tests.ps1"

foreach ($testFile in $testFiles) {
    Write-Host "[TEST] Running: $($testFile.Name)" -ForegroundColor Cyan
    
    try {
        $result = Invoke-Pester -Path $testFile.FullName -PassThru 2>&1 | Select-Object -Last 1
        $results += $result
        
        if ($result.FailedCount -eq 0) {
            Write-Host "  [PASS] All $($result.PassedCount) tests passed" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] $($result.FailedCount) of $($result.TotalCount) tests failed" -ForegroundColor Red
        }
    } catch {
        Write-Host "  [ERROR] $_" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  TEST SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$totalPassed = ($results | Measure-Object -Property PassedCount -Sum).Sum
$totalFailed = ($results | Measure-Object -Property FailedCount -Sum).Sum
$totalSkipped = ($results | Measure-Object -Property SkippedCount -Sum).Sum
$totalTests = ($results | Measure-Object -Property TotalCount -Sum).Sum

Write-Host "Total Tests:    $totalTests" -ForegroundColor White
Write-Host "Passed:         $totalPassed" -ForegroundColor Green
Write-Host "Failed:         $totalFailed" -ForegroundColor $(if ($totalFailed -gt 0) { "Red" } else { "Green" })
Write-Host "Skipped:        $totalSkipped" -ForegroundColor Yellow

# Output result
if ($totalFailed -eq 0) {
    Write-Host ""
    Write-Host "[SUCCESS] All tests passed!" -ForegroundColor Green
    if ($PassThru) {
        return $true
    }
    exit 0
} else {
    Write-Host ""
    Write-Host "[FAILURE] Some tests failed!" -ForegroundColor Red
    if ($PassThru) {
        return $false
    }
    exit 1
}
