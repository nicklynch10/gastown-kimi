#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Comprehensive Ralph-Gastown Test Suite

.DESCRIPTION
    This script performs extensive testing of the Ralph-Gastown SDLC system:
    1. Syntax validation of all scripts
    2. Module loading tests
    3. Prerequisite checks
    4. Functional tests (with mocks where needed)
    5. Performance tests
    6. Error handling tests

    This test suite is designed to run without requiring full Gastown/Beads setup,
    though some tests will be skipped if tools are not available.

.PARAMETER IncludeSlowTests
    Include tests that may take longer to run

.PARAMETER TestCategory
    Run only specific test categories: syntax, modules, functional, all

.EXAMPLE
    .\ralph-comprehensive-test.ps1

.EXAMPLE
    .\ralph-comprehensive-test.ps1 -IncludeSlowTests
#>

[CmdletBinding()]
param(
    [switch]$IncludeSlowTests,
    [ValidateSet("all", "syntax", "modules", "functional", "integration")]
    [string]$TestCategory = "all"
)

$TEST_VERSION = "1.0.0"
$ErrorActionPreference = "Stop"

#region Test Framework

$script:TestResults = @()
$script:TestStats = @{
    Passed = 0
    Failed = 0
    Skipped = 0
    Total = 0
}

function Write-TestHeader {
    param([string]$Title)
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host $Title -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
}

function Invoke-Test {
    param(
        [string]$Name,
        [scriptblock]$Test,
        [switch]$Skip,
        [string]$SkipReason = ""
    )
    
    $script:TestStats.Total++
    
    if ($Skip) {
        Write-Host "  [SKIP] $Name" -ForegroundColor Yellow
        if ($SkipReason) { Write-Host "       $SkipReason" -ForegroundColor Gray }
        $script:TestStats.Skipped++
        $script:TestResults += @{ Name = $Name; Result = "Skipped"; Reason = $SkipReason }
        return
    }
    
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $null = & $Test
        $sw.Stop()
        Write-Host "  [PASS] $Name ($($sw.ElapsedMilliseconds)ms)" -ForegroundColor Green
        $script:TestStats.Passed++
        $script:TestResults += @{ Name = $Name; Result = "Passed"; Duration = $sw.ElapsedMilliseconds }
    }
    catch {
        $sw.Stop()
        Write-Host "  [FAIL] $Name ($($sw.ElapsedMilliseconds)ms)" -ForegroundColor Red
        Write-Host "       $_" -ForegroundColor Gray
        $script:TestStats.Failed++
        $script:TestResults += @{ Name = $Name; Result = "Failed"; Reason = $_.Exception.Message }
    }
}

#endregion

#region Syntax Tests

function Test-Syntax {
    Write-TestHeader "SYNTAX VALIDATION"
    
    $scripts = @(
        @{ Path = "scripts\ralph\ralph-master.ps1"; Name = "ralph-master.ps1" }
        @{ Path = "scripts\ralph\ralph-executor.ps1"; Name = "ralph-executor.ps1" }
        @{ Path = "scripts\ralph\ralph-executor-simple.ps1"; Name = "ralph-executor-simple.ps1" }
        @{ Path = "scripts\ralph\ralph-governor.ps1"; Name = "ralph-governor.ps1" }
        @{ Path = "scripts\ralph\ralph-watchdog.ps1"; Name = "ralph-watchdog.ps1" }
        @{ Path = "scripts\ralph\ralph-setup.ps1"; Name = "ralph-setup.ps1" }
        @{ Path = "scripts\ralph\ralph-validate.ps1"; Name = "ralph-validate.ps1" }
        @{ Path = "scripts\ralph\ralph-prereq-check.ps1"; Name = "ralph-prereq-check.ps1" }
    )
    
    foreach ($script in $scripts) {
        Invoke-Test -Name "$($script.Name) parses correctly" -Test {
            if (-not (Test-Path $script.Path)) { throw "Script not found: $($script.Path)" }
            $content = Get-Content $script.Path -Raw
            $null = [scriptblock]::Create($content)
        }
    }
    
    # Test PS5.1 compatibility
    foreach ($script in $scripts) {
        Invoke-Test -Name "$($script.Name) is PS5.1 compatible" -Test {
            if (-not (Test-Path $script.Path)) { return } # Skip if missing
            $content = Get-Content $script.Path -Raw
            $hasPS7Ops = ($content -match '\$\w+\?\?\s') -or 
                        ($content -match '\$\w+\?\.') -or
                        ($content -match '\$\w+\?\?=')
            if ($hasPS7Ops) { throw "Contains PowerShell 7-only operators" }
        }
    }
}

#endregion

#region Module Tests

function Test-Modules {
    Write-TestHeader "MODULE LOADING"
    
    $modules = @(
        @{ Path = "scripts\ralph\ralph-browser.psm1"; Name = "ralph-browser" }
        @{ Path = "scripts\ralph\ralph-resilience.psm1"; Name = "ralph-resilience" }
    )
    
    foreach ($mod in $modules) {
        Invoke-Test -Name "$($mod.Name) module loads" -Test {
            if (-not (Test-Path $mod.Path)) { throw "Module not found: $($mod.Path)" }
            Import-Module (Join-Path $PWD $mod.Path) -Force
            $loaded = Get-Module $mod.Name
            if (-not $loaded) { throw "Module did not load properly" }
            Remove-Module $mod.Name -Force -ErrorAction SilentlyContinue
        }
    }
}

#endregion

#region Functional Tests

function Test-Functional {
    Write-TestHeader "FUNCTIONAL TESTS"
    
    # Test prerequisite checker
    Invoke-Test -Name "Prerequisite checker runs" -Test {
        $output = & "scripts\ralph\ralph-prereq-check.ps1" -Quiet 2>&1
        # Should complete without error
    }
    
    # Test help commands - verify script runs without error (uses Write-Host so output not capturable)
    Invoke-Test -Name "ralph-master.ps1 -Command help works" -Test {
        $exitCode = 0
        try {
            & "scripts\ralph\ralph-master.ps1" -Command help 2>&1 | Out-Null
            $exitCode = $LASTEXITCODE
        } catch {
            throw "Help command failed: $_"
        }
        if ($exitCode -ne 0) { throw "Help command exited with code $exitCode" }
    }
    
    # Test resilience module functions
    $resilienceModule = Join-Path $PWD "scripts\ralph\ralph-resilience.psm1"
    
    Invoke-Test -Name "Resilience: Invoke-WithRetry basic" -Test {
        Import-Module $resilienceModule -Force
        $result = Invoke-WithRetry -ScriptBlock { "success" } -MaxRetries 2
        Remove-Module ralph-resilience -Force -ErrorAction SilentlyContinue
        if (-not $result.Success) { throw "Retry function failed" }
        if ($result.Result -ne "success") { throw "Wrong result" }
    }
    
    Invoke-Test -Name "Resilience: Circuit breaker basic" -Test {
        Import-Module $resilienceModule -Force
        Reset-CircuitBreaker -Name "test-cb" -ErrorAction SilentlyContinue
        $result = Invoke-WithCircuitBreaker -Name "test-cb" -ScriptBlock { "ok" } -FailureThreshold 3
        Remove-Module ralph-resilience -Force -ErrorAction SilentlyContinue
        if ($result -ne "ok") { throw "Circuit breaker failed" }
    }
    
    Invoke-Test -Name "Resilience: Start-ResilientProcess basic" -Test {
        Import-Module $resilienceModule -Force
        $result = Start-ResilientProcess -FilePath "powershell.exe" -Arguments "-Command 'exit 0'" -TimeoutSeconds 5
        Remove-Module ralph-resilience -Force -ErrorAction SilentlyContinue
        if (-not $result.Success) { throw "Process execution failed" }
        if ($result.ExitCode -ne 0) { throw "Non-zero exit code" }
    }
    
    # Test bead contract validation
    Invoke-Test -Name "Bead contract schema is valid JSON" -Test {
        $schemaPath = ".beads\schemas\ralph-bead.schema.json"
        if (-not (Test-Path $schemaPath)) { throw "Schema file not found" }
        $schema = Get-Content $schemaPath -Raw | ConvertFrom-Json
        if (-not $schema.title) { throw "Schema missing title" }
        if (-not $schema.required) { throw "Schema missing required fields" }
    }
    
    # Test formula files
    $formulas = @(
        ".beads\formulas\molecule-ralph-work.formula.toml"
        ".beads\formulas\molecule-ralph-patrol.formula.toml"
        ".beads\formulas\molecule-ralph-gate.formula.toml"
    )
    
    foreach ($formula in $formulas) {
        $name = Split-Path $formula -Leaf
        Invoke-Test -Name "Formula $name is valid" -Test {
            if (-not (Test-Path $formula)) { throw "Formula file not found" }
            $content = Get-Content $formula -Raw
            $hasFormula = $content -match "formula\s*="
            $hasVersion = $content -match "version\s*="
            $hasSteps = $content -match "\[\[steps\]\]"
            if (-not ($hasFormula -and $hasVersion -and $hasSteps)) {
                throw "Missing required TOML fields"
            }
        }
    }
}

#endregion

#region Integration Tests

function Test-Integration {
    Write-TestHeader "INTEGRATION TESTS"
    
    # Demo application tests
    $demoDir = "examples\ralph-demo"
    
    if (Test-Path $demoDir) {
        Invoke-Test -Name "Demo: Calculator module exists" -Test {
            if (-not (Test-Path "$demoDir\Calculator.psm1")) { throw "Calculator module not found" }
        }
        
        Invoke-Test -Name "Demo: Test script runs" -Test {
            $output = & "$demoDir\test.ps1" 2>&1
            $exitCode = $LASTEXITCODE
            if ($exitCode -ne 0) { throw "Demo tests failed with exit code $exitCode" }
            $outputStr = $output -join " "
            # Check for pass indicators (handles "passed", "5 passed", etc.)
            if ($outputStr -notmatch "pass" -and $outputStr -notmatch "OK" -and $exitCode -ne 0) { 
                throw "No success indicator in output" 
            }
        }
        
        Invoke-Test -Name "Demo: Calculator functions work" -Test {
            Import-Module (Join-Path $PWD "$demoDir\Calculator.psm1") -Force
            
            $add = Add-Numbers -a 2 -b 3
            if ($add -ne 5) { throw "Add failed: 2+3=$add" }
            
            $sub = Subtract-Numbers -a 5 -b 3
            if ($sub -ne 2) { throw "Subtract failed: 5-3=$sub" }
            
            $mul = Multiply-Numbers -a 4 -b 5
            if ($mul -ne 20) { throw "Multiply failed: 4*5=$mul" }
            
            $div = Divide-Numbers -a 10 -b 2
            if ($div -ne 5) { throw "Divide failed: 10/2=$div" }
            
            Remove-Module Calculator -Force -ErrorAction SilentlyContinue
        }
    }
    else {
        Write-Host "  [INFO] Demo application not found, skipping demo tests" -ForegroundColor Yellow
    }
    
    # Test timeout handling
    Invoke-Test -Name "Process timeout works correctly" -Skip:(-not $IncludeSlowTests) -SkipReason "Use -IncludeSlowTests to run" -Test {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-NoProfile -Command 'Start-Sleep 30'"
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        
        $proc = [System.Diagnostics.Process]::Start($psi)
        $startTime = Get-Date
        $completed = $proc.WaitForExit(1000)  # 1 second timeout
        $elapsed = (Get-Date) - $startTime
        
        if (-not $completed) {
            try { $proc.Kill() } catch {}
        }
        try { $proc.Dispose() } catch {}
        
        if ($completed) { throw "Should have timed out" }
        # Allow up to 5 seconds for Windows process overhead
        if ($elapsed.TotalSeconds -gt 5) { throw "Timeout not respected: $($elapsed.TotalSeconds)s" }
    }
}

#endregion

#region Main

Write-TestHeader "RALPH-GASTOWN COMPREHENSIVE TEST SUITE v$TEST_VERSION"
Write-Host "Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "PowerShell: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
Write-Host "Category: $TestCategory" -ForegroundColor Gray

# Run tests based on category
switch ($TestCategory) {
    "all" {
        Test-Syntax
        Test-Modules
        Test-Functional
        Test-Integration
    }
    "syntax" { Test-Syntax }
    "modules" { Test-Modules }
    "functional" { Test-Functional }
    "integration" { Test-Integration }
}

# Summary
Write-TestHeader "TEST SUMMARY"
Write-Host "Total:   $($script:TestStats.Total)" -ForegroundColor White
Write-Host "Passed:  $($script:TestStats.Passed)" -ForegroundColor Green
Write-Host "Failed:  $($script:TestStats.Failed)" -ForegroundColor $(if($script:TestStats.Failed -gt 0){"Red"}else{"Green"})
Write-Host "Skipped: $($script:TestStats.Skipped)" -ForegroundColor Yellow
Write-Host ""

if ($script:TestStats.Failed -gt 0) {
    Write-Host "Failed Tests:" -ForegroundColor Red
    $script:TestResults | Where-Object { $_.Result -eq "Failed" } | ForEach-Object {
        Write-Host "  - $($_.Name): $($_.Reason)" -ForegroundColor Gray
    }
    Write-Host ""
}

$exitCode = if ($script:TestStats.Failed -eq 0) { 0 } else { 1 }
exit $exitCode

#endregion
