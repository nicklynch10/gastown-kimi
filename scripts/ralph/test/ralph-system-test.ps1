#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Ralph-Gastown System Integration Test Suite

.DESCRIPTION
    Comprehensive test suite that validates:
    1. All scripts parse and load correctly
    2. Core functions work as expected
    3. Integration between components
    4. Error handling and edge cases
    5. Browser testing module (if available)

.PARAMETER TestType
    Type of tests to run: unit, integration, e2e, all

.PARAMETER Verbose
    Show detailed test output

.EXAMPLE
    .\ralph-system-test.ps1 -TestType all -Verbose
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet("unit", "integration", "e2e", "all")]
    [string]$TestType = "all",

    [Parameter()]
    [switch]$ShowProgress
)

#region Test Framework

$script:TestResults = @()
$script:Passed = 0
$script:Failed = 0
$script:Skipped = 0

function Write-TestHeader {
    param([string]$Title)
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host $Title -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
}

function Write-TestResult {
    param(
        [string]$Name,
        [bool]$Passed,
        [string]$Message = "",
        [switch]$Skip
    )
    
    $icon = if ($Skip) { "SKIP" } elseif ($Passed) { "PASS" } else { "FAIL" }
    $color = if ($Skip) { "Yellow" } elseif ($Passed) { "Green" } else { "Red" }
    
    Write-Host "[$icon] $Name" -ForegroundColor $color
    if ($Message -and -not $Passed -and -not $Skip) {
        Write-Host "      $Message" -ForegroundColor Gray
    }
    
    $script:TestResults += [PSCustomObject]@{
        Name = $Name
        Passed = if ($Skip) { $null } else { $Passed }
        Message = $Message
    }
    
    if ($Skip) { $script:Skipped++ }
    elseif ($Passed) { $script:Passed++ }
    else { $script:Failed++ }
}

function Invoke-TestCase {
    param(
        [string]$Name,
        [scriptblock]$Test,
        [switch]$Skip
    )
    
    if ($Skip) {
        Write-TestResult -Name $Name -Skip
        return
    }
    
    try {
        $result = & $Test
        if ($result -eq $false) {
            Write-TestResult -Name $Name -Passed $false -Message "Test returned false"
        } else {
            Write-TestResult -Name $Name -Passed $true
        }
    } catch {
        Write-TestResult -Name $Name -Passed $false -Message $_.Exception.Message
    }
}

#endregion

#region Unit Tests

function Test-ScriptParsing {
    Write-TestHeader "UNIT: Script Parsing"
    
    $scriptsDir = "$PSScriptRoot/.."
    $scripts = @(
        "ralph-master.ps1",
        "ralph-executor.ps1",
        "ralph-executor-simple.ps1",
        "ralph-governor.ps1",
        "ralph-watchdog.ps1"
    )
    
    foreach ($script in $scripts) {
        $path = Join-Path $scriptsDir $script
        Invoke-TestCase -Name "Parse $script" -Test {
            if (-not (Test-Path $path)) { throw "File not found: $path" }
            $content = Get-Content $path -Raw
            $null = [scriptblock]::Create($content)
            $true
        }
    }
}

function Test-FunctionExports {
    Write-TestHeader "UNIT: Function Exports"
    
    Invoke-TestCase -Name "ralph-master defines Invoke-InitCommand" -Test {
        $content = Get-Content "$PSScriptRoot/../ralph-master.ps1" -Raw
        $content -match "function Invoke-InitCommand"
    }
    
    Invoke-TestCase -Name "ralph-governor defines Test-GatesBlocking" -Test {
        $content = Get-Content "$PSScriptRoot/../ralph-governor.ps1" -Raw
        $content -match "function Test-GatesBlocking"
    }
    
    Invoke-TestCase -Name "ralph-watchdog defines Send-Nudge" -Test {
        $content = Get-Content "$PSScriptRoot/../ralph-watchdog.ps1" -Raw
        $content -match "function Send-Nudge"
    }
}

function Test-PowerShellCompatibility {
    Write-TestHeader "UNIT: PowerShell 5.1 Compatibility"
    
    $scripts = Get-ChildItem "$PSScriptRoot/.." -Filter "*.ps1"
    
    foreach ($script in $scripts) {
        $content = Get-Content $script.FullName -Raw
        
        Invoke-TestCase -Name "$($script.Name) - No ?? operator" -Test {
            $content -notmatch '\$\w+\?\?\s' -and $content -notmatch '\$\w+\?\?='
        }
        
        Invoke-TestCase -Name "$($script.Name) - No ?. operator" -Test {
            $content -notmatch '\$\w+\?\.'
        }
    }
}

function Test-FormulaFiles {
    Write-TestHeader "UNIT: Formula Files"
    
    $projectRoot = Resolve-Path "$PSScriptRoot/../../.."
    $formulas = @(
        "molecule-ralph-work",
        "molecule-ralph-patrol",
        "molecule-ralph-gate"
    )
    
    foreach ($formula in $formulas) {
        $path = Join-Path $projectRoot ".beads/formulas/$formula.formula.toml"
        
        Invoke-TestCase -Name "Formula exists: $formula" -Test {
            Test-Path $path
        }
        
        Invoke-TestCase -Name "Formula valid TOML: $formula" -Test {
            $content = Get-Content $path -Raw
            $expected = 'formula = "' + $formula + '"'
            $content -match [regex]::Escape($expected)
        }
    }
}

#endregion

#region Integration Tests

function Test-BeadContractSchema {
    Write-TestHeader "INTEGRATION: Bead Contract Schema"
    
    $projectRoot = Resolve-Path "$PSScriptRoot/../../.."
    $schemaPath = Join-Path $projectRoot ".beads/schemas/ralph-bead.schema.json"
    
    Invoke-TestCase -Name "Schema file exists" -Test {
        Test-Path $schemaPath
    }
    
    Invoke-TestCase -Name "Schema is valid JSON" -Test {
        $content = Get-Content $schemaPath -Raw
        $null = $content | ConvertFrom-Json
        $true
    }
    
    Invoke-TestCase -Name "Schema has required fields" -Test {
        $schema = Get-Content $schemaPath -Raw | ConvertFrom-Json
        $schema.required -contains "intent" -and $schema.required -contains "dod"
    }
}

function Test-DemoApp {
    Write-TestHeader "INTEGRATION: Demo Application"
    
    $demoDir = Resolve-Path "$PSScriptRoot/../../../examples/ralph-demo"
    
    Invoke-TestCase -Name "Demo Calculator module exists" -Test {
        Test-Path "$demoDir/Calculator.psm1"
    }
    
    Invoke-TestCase -Name "Demo tests exist" -Test {
        Test-Path "$demoDir/test.ps1"
    }
    
    Invoke-TestCase -Name "Demo bead exists" -Test {
        Test-Path "$demoDir/bead-gt-demo-calc-001.json"
    }
    
    Invoke-TestCase -Name "Calculator module loads" -Test {
        Import-Module "$demoDir/Calculator.psm1" -Force
        (Get-Command Add-Numbers) -ne $null
    }
    
    Invoke-TestCase -Name "Calculator Add works" -Test {
        Import-Module "$demoDir/Calculator.psm1" -Force
        $result = Add-Numbers -a 2 -b 3
        $result -eq 5
    }
}

function Test-ExecutorLogic {
    Write-TestHeader "INTEGRATION: Executor Logic"
    
    $executorPath = "$PSScriptRoot/../ralph-executor.ps1"
    
    Invoke-TestCase -Name "Executor can be dot-sourced" -Test {
        $content = Get-Content $executorPath -Raw
        $null = [scriptblock]::Create($content)
        $true
    }
}

#endregion

#region E2E Tests

function Test-EndToEndWorkflow {
    Write-TestHeader "E2E: Complete Workflow"
    
    Invoke-TestCase -Name "Can create test bead JSON" -Test {
        $testBead = @{
            id = "gt-test-001"
            title = "Test Bead"
            intent = "Verify Ralph system works"
            dod = @{
                verifiers = @(
                    @{
                        name = "Always passes"
                        command = "exit 0"
                        expect = @{ exit_code = 0 }
                    }
                )
            }
            constraints = @{
                max_iterations = 3
            }
        }
        $json = $testBead | ConvertTo-Json -Depth 10
        $json -match "gt-test-001"
    } -Skip:(-not $env:RALPH_RUN_E2E)
    
    Invoke-TestCase -Name "Verifier execution works" -Test {
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
        
        $completed -and $exitCode -eq 0
    }
    
    Invoke-TestCase -Name "Timeout handling works" -Test {
        # Test that WaitForExit returns false when timeout expires
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-NoProfile -Command 'Start-Sleep 5'"
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        
        $process = [System.Diagnostics.Process]::Start($psi)
        $startTime = Get-Date
        $completed = $process.WaitForExit(100)  # 100ms timeout
        $elapsed = ((Get-Date) - $startTime).TotalMilliseconds
        
        if (-not $completed) {
            $process.Kill()
        }
        $process.Dispose()
        
        # Test passes if: it didn't complete AND it respected the timeout
        (-not $completed) -and ($elapsed -lt 1000)
    }
}

#endregion

#region Browser Testing Module Validation

function Test-BrowserTestingModule {
    Write-TestHeader "BROWSER: Testing Module"
    
    $browserModule = "$PSScriptRoot/../ralph-browser.psm1"
    
    Invoke-TestCase -Name "Browser module exists" -Test {
        Test-Path $browserModule
    }
    
    if (Test-Path $browserModule) {
        Invoke-TestCase -Name "Browser module loads" -Test {
            Import-Module $browserModule -Force
            (Get-Module ralph-browser) -ne $null
        }
        
        Invoke-TestCase -Name "New-BrowserTestContext function exists" -Test {
            (Get-Command New-BrowserTestContext -ErrorAction SilentlyContinue) -ne $null
        }
    }
}

#endregion

#region Main

Write-TestHeader "RALPH-GASTOWN SYSTEM TEST SUITE"
Write-Host "Test Type: $TestType"
Write-Host "Start Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host ""

$startTime = Get-Date

switch ($TestType) {
    "unit" {
        Test-ScriptParsing
        Test-FunctionExports
        Test-PowerShellCompatibility
        Test-FormulaFiles
    }
    "integration" {
        Test-BeadContractSchema
        Test-DemoApp
        Test-ExecutorLogic
    }
    "e2e" {
        Test-EndToEndWorkflow
    }
    "all" {
        Test-ScriptParsing
        Test-FunctionExports
        Test-PowerShellCompatibility
        Test-FormulaFiles
        Test-BeadContractSchema
        Test-DemoApp
        Test-ExecutorLogic
        Test-EndToEndWorkflow
        Test-BrowserTestingModule
    }
}

$endTime = Get-Date
$duration = $endTime - $startTime

Write-TestHeader "TEST SUMMARY"
Write-Host "Duration: $($duration.TotalSeconds.ToString('F2'))s"
Write-Host "Passed: $script:Passed" -ForegroundColor Green
Write-Host "Failed: $script:Failed" -ForegroundColor $(if($script:Failed -gt 0){"Red"}else{"Green"})
Write-Host "Skipped: $script:Skipped" -ForegroundColor Yellow
Write-Host ""

if ($script:Failed -eq 0) {
    Write-Host "ALL TESTS PASSED" -ForegroundColor Green
    exit 0
} else {
    Write-Host "SOME TESTS FAILED" -ForegroundColor Red
    exit 1
}

#endregion
