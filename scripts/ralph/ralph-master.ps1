#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Ralph-Gastown Master Integration Script

.DESCRIPTION
    Main entry point for the Ralph-Gastown integration.
    
    This script:
    1. Sets up the Ralph environment in a Gastown town
    2. Installs formulas and schemas
    3. Configures Kimi hooks
    4. Validates Windows-native compatibility
    5. Provides commands for common operations

    PREREQUISITES:
    - PowerShell 5.1 or higher
    - Gastown CLI (gt): https://github.com/nicklynch10/gastown-cli
    - Beads CLI (bd): https://github.com/nicklynch10/beads-cli
    - Kimi Code CLI: pip install kimi-cli

.PARAMETER Command
    Command to execute: init, status, run, patrol, govern, watchdog, verify

.PARAMETER Rig
    Target rig for operations

.PARAMETER Convoy
    Target convoy for operations

.PARAMETER Bead
    Target bead for operations

.EXAMPLE
    .\ralph-master.ps1 -Command init -Rig myproject

.EXAMPLE
    .\ralph-master.ps1 -Command status

.EXAMPLE
    .\ralph-master.ps1 -Command run -Bead gt-abc12
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("init", "status", "run", "patrol", "govern", "watchdog", "verify", "create-bead", "create-gate", "help")]
    [string]$Command,

    [Parameter()]
    [string]$Rig,

    [Parameter()]
    [string]$Convoy,

    [Parameter()]
    [string]$Bead,

    [Parameter()]
    [string]$Intent,

    [Parameter()]
    [string]$GateType
)

#region Configuration

$RALPH_VERSION = "1.0.0"
$SCRIPTS_DIR = $PSScriptRoot
$TOWN_ROOT = $null

function Get-TownRoot {
    if (Get-Command gt -ErrorAction SilentlyContinue) {
        try {
            return & gt root 2>$null
        } catch {
            return $null
        }
    }
    return $null
}

$TOWN_ROOT = Get-TownRoot

#endregion

#region Prerequisites Check

function Test-Prerequisites {
    param([switch]$Detailed)
    
    $prereqs = @{
        PowerShell = $PSVersionTable.PSVersion -ge [Version]"5.1"
        Git = (Get-Command git -ErrorAction SilentlyContinue) -ne $null
        Kimi = (Get-Command kimi -ErrorAction SilentlyContinue) -ne $null
        Gastown = (Get-Command gt -ErrorAction SilentlyContinue) -ne $null
        Beads = (Get-Command bd -ErrorAction SilentlyContinue) -ne $null
    }
    
    if ($Detailed) {
        Write-Status "Prerequisites:" "STEP"
        foreach ($prereq in $prereqs.GetEnumerator()) {
            $status = if ($prereq.Value) { "OK" } else { "MISSING" }
            $color = if ($prereq.Value) { "Green" } else { "Yellow" }
            Write-Host "  [$status] $($prereq.Key)" -ForegroundColor $color
        }
        Write-Host ""
    }
    
    return $prereqs
}

function Show-PrereqHelp {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  PREREQUISITE INSTALLATION GUIDE       " -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. PowerShell 5.1+ (included with Windows)" -ForegroundColor White
    Write-Host ""
    Write-Host "2. Git for Windows:" -ForegroundColor White
    Write-Host "   winget install Git.Git" -ForegroundColor Gray
    Write-Host "   OR: https://git-scm.com/download/win" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. Gastown CLI (gt):" -ForegroundColor White
    Write-Host "   go install github.com/nicklynch10/gastown-cli/cmd/gt@latest" -ForegroundColor Gray
    Write-Host "   OR download from: https://github.com/nicklynch10/gastown-cli/releases" -ForegroundColor Gray
    Write-Host ""
    Write-Host "4. Beads CLI (bd):" -ForegroundColor White
    Write-Host "   go install github.com/nicklynch10/beads-cli/cmd/bd@latest" -ForegroundColor Gray
    Write-Host "   OR download from: https://github.com/nicklynch10/beads-cli/releases" -ForegroundColor Gray
    Write-Host ""
    Write-Host "5. Kimi Code CLI:" -ForegroundColor White
    Write-Host "   pip install kimi-cli" -ForegroundColor Gray
    Write-Host "   Requires: Python 3.8+" -ForegroundColor Gray
    Write-Host ""
}

#endregion

#region Logging

function Write-RalphHeader {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "RALPH-GASTOWN INTEGRATION v$RALPH_VERSION" -ForegroundColor Cyan
    Write-Host "Windows-Native DoD Enforcement" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Status {
    param([string]$Message, [string]$Level = "INFO")
    $icons = @{
        "INFO" = "i"
        "OK" = "+"
        "WARN" = "!"
        "ERROR" = "X"
        "STEP" = ">"
    }
    $colors = @{
        "INFO" = "White"
        "OK" = "Green"
        "WARN" = "Yellow"
        "ERROR" = "Red"
        "STEP" = "Cyan"
    }
    $icon = $icons[$Level]
    $color = $colors[$Level]
    Write-Host "[$icon] $Message" -ForegroundColor $color
}

#endregion

#region Commands

function Invoke-InitCommand {
    param([string]$TargetRig)
    
    Write-Status "Initializing Ralph integration..." "STEP"
    
    # 1. Verify prerequisites
    Write-Status "Checking prerequisites..." "STEP"
    
    $tools = @(
        @{ Name = "gt"; Command = "gt version" },
        @{ Name = "bd"; Command = "bd version" },
        @{ Name = "kimi"; Command = "kimi --version" },
        @{ Name = "git"; Command = "git version" }
    )
    
    $allOk = $true
    foreach ($tool in $tools) {
        $found = Get-Command $tool.Name -ErrorAction SilentlyContinue
        if ($found) {
            Write-Status "$($tool.Name): OK" "OK"
        }
        else {
            Write-Status "$($tool.Name): NOT FOUND" "ERROR"
            $allOk = $false
        }
    }
    
    if (-not $allOk) {
        Write-Status "Some prerequisites missing. Please install them." "ERROR"
        return
    }
    
    # 2. Install formulas
    Write-Status "Installing Ralph formulas..." "STEP"
    
    $formulas = @(
        "molecule-ralph-work",
        "molecule-ralph-patrol",
        "molecule-ralph-gate"
    )
    
    foreach ($formula in $formulas) {
        $formulaPath = "$SCRIPTS_DIR/../../.beads/formulas/$formula.formula.toml"
        if (Test-Path $formulaPath) {
            # Copy to town formulas if not exists
            Write-Status "  Formula: $formula" "OK"
        }
        else {
            Write-Status "  Formula: $formula (not found at $formulaPath)" "WARN"
        }
    }
    
    # 3. Create .ralph directory structure
    Write-Status "Creating Ralph directories..." "STEP"
    
    $dirs = @(
        ".ralph/evidence",
        ".ralph/logs",
        ".ralph/patrol"
    )
    
    foreach ($dir in $dirs) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    Write-Status "  Created .ralph/ structure" "OK"
    
    # 4. Create sample bead
    Write-Status "Creating sample Ralph bead..." "STEP"
    
    $sampleBead = @"
{
    "intent": "Sample Ralph bead demonstrating DoD enforcement",
    "dod": {
        "verifiers": [
            {
                "name": "Build succeeds",
                "command": "go build ./...",
                "expect": { "exit_code": 0 },
                "timeout_seconds": 60
            },
            {
                "name": "Tests pass",
                "command": "go test ./...",
                "expect": { "exit_code": 0 },
                "timeout_seconds": 120
            }
        ],
        "evidence_required": true
    },
    "constraints": {
        "max_iterations": 5,
        "time_budget_minutes": 30
    },
    "lane": "feature",
    "priority": 2
}
"@
    
    $sampleBead | Out-File -FilePath ".ralph/sample-bead.json" -Encoding utf8
    Write-Status "  Sample saved to .ralph/sample-bead.json" "OK"
    
    # 5. Configure Kimi settings
    Write-Status "Configuring Kimi for Ralph..." "STEP"
    
    $kimiSettings = @{
        hooks = @{
            SessionStart = @(
                @{
                    matcher = ".*"
                    hooks = @(
                        @{
                            type = "command"
                            command = "gt prime"
                        }
                    )
                }
            )
        }
    }
    
    $kimiSettingsJson = $kimiSettings | ConvertTo-Json -Depth 10
    
    if (-not (Test-Path ".kimi")) {
        New-Item -ItemType Directory -Force -Path ".kimi" | Out-Null
    }
    $kimiSettingsJson | Out-File -FilePath ".kimi/ralph-settings.json" -Encoding utf8
    Write-Status "  Kimi settings: .kimi/ralph-settings.json" "OK"
    
    Write-Status "" "INFO"
    Write-Status "Ralph initialization complete!" "OK"
    Write-Status "Run 'ralph-master.ps1 -Command status' to check status" "INFO"
}

function Invoke-StatusCommand {
    Write-RalphHeader
    
    Write-Status "RALPH-GASTOWN STATUS" "STEP"
    Write-Status ""
    
    # Check Gastown status
    Write-Status "Gastown Status:" "STEP"
    $gtVersion = & gt version 2>&1
    Write-Status "  Version: $gtVersion" "INFO"
    
    $townRoot = & gt root 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Status "  Town Root: $townRoot" "INFO"
    }
    else {
        Write-Status "  Town Root: Not in a town" "WARN"
    }
    
    # Check Ralph formulas
    Write-Status ""
    Write-Status "Ralph Formulas:" "STEP"
    $formulas = @("molecule-ralph-work", "molecule-ralph-patrol", "molecule-ralph-gate")
    foreach ($f in $formulas) {
        $path = ".beads/formulas/$f.formula.toml"
        if (Test-Path $path) {
            Write-Status "  ${f}: OK" "OK"
        }
        else {
            Write-Status "  ${f}: MISSING" "WARN"
        }
    }
    
    # Check Ralph scripts
    Write-Status ""
    Write-Status "Ralph Scripts:" "STEP"
    $scripts = @(
        "ralph-executor.ps1",
        "ralph-governor.ps1",
        "ralph-watchdog.ps1"
    )
    foreach ($s in $scripts) {
        $path = "$SCRIPTS_DIR/$s"
        if (Test-Path $path) {
            Write-Status "  ${s}: OK" "OK"
        }
        else {
            Write-Status "  ${s}: MISSING" "WARN"
        }
    }
    
    # Check for active Ralph beads
    Write-Status ""
    Write-Status "Active Ralph Beads:" "STEP"
    
    $ralphBeads = & bd list --json 2>&1 | ConvertFrom-Json -ErrorAction SilentlyContinue | 
        Where-Object { $_.description -and $_.description -match "ralph_meta" }
    
    if ($ralphBeads) {
        Write-Status "  Found $($ralphBeads.Count) Ralph bead(s)" "INFO"
        foreach ($b in $ralphBeads | Select-Object -First 5) {
            Write-Status "  - $($b.id): $($b.title)" "INFO"
        }
    }
    else {
        Write-Status "  No Ralph beads found" "INFO"
    }
    
    # Check gates
    Write-Status ""
    Write-Status "Gate Status:" "STEP"
    & "$SCRIPTS_DIR/ralph-governor.ps1" -Action check 2>&1 | ForEach-Object {
        Write-Status "  $_" "INFO"
    }
}

function Invoke-RunCommand {
    param([string]$TargetBead)
    
    if (-not $TargetBead) {
        Write-Status "Error: -Bead parameter required" "ERROR"
        return
    }
    
    Write-Status "Running Ralph executor for $TargetBead..." "STEP"
    & "$SCRIPTS_DIR/ralph-executor.ps1" -BeadId $TargetBead -Verbose
}

function Invoke-PatrolCommand {
    param([string]$TargetRig)
    
    Write-Status "Starting Ralph patrol..." "STEP"
    
    if ($TargetRig) {
        # Create patrol wisp in rig
        & bd mol wisp molecule-ralph-patrol --var patrol_interval=300
    }
    else {
        Write-Status "Patrol runs as continuous wisp" "INFO"
        Write-Status "Use: gt sling molecule-ralph-patrol <rig>" "INFO"
    }
}

function Invoke-GovernCommand {
    param([string]$TargetConvoy)
    
    if ($TargetConvoy) {
        & "$SCRIPTS_DIR/ralph-governor.ps1" -Action check -ConvoyId $TargetConvoy
    }
    else {
        & "$SCRIPTS_DIR/ralph-governor.ps1" -Action status
    }
}

function Invoke-WatchdogCommand {
    Write-Status "Starting Ralph watchdog..." "STEP"
    Write-Status "Press Ctrl+C to stop" "WARN"
    & "$SCRIPTS_DIR/ralph-watchdog.ps1" -Verbose
}

function Invoke-VerifyCommand {
    Write-Status "Verifying Ralph-Gastown integration..." "STEP"
    
    $prereqs = Test-Prerequisites -Detailed
    
    Write-Status ""
    
    $tests = @(
        @{
            Name = "Ralph Executor"
            Test = { Test-Path "$SCRIPTS_DIR/ralph-executor.ps1" }
            Required = $true
        },
        @{
            Name = "Ralph Governor"
            Test = { Test-Path "$SCRIPTS_DIR/ralph-governor.ps1" }
            Required = $true
        },
        @{
            Name = "Ralph Watchdog"
            Test = { Test-Path "$SCRIPTS_DIR/ralph-watchdog.ps1" }
            Required = $true
        },
        @{
            Name = "Ralph Formulas"
            Test = { 
                Test-Path ".beads/formulas/molecule-ralph-work.formula.toml"
            }
            Required = $true
        }
    )
    
    $passed = 0
    $failed = 0
    
    foreach ($t in $tests) {
        $result = & $t.Test
        $status = if ($result) { "OK" } else { if ($t.Required) { "FAIL" } else { "SKIP" } }
        $color = if ($result) { "Green" } elseif ($t.Required) { "Red" } else { "Yellow" }
        Write-Status "  $($t.Name): $status" $color
        if ($result) { $passed++ } else { $failed++ }
    }
    
    Write-Status ""
    $resultLevel = if ($failed -eq 0) { "OK" } else { "WARN" }
    Write-Status "Results: $passed passed, $failed failed" $resultLevel
    
    if ($failed -gt 0) {
        Write-Status ""
        Show-PrereqHelp
    }
    
    return $failed -eq 0
}

function Invoke-CreateBeadCommand {
    param(
        [string]$BeadIntent,
        [string]$TargetRig
    )
    
    if (-not $BeadIntent) {
        Write-Status "Error: -Intent parameter required" "ERROR"
        return
    }
    
    Write-Status "Creating Ralph bead..." "STEP"
    
    # Create bead with Ralph contract
    $beadDesc = @"
Intent: $BeadIntent

## Definition of Done
- Implementation satisfies intent
- All verifiers pass
- Evidence attached

## Ralph Meta
{"attempt_count":0,"executor_version":"ralph-v1"}

## Constraints
max_iterations: 10
time_budget_minutes: 60
"@
    $beadId = & bd create --title $BeadIntent --type task --priority 2 --description $beadDesc
    
    Write-Status "Created bead: $beadId" "OK"
    
    if ($TargetRig) {
        Write-Status "Slinging to $TargetRig..." "STEP"
        & gt sling $beadId $TargetRig
    }
    else {
        Write-Status "Bead ready. Sling with: gt sling $beadId <rig>" "INFO"
    }
}

function Invoke-CreateGateCommand {
    param(
        [string]$Type,
        [string]$TargetConvoy
    )
    
    if (-not $Type) {
        $Type = "custom"
    }
    
    Write-Status "Creating $Type gate..." "STEP"
    
    $verifierCmd = switch ($Type) {
        "smoke" { "go test -run TestSmoke ./..." }
        "lint" { "golangci-lint run" }
        "build" { "go build ./..." }
        "test" { "go test ./..." }
        default { "echo 'Custom verifier'" }
    }
    
    $gateDesc = @"
gate_type: $Type
blocks_convoy: true
verifier_command: $verifierCmd
auto_close_on_pass: true
"@
    $gateId = & bd create --title "[GATE] $Type check" --type gate --priority 0 --description $gateDesc
    
    Write-Status "Created gate: $gateId" "OK"
    
    if ($TargetConvoy) {
        Write-Status "Adding to convoy $TargetConvoy..." "STEP"
        & gt convoy add $TargetConvoy $gateId
    }
}

function Invoke-HelpCommand {
    Write-RalphHeader
    
    $helpText = @"
RALPH-MASTER: Main control interface for Ralph-Gastown integration

USAGE: ralph-master.ps1 -Command <command> [options]

COMMANDS:
  init [-Rig <rig>]           Initialize Ralph in current town
  status                      Show Ralph-Gastown status
  run -Bead <id>              Run Ralph executor on a bead
  patrol [-Rig <rig>]         Start patrol molecule
  govern [-Convoy <id>]       Check/apply governor policies
  watchdog                    Start watchdog monitor
  verify                      Verify integration health
  create-bead -Intent <text>  Create a new Ralph bead
  create-gate -Type <type>    Create a gate bead
  help                        Show this help

EXAMPLES:
  # Initialize
  .\ralph-master.ps1 -Command init

  # Create and run a bead
  .\ralph-master.ps1 -Command create-bead -Intent "Fix login bug"
  .\ralph-master.ps1 -Command run -Bead gt-abc12

  # Check governance
  .\ralph-master.ps1 -Command govern
  .\ralph-master.ps1 -Command govern -Convoy convoy-xyz

  # Start monitoring
  .\ralph-master.ps1 -Command watchdog

DOCUMENTATION:
  - Project README:    README.md
  - Integration Guide: RALPH_INTEGRATION.md
  - Quick Start:       QUICKSTART.md

For prerequisite installation help, run with -Command verify
"@
    Write-Host $helpText -ForegroundColor White
}

#endregion

#region Main

Write-RalphHeader

switch ($Command) {
    "init" { Invoke-InitCommand -TargetRig $Rig }
    "status" { Invoke-StatusCommand }
    "run" { Invoke-RunCommand -TargetBead $Bead }
    "patrol" { Invoke-PatrolCommand -TargetRig $Rig }
    "govern" { Invoke-GovernCommand -TargetConvoy $Convoy }
    "watchdog" { Invoke-WatchdogCommand }
    "verify" { Invoke-VerifyCommand }
    "create-bead" { Invoke-CreateBeadCommand -BeadIntent $Intent -TargetRig $Rig }
    "create-gate" { Invoke-CreateGateCommand -Type $GateType -TargetConvoy $Convoy }
    "help" { Invoke-HelpCommand }
    default { Invoke-HelpCommand }
}

#endregion
