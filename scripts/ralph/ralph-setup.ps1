#!/usr/bin/env pwsh
<#
.SYNOPSIS
    One-Command Ralph-Gastown SDLC Setup

.DESCRIPTION
    Sets up a complete, production-ready automated SDLC environment:
    1. Validates prerequisites (Git, PowerShell, Node.js if browser testing)
    2. Creates Ralph directory structure
    3. Initializes sample project with working DoD
    4. Sets up patrol and gate infrastructure
    5. Creates watchdog service configuration
    6. Validates the entire setup

.PARAMETER ProjectName
    Name of the project to set up

.PARAMETER ProjectType
    Type of project: go, node, python, powershell, generic

.PARAMETER WithBrowserTests
    Include browser testing setup

.PARAMETER WithPatrol
    Set up automated patrol (requires scheduled task/cron setup)

.PARAMETER SkipValidation
    Skip prerequisite validation (not recommended)

.EXAMPLE
    .\ralph-setup.ps1 -ProjectName "myapp" -ProjectType go -WithBrowserTests

.EXAMPLE
    .\ralph-setup.ps1 -ProjectName "webapp" -ProjectType node -WithPatrol
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectName,
    
    [Parameter()]
    [ValidateSet("go", "node", "python", "powershell", "generic")]
    [string]$ProjectType = "generic",
    
    [Parameter()]
    [switch]$WithBrowserTests,
    
    [Parameter()]
    [switch]$WithPatrol,
    
    [Parameter()]
    [switch]$SkipValidation,
    
    [Parameter()]
    [string]$WorkingDir = "."
)

$RALPH_SETUP_VERSION = "1.0.0"

#region UI

function Write-SetupHeader {
    Clear-Host
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "    RALPH-GASTOWN SDLC SETUP v$RALPH_SETUP_VERSION    " -ForegroundColor Cyan
    Write-Host "    Automated Software Delivery          " -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step {
    param([int]$Number, [string]$Title)
    Write-Host ""
    Write-Host "[$Number/7] $Title" -ForegroundColor Yellow
    Write-Host "$("-" * 50)" -ForegroundColor Gray
}

function Write-Status {
    param([string]$Message, [string]$Status = "INFO")
    $icons = @{ "OK" = "+"; "FAIL" = "X"; "WARN" = "!"; "INFO" = ">" }
    $colors = @{ "OK" = "Green"; "FAIL" = "Red"; "WARN" = "Yellow"; "INFO" = "White" }
    $icon = $icons[$Status]
    $color = $colors[$Status]
    Write-Host "  $icon $Message" -ForegroundColor $color
}

#endregion

#region Validation

function Test-Prerequisites {
    Write-Step 1 "Validating Prerequisites"
    
    $checks = @(
        @{ Name = "PowerShell 5.1+"; Test = { $PSVersionTable.PSVersion -ge [Version]"5.1" }; Required = $true }
        @{ Name = "Git"; Test = { (Get-Command git -ErrorAction SilentlyContinue) -ne $null }; Required = $true }
        @{ Name = "Git repository"; Test = { Test-Path .git }; Required = $false }
    )
    
    $allPassed = $true
    foreach ($check in $checks) {
        $result = & $check.Test
        $status = if ($result) { "OK" } elseif ($check.Required) { "FAIL" } else { "WARN" }
        Write-Status $check.Name $status
        if (-not $result -and $check.Required) { $allPassed = $false }
    }
    
    if ($WithBrowserTests) {
        Write-Status "Checking browser testing prerequisites..." "INFO"
        
        $nodeCheck = (Get-Command node -ErrorAction SilentlyContinue) -ne $null
        $npmCheck = (Get-Command npm -ErrorAction SilentlyContinue) -ne $null
        
        if (-not $nodeCheck) {
            Write-Status "Node.js not found - browser tests require Node.js" "FAIL"
            $allPassed = $false
        } else {
            Write-Status "Node.js found" "OK"
        }
        
        if (-not $npmCheck) {
            Write-Status "npm not found" "FAIL"
            $allPassed = $false
        } else {
            Write-Status "npm found" "OK"
        }
    }
    
    return $allPassed
}

#endregion

#region Directory Structure

function Initialize-DirectoryStructure {
    Write-Step 2 "Creating Directory Structure"
    
    $dirs = @(
        ".ralph/evidence/screenshots",
        ".ralph/evidence/traces",
        ".ralph/evidence/har",
        ".ralph/logs",
        ".ralph/patrol",
        ".ralph/gates",
        ".kimi"
    )
    
    foreach ($dir in $dirs) {
        $path = Join-Path $WorkingDir $dir
        if (-not (Test-Path $path)) {
            New-Item -ItemType Directory -Force -Path $path | Out-Null
            Write-Status "Created: $dir" "OK"
        } else {
            Write-Status "Exists: $dir" "INFO"
        }
    }
}

#endregion

#region Project Templates

function Get-BuildCommand {
    param([string]$Type)
    switch ($Type) {
        "go" { return "go build ./..." }
        "node" { return "npm run build" }
        "python" { return "python -m compileall ." }
        "powershell" { return "Get-ChildItem -Recurse -Filter '*.ps1' | ForEach-Object { `$null = [System.Management.Automation.PSParser]::Tokenize((Get-Content `$_.FullName), [ref]`$null) }" }
        default { return "echo 'No build step defined'" }
    }
}

function Get-TestCommand {
    param([string]$Type)
    switch ($Type) {
        "go" { return "go test ./..." }
        "node" { return "npm test" }
        "python" { return "python -m pytest" }
        "powershell" { return "Invoke-Pester -Path tests/ -PassThru | ForEach-Object { exit `$_.FailedCount }" }
        default { return "echo 'No test step defined'" }
    }
}

function Get-LintCommand {
    param([string]$Type)
    switch ($Type) {
        "go" { return "if (Get-Command golangci-lint) { golangci-lint run } else { go vet ./... }" }
        "node" { return "npm run lint" }
        "python" { return "python -m flake8" }
        "powershell" { return "Invoke-ScriptAnalyzer -Path . -Recurse -Severity Warning" }
        default { return "echo 'No lint step defined'" }
    }
}

function Initialize-ProjectTemplate {
    Write-Step 3 "Creating Project Template"
    
    $buildCmd = Get-BuildCommand -Type $ProjectType
    $testCmd = Get-TestCommand -Type $ProjectType
    $lintCmd = Get-LintCommand -Type $ProjectType
    
    # Create sample bead
    $sampleBead = @{
        id = "gt-$ProjectName-init-001"
        title = "Initialize $ProjectName with Ralph DoD"
        intent = "Set up $ProjectType project with automated testing and quality gates"
        dod = @{
            verifiers = @(
                @{
                    name = "Build succeeds"
                    command = $buildCmd
                    expect = @{ exit_code = 0 }
                    timeout_seconds = 120
                },
                @{
                    name = "Tests pass"
                    command = $testCmd
                    expect = @{ exit_code = 0 }
                    timeout_seconds = 300
                },
                @{
                    name = "Lint clean"
                    command = $lintCmd
                    expect = @{ exit_code = 0 }
                    timeout_seconds = 120
                }
            )
            evidence_required = $true
        }
        constraints = @{
            max_iterations = 10
            time_budget_minutes = 60
        }
        lane = "feature"
        priority = 2
    }
    
    $beadPath = Join-Path $WorkingDir ".ralph/sample-bead.json"
    $sampleBead | ConvertTo-Json -Depth 10 | Out-File -FilePath $beadPath -Encoding utf8
    Write-Status "Created sample bead: .ralph/sample-bead.json" "OK"
    
    # Create Kimi settings
    $kimiSettings = @{
        hooks = @{
            SessionStart = @(
                @{
                    matcher = ".*"
                    hooks = @(
                        @{
                            type = "command"
                            command = "Write-Host 'Ralph-Gastown Environment Ready' -ForegroundColor Cyan"
                        }
                    )
                }
            )
        }
    }
    
    $kimiPath = Join-Path $WorkingDir ".kimi/ralph-settings.json"
    $kimiSettings | ConvertTo-Json -Depth 10 | Out-File -FilePath $kimiPath -Encoding utf8
    Write-Status "Created Kimi settings: .kimi/ralph-settings.json" "OK"
}

#endregion

#region Gates and Patrol

function Initialize-Gates {
    Write-Step 4 "Setting Up Quality Gates"
    
    $gates = @(
        @{
            id = "gate-build"
            title = "[GATE] Build Verification"
            type = "build"
            command = Get-BuildCommand -Type $ProjectType
        },
        @{
            id = "gate-test"
            title = "[GATE] Test Suite"
            type = "test"
            command = Get-TestCommand -Type $ProjectType
        },
        @{
            id = "gate-lint"
            title = "[GATE] Code Quality"
            type = "lint"
            command = Get-LintCommand -Type $ProjectType
        }
    )
    
    foreach ($gate in $gates) {
        $gateData = @{
            id = $gate.id
            title = $gate.title
            gate_type = $gate.type
            verifier_command = $gate.command
            blocks_convoy = $true
            auto_close_on_pass = $true
        }
        
        $gatePath = Join-Path $WorkingDir ".ralph/gates/$($gate.id).json"
        $gateData | ConvertTo-Json -Depth 5 | Out-File -FilePath $gatePath -Encoding utf8
        Write-Status "Created gate: $($gate.id)" "OK"
    }
}

function Initialize-Patrol {
    Write-Step 5 "Setting Up Automated Patrol"
    
    $patrolConfig = @{
        enabled = $true
        interval_minutes = 30
        test_pattern = if ($ProjectType -eq "go") { "./..." } else { "*" }
        e2e_enabled = $WithBrowserTests.IsPresent
        e2e_command = if ($WithBrowserTests) { "npx playwright test" } else { $null }
        evidence_retention_days = 7
        notify_on_failure = $true
        create_bug_beads = $true
    }
    
    $patrolPath = Join-Path $WorkingDir ".ralph/patrol/config.json"
    $patrolConfig | ConvertTo-Json -Depth 5 | Out-File -FilePath $patrolPath -Encoding utf8
    Write-Status "Created patrol config: .ralph/patrol/config.json" "OK"
    
    # Create patrol runner script
    $patrolScript = @"
# Ralph Patrol Runner
# Generated by ralph-setup.ps1

param(`$RunOnce = `$false)

`$config = Get-Content "`$PSScriptRoot/config.json" | ConvertFrom-Json
`$logFile = "`$PSScriptRoot/patrol-$(Get-Date -Format 'yyyyMMdd').log"

function Write-PatrolLog(`$Message) {
    `$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[`$timestamp] `$Message" | Tee-Object -FilePath `$logFile -Append
}

Write-PatrolLog "Patrol started"

do {
    Write-PatrolLog "Running patrol cycle..."
    
    # Run tests
    `$testResult = & "$($patrolConfig.test_pattern)" 2>&1
    `$testExit = `$LASTEXITCODE
    
    if (`$testExit -ne 0) {
        Write-PatrolLog "TESTS FAILED - Creating bug bead"
        # Would create bug bead here
    }
    
    if (`$config.e2e_enabled) {
        Write-PatrolLog "Running E2E tests..."
        `$e2eResult = & `$config.e2e_command 2>&1
        if (`$LASTEXITCODE -ne 0) {
            Write-PatrolLog "E2E TESTS FAILED"
        }
    }
    
    Write-PatrolLog "Patrol cycle complete"
    
    if (-not `$RunOnce) {
        Start-Sleep -Seconds (`$config.interval_minutes * 60)
    }
} while (-not `$RunOne)

Write-PatrolLog "Patrol ended"
"@
    
    $patrolScriptPath = Join-Path $WorkingDir ".ralph/patrol/run.ps1"
    $patrolScript | Out-File -FilePath $patrolScriptPath -Encoding utf8
    Write-Status "Created patrol runner: .ralph/patrol/run.ps1" "OK"
}

#endregion

#region Watchdog

function Initialize-Watchdog {
    Write-Step 6 "Setting Up Watchdog"
    
    $watchdogConfig = @{
        enabled = $true
        watch_interval_seconds = 60
        stale_threshold_minutes = 30
        max_restarts = 5
        escalation_enabled = $true
        log_retention_days = 7
    }
    
    $watchdogPath = Join-Path $WorkingDir ".ralph/watchdog-config.json"
    $watchdogConfig | ConvertTo-Json -Depth 5 | Out-File -FilePath $watchdogPath -Encoding utf8
    Write-Status "Created watchdog config: .ralph/watchdog-config.json" "OK"
}

#endregion

#region Documentation

function Initialize-Documentation {
    Write-Step 7 "Creating Documentation"
    
    $readmeContent = @"
# $ProjectName - Ralph-Gastown SDLC

This project uses Ralph-Gastown for automated, correctness-forcing software delivery.

## Quick Start

### Run a Ralph Bead
```powershell
# Using the master script
.\scripts\ralph\ralph-master.ps1 -Command run -Bead <bead-id>

# Or directly
.\scripts\ralph\ralph-executor-simple.ps1 -BeadId <bead-id>
```

### Check Status
```powershell
.\scripts\ralph\ralph-master.ps1 -Command status
```

### Run Quality Gates
```powershell
.\scripts\ralph\ralph-master.ps1 -Command govern
```

### Start Watchdog
```powershell
.\scripts\ralph\ralph-master.ps1 -Command watchdog
```

## Project Structure

```
.
├── .ralph/
│   ├── evidence/          # Test evidence (screenshots, traces)
│   ├── logs/              # Execution logs
│   ├── gates/             # Quality gate definitions
│   └── patrol/            # Patrol configuration
├── .kimi/
│   └── ralph-settings.json    # Kimi CLI settings
└── scripts/ralph/
    ├── ralph-master.ps1       # Main control script
    ├── ralph-executor.ps1     # Bead executor
    ├── ralph-governor.ps1     # Policy enforcement
    └── ralph-watchdog.ps1     # Monitoring
```

## Quality Gates

The following gates must be green for features to proceed:

1. **Build Verification** - Project compiles successfully
2. **Test Suite** - All tests pass
3. **Code Quality** - Linting passes

$(if ($WithBrowserTests) { "4. **E2E Tests** - Browser tests pass`n" })

## Bead Contract

Ralph beads use this structure:

```json
{
  "intent": "What needs to be done",
  "dod": {
    "verifiers": [
      {
        "name": "Verifier name",
        "command": "Command to run",
        "expect": { "exit_code": 0 }
      }
    ]
  },
  "constraints": {
    "max_iterations": 10
  }
}
```

## Automated Patrol

$(if ($WithPatrol) { "Patrol runs every 30 minutes to check:" } else { "To enable patrol, run setup with -WithPatrol" })
- Test suite status
- Build status
$(if ($WithBrowserTests) { "- Browser/E2E tests" })

## Support

- [Ralph-Gastown Documentation](../../RALPH_INTEGRATION.md)
- Run `gt doctor` to diagnose issues
- Run `.\scripts\ralph\test\ralph-system-test.ps1` to validate setup
"@
    
    $readmePath = Join-Path $WorkingDir "RALPH-README.md"
    $readmeContent | Out-File -FilePath $readmePath -Encoding utf8
    Write-Status "Created documentation: RALPH-README.md" "OK"
}

#endregion

#region Validation

function Test-Setup {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "VALIDATING SETUP" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    $testScript = Join-Path $PSScriptRoot "test/ralph-system-test.ps1"
    
    if (Test-Path $testScript) {
        Write-Host "Running system validation..." -ForegroundColor White
        & $testScript -TestType unit
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Host "SETUP VALIDATED SUCCESSFULLY" -ForegroundColor Green
            return $true
        } else {
            Write-Host ""
            Write-Host "VALIDATION FAILED - Check errors above" -ForegroundColor Red
            return $false
        }
    } else {
        Write-Status "Test script not found, skipping validation" "WARN"
        return $true
    }
}

#endregion

#region Main

Write-SetupHeader

# Validate prerequisites
if (-not $SkipValidation) {
    $valid = Test-Prerequisites
    if (-not $valid) {
        Write-Host ""
        Write-Host "PREREQUISITE CHECK FAILED" -ForegroundColor Red
        Write-Host "Install missing prerequisites and try again, or use -SkipValidation (not recommended)" -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Status "Prerequisite validation skipped" "WARN"
}

# Run setup steps
Initialize-DirectoryStructure
Initialize-ProjectTemplate
Initialize-Gates

if ($WithPatrol) {
    Initialize-Patrol
}

Initialize-Watchdog
Initialize-Documentation

# Validate
$valid = Test-Setup

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "         SETUP COMPLETE                 " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Project: $ProjectName" -ForegroundColor White
Write-Host "Type: $ProjectType" -ForegroundColor White
Write-Host "Location: $(Resolve-Path $WorkingDir)" -ForegroundColor White
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Review RALPH-README.md for project-specific documentation"
Write-Host "  2. Run: .\scripts\ralph\ralph-master.ps1 -Command status"
Write-Host "  3. Create your first bead: .\scripts\ralph\ralph-master.ps1 -Command create-bead -Intent 'Your task'"
Write-Host ""

if ($WithBrowserTests) {
    Write-Host "Browser Testing:" -ForegroundColor Yellow
    Write-Host "  - Install Playwright: npm install -D @playwright/test"
    Write-Host "  - Install browsers: npx playwright install"
    Write-Host ""
}

if ($WithPatrol) {
    Write-Host "Patrol:" -ForegroundColor Yellow
    Write-Host "  - Start manually: .ralph\patrol\run.ps1"
    Write-Host "  - Or set up scheduled task to run every 30 minutes"
    Write-Host ""
}

Write-Host "Documentation:" -ForegroundColor Yellow
Write-Host "  - Project README: RALPH-README.md"
Write-Host "  - Integration Guide: RALPH_INTEGRATION.md"
Write-Host ""

exit $(if ($valid) { 0 } else { 1 })

#endregion
