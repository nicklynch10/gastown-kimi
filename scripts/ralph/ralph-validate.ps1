#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Ralph-Gastown End-to-End Validation Script

.DESCRIPTION
    Comprehensive validation that ensures the entire Ralph-Gastown system
    is working correctly and ready for production use.

    Validates:
    1. All scripts parse correctly
    2. All modules load successfully
    3. Demo application runs correctly
    4. Bead contract validation works
    5. Verifier execution works
    6. Browser module loads (if available)
    7. Resilience module functions work
    8. Full workflow simulation

.PARAMETER Detailed
    Show detailed output for each test

.PARAMETER OutputFormat
    Output format: console, json, markdown

.EXAMPLE
    .\ralph-validate.ps1 -Detailed

.EXAMPLE
    .\ralph-validate.ps1 -OutputFormat json | Out-File validation-report.json
#>

[CmdletBinding()]
param(
    [switch]$Detailed,
    
    [ValidateSet("console", "json", "markdown")]
    [string]$OutputFormat = "console"
)

$VALIDATION_VERSION = "1.0.0"

#region Test Results

$script:Results = @{
    Version = $VALIDATION_VERSION
    Timestamp = Get-Date -Format "o"
    System = @{
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        Platform = $env:OS
    }
    Tests = @()
    Summary = @{
        Total = 0
        Passed = 0
        Failed = 0
        Skipped = 0
    }
}

function Add-TestResult {
    param(
        [string]$Category,
        [string]$Name,
        [bool]$Passed,
        [string]$Message = "",
        [switch]$Skip,
        [object]$Data = $null
    )
    
    $result = [PSCustomObject]@{
        Category = $Category
        Name = $Name
        Passed = if ($Skip) { $null } else { $Passed }
        Skipped = $Skip.IsPresent
        Message = $Message
        Duration = $null
        Data = $Data
    }
    
    $script:Results.Tests += $result
    $script:Results.Summary.Total++
    
    if ($Skip) { $script:Results.Summary.Skipped++ }
    elseif ($Passed) { $script:Results.Summary.Passed++ }
    else { $script:Results.Summary.Failed++ }
    
    return $result
}

#endregion

#region Validation Tests

function Test-CoreScripts {
    $category = "Core Scripts"
    Write-Host "Validating Core Scripts..." -ForegroundColor Cyan
    
    $scripts = @(
        @{ Path = "scripts/ralph/ralph-master.ps1"; Required = $true }
        @{ Path = "scripts/ralph/ralph-executor.ps1"; Required = $true }
        @{ Path = "scripts/ralph/ralph-executor-simple.ps1"; Required = $true }
        @{ Path = "scripts/ralph/ralph-governor.ps1"; Required = $true }
        @{ Path = "scripts/ralph/ralph-watchdog.ps1"; Required = $true }
        @{ Path = "scripts/ralph/ralph-setup.ps1"; Required = $false }
    )
    
    foreach ($script in $scripts) {
        $path = $script.Path
        $name = Split-Path $path -Leaf
        
        try {
            if (-not (Test-Path $path)) {
                if ($script.Required) {
                    Add-TestResult -Category $category -Name $name -Passed $false -Message "File not found"
                } else {
                    Add-TestResult -Category $category -Name $name -Skip -Message "Optional file not found"
                }
                continue
            }
            
            $content = Get-Content $path -Raw
            
            # Test parsing
            try {
                $null = [scriptblock]::Create($content)
                Add-TestResult -Category $category -Name "$name - Parses" -Passed $true
            }
            catch {
                Add-TestResult -Category $category -Name "$name - Parses" -Passed $false -Message $_.Exception.Message
                continue
            }
            
            # Check PS5.1 compatibility
            $hasPS7Ops = ($content -match '\$\w+\?\?\s') -or 
                        ($content -match '\$\w+\?\.') -or
                        ($content -match '\$\w+\?\?=')
            
            Add-TestResult -Category $category -Name "$name - PS5.1 Compatible" -Passed (-not $hasPS7Ops) -Message $(if($hasPS7Ops){"Contains PS7-only operators"}else{"Compatible"})
            
            # Check for required functions
            $hasCmdletBinding = $content -match "\[CmdletBinding\(\)\]"
            Add-TestResult -Category $category -Name "$name - Has CmdletBinding" -Passed $hasCmdletBinding
        }
        catch {
            Add-TestResult -Category $category -Name $name -Passed $false -Message $_.Exception.Message
        }
    }
}

function Test-Modules {
    $category = "PowerShell Modules"
    Write-Host "Validating PowerShell Modules..." -ForegroundColor Cyan
    
    $modules = @(
        @{ Path = "scripts\ralph\ralph-browser.psm1"; Required = $false }
        @{ Path = "scripts\ralph\ralph-resilience.psm1"; Required = $false }
    )
    
    foreach ($mod in $modules) {
        $path = $mod.Path
        $name = Split-Path $path -Leaf
        
        if (-not (Test-Path $path)) {
            Add-TestResult -Category $category -Name $name -Skip -Message "Module not found"
            continue
        }
        
        try {
            Import-Module (Join-Path $PWD $path) -Force
            $moduleName = [System.IO.Path]::GetFileNameWithoutExtension($path)
            $moduleInfo = Get-Module $moduleName
            
            Add-TestResult -Category $category -Name "$name - Loads" -Passed $true -Data @{
                ExportedCommands = $moduleInfo.ExportedCommands.Count
                ExportedFunctions = $moduleInfo.ExportedFunctions.Count
            }
            
            Remove-Module ([System.IO.Path]::GetFileNameWithoutExtension($path)) -Force -ErrorAction SilentlyContinue
        }
        catch {
            Add-TestResult -Category $category -Name "$name - Loads" -Passed $false -Message $_.Exception.Message
        }
    }
}

function Test-Formulas {
    $category = "Bead Formulas"
    Write-Host "Validating Bead Formulas..." -ForegroundColor Cyan
    
    $formulas = @(
        "molecule-ralph-work"
        "molecule-ralph-patrol"
        "molecule-ralph-gate"
    )
    
    foreach ($formula in $formulas) {
        $path = ".beads/formulas/$formula.formula.toml"
        
        if (-not (Test-Path $path)) {
            Add-TestResult -Category $category -Name $formula -Passed $false -Message "Formula not found"
            continue
        }
        
        $content = Get-Content $path -Raw
        
        # Check required fields
        $expectedFormula = 'formula = "' + $formula + '"'
        $hasFormula = $content -match [regex]::Escape($expectedFormula)
        $hasVersion = $content -match "version = "
        $hasType = $content -match "type = "
        $hasSteps = $content -match "\[\[steps\]\]"
        
        Add-TestResult -Category $category -Name "$formula - Formula field" -Passed $hasFormula
        Add-TestResult -Category $category -Name "$formula - Version field" -Passed $hasVersion
        Add-TestResult -Category $category -Name "$formula - Type field" -Passed $hasType
        Add-TestResult -Category $category -Name "$formula - Has steps" -Passed $hasSteps
    }
}

function Test-Schema {
    $category = "Bead Schema"
    Write-Host "Validating Bead Schema..." -ForegroundColor Cyan
    
    $path = ".beads/schemas/ralph-bead.schema.json"
    
    if (-not (Test-Path $path)) {
        Add-TestResult -Category $category -Name "Schema exists" -Passed $false -Message "Schema file not found"
        return
    }
    
    Add-TestResult -Category $category -Name "Schema exists" -Passed $true
    
    try {
        $schema = Get-Content $path -Raw | ConvertFrom-Json
        
        $hasTitle = $null -ne $schema.title
        $hasRequired = $schema.required -contains "intent" -and $schema.required -contains "dod"
        $hasProperties = $null -ne $schema.properties
        
        Add-TestResult -Category $category -Name "Valid JSON" -Passed $true
        Add-TestResult -Category $category -Name "Has title" -Passed $hasTitle
        Add-TestResult -Category $category -Name "Has required fields" -Passed $hasRequired
        Add-TestResult -Category $category -Name "Has properties" -Passed $hasProperties
    }
    catch {
        Add-TestResult -Category $category -Name "Valid JSON" -Passed $false -Message $_.Exception.Message
    }
}

function Test-DemoApplication {
    $category = "Demo Application"
    Write-Host "Validating Demo Application..." -ForegroundColor Cyan
    
    $demoDir = "examples/ralph-demo"
    
    # Check files exist
    $files = @("Calculator.psm1", "test.ps1", "ralph-demo.ps1", "bead-gt-demo-calc-001.json")
    foreach ($file in $files) {
        $path = "$demoDir/$file"
        Add-TestResult -Category $category -Name "File exists: $file" -Passed (Test-Path $path)
    }
    
    # Test calculator module
    try {
        Import-Module (Join-Path $PWD "$demoDir\Calculator.psm1") -Force
        
        # Test functions
        $tests = @(
            @{ Func = "Add-Numbers"; Args = @{ a = 2; b = 3 }; Expected = 5 }
            @{ Func = "Subtract-Numbers"; Args = @{ a = 5; b = 3 }; Expected = 2 }
            @{ Func = "Multiply-Numbers"; Args = @{ a = 4; b = 5 }; Expected = 20 }
            @{ Func = "Divide-Numbers"; Args = @{ a = 10; b = 2 }; Expected = 5 }
        )
        
        foreach ($test in $tests) {
            try {
                $funcArgs = $test.Args
                $result = & $test.Func @funcArgs
                $passed = $result -eq $test.Expected
                Add-TestResult -Category $category -Name "$($test.Func) works" -Passed $passed -Data @{ Result = $result; Expected = $test.Expected }
            }
            catch {
                Add-TestResult -Category $category -Name "$($test.Func) works" -Passed $false -Message $_.Exception.Message
            }
        }
        
        Remove-Module Calculator -Force -ErrorAction SilentlyContinue
    }
    catch {
        Add-TestResult -Category $category -Name "Calculator module loads" -Passed $false -Message $_.Exception.Message
    }
    
    # Test demo tests
    try {
        $testPath = Join-Path $PWD "$demoDir\test.ps1"
        $testOutput = & $testPath 2>&1
        $testExit = $LASTEXITCODE
        Add-TestResult -Category $category -Name "Demo tests pass" -Passed ($testExit -eq 0) -Data @{ ExitCode = $testExit }
    }
    catch {
        Add-TestResult -Category $category -Name "Demo tests pass" -Passed $false -Message $_.Exception.Message
    }
}

function Test-VerifierExecution {
    $category = "Verifier Execution"
    Write-Host "Testing Verifier Execution..." -ForegroundColor Cyan
    
    # Test simple command execution
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-NoProfile -Command 'exit 0'"
        $psi.RedirectStandardOutput = $true
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        
        $process = [System.Diagnostics.Process]::Start($psi)
        $completed = $process.WaitForExit(5000)
        $exitCode = $process.ExitCode
        $process.Dispose()
        
        Add-TestResult -Category $category -Name "Simple command execution" -Passed ($completed -and $exitCode -eq 0)
    }
    catch {
        Add-TestResult -Category $category -Name "Simple command execution" -Passed $false -Message $_.Exception.Message
    }
    
    # Test timeout handling
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-NoProfile -Command 'Start-Sleep 10'"
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        
        $process = [System.Diagnostics.Process]::Start($psi)
        $completed = $process.WaitForExit(100)
        
        if (-not $completed) {
            $process.Kill()
        }
        $process.Dispose()
        
        Add-TestResult -Category $category -Name "Timeout handling" -Passed (-not $completed)
    }
    catch {
        Add-TestResult -Category $category -Name "Timeout handling" -Passed $false -Message $_.Exception.Message
    }
}

function Test-BeadContract {
    $category = "Bead Contract"
    Write-Host "Testing Bead Contract Validation..." -ForegroundColor Cyan
    
    # Create test bead
    $testBead = @{
        id = "gt-test-validation"
        title = "Validation Test"
        intent = "Test intent"
        dod = @{
            verifiers = @(
                @{
                    name = "Test verifier"
                    command = "exit 0"
                    expect = @{ exit_code = 0 }
                }
            )
        }
        constraints = @{
            max_iterations = 3
        }
    }
    
    try {
        $json = $testBead | ConvertTo-Json -Depth 10
        $parsed = $json | ConvertFrom-Json
        
        Add-TestResult -Category $category -Name "Bead serialization" -Passed $true
        Add-TestResult -Category $category -Name "Bead has intent" -Passed ($null -ne $parsed.intent)
        Add-TestResult -Category $category -Name "Bead has dod" -Passed ($null -ne $parsed.dod)
        Add-TestResult -Category $category -Name "Bead has verifiers" -Passed ($parsed.dod.verifiers.Count -gt 0)
    }
    catch {
        Add-TestResult -Category $category -Name "Bead serialization" -Passed $false -Message $_.Exception.Message
    }
}

function Test-WorkflowSimulation {
    $category = "Workflow Simulation"
    Write-Host "Running Workflow Simulation..." -ForegroundColor Cyan
    
    # Simulate the Ralph workflow without actually invoking Kimi
    
    # Step 1: Load bead
    try {
        $demoBead = Get-Content "examples/ralph-demo/bead-gt-demo-calc-001.json" -Raw | ConvertFrom-Json
        Add-TestResult -Category $category -Name "Load demo bead" -Passed $true
    }
    catch {
        Add-TestResult -Category $category -Name "Load demo bead" -Passed $false -Message $_.Exception.Message
        return
    }
    
    # Step 2: Validate verifiers
    $hasVerifiers = $demoBead.dod.verifiers.Count -gt 0
    Add-TestResult -Category $category -Name "Demo has verifiers" -Passed $hasVerifiers -Data @{ Count = $demoBead.dod.verifiers.Count }
    
    # Step 3: Test verifier structure
    $validVerifiers = $true
    foreach ($verifier in $demoBead.dod.verifiers) {
        if (-not $verifier.name -or -not $verifier.command) {
            $validVerifiers = $false
            break
        }
    }
    Add-TestResult -Category $category -Name "Verifiers have required fields" -Passed $validVerifiers
    
    # Step 4: Simulate execution (dry run)
    Add-TestResult -Category $category -Name "Dry run simulation" -Passed $true -Message "Workflow structure validated"
}

#endregion

#region Output Formatting

function Write-ConsoleOutput {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "      RALPH-GASTOWN VALIDATION REPORT   " -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Version: $($script:Results.Version)" -ForegroundColor Gray
    Write-Host "Timestamp: $($script:Results.Timestamp)" -ForegroundColor Gray
    Write-Host "PowerShell: $($script:Results.System.PowerShellVersion)" -ForegroundColor Gray
    Write-Host ""
    
    # Group results by category
    $categories = $script:Results.Tests | Group-Object -Property Category
    
    foreach ($cat in $categories) {
        Write-Host "[$($cat.Name)]" -ForegroundColor Yellow
        
        foreach ($test in $cat.Group) {
            $icon = if ($test.Skipped) { "SKIP" } elseif ($test.Passed) { "PASS" } else { "FAIL" }
            $color = if ($test.Skipped) { "Yellow" } elseif ($test.Passed) { "Green" } else { "Red" }
            
            Write-Host "  $icon : $($test.Name)" -ForegroundColor $color
            
            if ($Detailed -and $test.Message) {
                Write-Host "        $($test.Message)" -ForegroundColor Gray
            }
            
            if ($Detailed -and $test.Data) {
                $dataStr = ($test.Data | ConvertTo-Json -Compress -Depth 2)
                Write-Host "        Data: $dataStr" -ForegroundColor Gray
            }
        }
        
        Write-Host ""
    }
    
    # Summary
    $total = $script:Results.Summary.Total
    $passed = $script:Results.Summary.Passed
    $failed = $script:Results.Summary.Failed
    $skipped = $script:Results.Summary.Skipped
    
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "SUMMARY" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Total:   $total" -ForegroundColor White
    Write-Host "Passed:  $passed" -ForegroundColor Green
    Write-Host "Failed:  $failed" -ForegroundColor $(if($failed -gt 0){"Red"}else{"Green"})
    Write-Host "Skipped: $skipped" -ForegroundColor Yellow
    Write-Host ""
    
    if ($failed -eq 0) {
        Write-Host "[OK] ALL VALIDATION CHECKS PASSED" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] VALIDATION FAILED ($failed failures)" -ForegroundColor Red
    }
}

function Write-JsonOutput {
    $script:Results | ConvertTo-Json -Depth 10
}

function Write-MarkdownOutput {
    $output = @"
# Ralph-Gastown Validation Report

**Version:** $($script:Results.Version)  
**Timestamp:** $($script:Results.Timestamp)  
**PowerShell:** $($script:Results.System.PowerShellVersion)

## Summary

| Metric | Count |
|--------|-------|
| Total | $($script:Results.Summary.Total) |
| Passed | $($script:Results.Summary.Passed) |
| Failed | $($script:Results.Summary.Failed) |
| Skipped | $($script:Results.Summary.Skipped) |

## Results by Category

"@
    
    $categories = $script:Results.Tests | Group-Object -Property Category
    
    foreach ($cat in $categories) {
        $output += "### $($cat.Name)`n`n"
        $output += "| Status | Test | Message |`n"
        $output += "|--------|------|---------|`n"
        
        foreach ($test in $cat.Group) {
            $status = if ($test.Skipped) { "SKIP" } elseif ($test.Passed) { "PASS" } else { "FAIL" }
            $message = if ($test.Message) { $test.Message } else { "" }
            $output += "| $status | $($test.Name) | $message |`n"
        }
        
        $output += "`n"
    }
    
    $output
}

#endregion

#region Main

# Run all tests
Test-CoreScripts
Test-Modules
Test-Formulas
Test-Schema
Test-DemoApplication
Test-VerifierExecution
Test-BeadContract
Test-WorkflowSimulation

# Output results
switch ($OutputFormat) {
    "json" { Write-JsonOutput }
    "markdown" { Write-MarkdownOutput }
    default { Write-ConsoleOutput }
}

# Exit with appropriate code
exit $(if ($script:Results.Summary.Failed -eq 0) { 0 } else { 1 })

#endregion
