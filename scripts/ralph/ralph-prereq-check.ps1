#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Ralph-Gastown Prerequisite Checker

.DESCRIPTION
    Checks that all required dependencies are installed before running Ralph.
    This script MUST pass before any other Ralph operations.

.REQUIRED DEPENDENCIES:
    1. PowerShell 5.1+ (included with Windows 10/11)
    2. Git for Windows
    3. Gastown CLI (gt) - https://github.com/nicklynch10/gastown-cli
    4. Beads CLI (bd) - OPTIONAL (Ralph works in standalone mode without it)
    5. Kimi Code CLI - pip install kimi-cli

.PARAMETER Install
    Show installation instructions for missing dependencies.

.PARAMETER Fix
    Attempt to auto-fix issues where possible.

.EXAMPLE
    .\ralph-prereq-check.ps1
    # Check all prerequisites

.EXAMPLE
    .\ralph-prereq-check.ps1 -Install
    # Show installation help for missing dependencies
#>

[CmdletBinding()]
param(
    [switch]$Install,
    [switch]$Fix
)

$ErrorActionPreference = "Stop"

#region Configuration

$REQUIRED_PS_VERSION = [Version]"5.1"
$SCRIPT_VERSION = "1.0.0"

#endregion

#region Console Output

function Write-Status {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $colors = @{
        "INFO" = "White"
        "OK" = "Green"
        "WARN" = "Yellow"
        "ERROR" = "Red"
        "STEP" = "Cyan"
    }
    
    $icons = @{
        "INFO" = "[i]"
        "OK" = "[+]"
        "WARN" = "[!]"
        "ERROR" = "[X]"
        "STEP" = "[>]"
    }
    
    $color = $colors[$Level]
    $icon = $icons[$Level]
    
    Write-Host "$icon $Message" -ForegroundColor $color
}

function Write-Header {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  RALPH PREREQUISITE CHECKER v$SCRIPT_VERSION" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-InstallHelp {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  INSTALLATION INSTRUCTIONS             " -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "1. PowerShell 5.1+ (usually pre-installed)" -ForegroundColor Yellow
    Write-Host "   Check: `$PSVersionTable.PSVersion" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "2. Git for Windows" -ForegroundColor Yellow
    Write-Host "   Option A: winget install Git.Git" -ForegroundColor Gray
    Write-Host "   Option B: https://git-scm.com/download/win" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "3. Go (required for gt and bd CLI tools)" -ForegroundColor Yellow
    Write-Host "   Option A: winget install GoLang.Go" -ForegroundColor Gray
    Write-Host "   Option B: https://go.dev/dl/" -ForegroundColor Gray
    Write-Host "   Verify: go version" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "4. Gastown CLI (gt)" -ForegroundColor Yellow
    Write-Host "   Install: go install github.com/nicklynch10/gastown-cli/cmd/gt@latest" -ForegroundColor Gray
    Write-Host "   Verify: gt version" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "5. Beads CLI (bd) - OPTIONAL" -ForegroundColor Yellow
    Write-Host "   Note: Ralph works without bd using standalone JSON file mode" -ForegroundColor Gray
    Write-Host "   The gt bead subcommand provides limited bead functionality" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "6. Kimi Code CLI" -ForegroundColor Yellow
    Write-Host "   Requires Python 3.8+" -ForegroundColor Gray
    Write-Host "   Install: pip install kimi-cli" -ForegroundColor Gray
    Write-Host "   Or: pip3 install kimi-cli" -ForegroundColor Gray
    Write-Host "   Verify: kimi --version" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "========================================" -ForegroundColor Cyan
}

#endregion

#region Checks

function Test-PowerShellVersion {
    Write-Status "Checking PowerShell version..." "STEP"
    
    $currentVersion = $PSVersionTable.PSVersion
    $meetsRequirement = $currentVersion -ge $REQUIRED_PS_VERSION
    
    if ($meetsRequirement) {
        Write-Status "PowerShell $currentVersion [OK]" "OK"
        return @{ Passed = $true; Version = $currentVersion }
    } else {
        Write-Status "PowerShell $currentVersion [FAIL - Requires $REQUIRED_PS_VERSION+]" "ERROR"
        return @{ Passed = $false; Version = $currentVersion }
    }
}

function Test-ExecutionPolicy {
    Write-Status "Checking execution policy..." "STEP"
    
    $policy = Get-ExecutionPolicy
    $effectivePolicy = Get-ExecutionPolicy -Scope Process
    
    $acceptablePolicies = @("RemoteSigned", "Unrestricted", "Bypass")
    
    if ($acceptablePolicies -contains $effectivePolicy) {
        Write-Status "Execution Policy: $effectivePolicy [OK]" "OK"
        return @{ Passed = $true; Policy = $effectivePolicy }
    } else {
        Write-Status "Execution Policy: $effectivePolicy [WARN]" "WARN"
        Write-Status "  Current policy may prevent script execution" "WARN"
        Write-Status "  Current user policy: $policy" "INFO"
        
        if ($Fix) {
            Write-Status "Attempting to set execution policy..." "STEP"
            try {
                Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force
                Write-Status "Execution policy set to RemoteSigned for current process" "OK"
                return @{ Passed = $true; Policy = "RemoteSigned (fixed)" }
            } catch {
                Write-Status "Failed to set execution policy: $_" "ERROR"
            }
        }
        
        return @{ 
            Passed = $false
            Policy = $effectivePolicy
            FixCommand = "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser"
        }
    }
}

function Test-CommandAvailable {
    param(
        [string]$Name,
        [string]$DisplayName,
        [string]$VersionFlag = "--version",
        [switch]$Required
    )
    
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    
    if ($cmd) {
        try {
            $versionOutput = & $Name $VersionFlag 2>&1 | Select-Object -First 1
            Write-Status "$DisplayName found: $versionOutput" "OK"
            return @{ Passed = $true; Path = $cmd.Source; Version = $versionOutput }
        } catch {
            Write-Status "$DisplayName found (version check failed)" "OK"
            return @{ Passed = $true; Path = $cmd.Source; Version = "unknown" }
        }
    } else {
        $level = if ($Required) { "ERROR" } else { "WARN" }
        Write-Status "$DisplayName not found in PATH" $level
        return @{ Passed = (-not $Required); Required = $Required }
    }
}

function Test-GitConfiguration {
    Write-Status "Checking Git configuration..." "STEP"
    
    $git = Get-Command git -ErrorAction SilentlyContinue
    if (-not $git) {
        Write-Status "Git not found, skipping config check" "WARN"
        return @{ Passed = $false }
    }
    
    try {
        $userName = git config user.name 2>$null
        $userEmail = git config user.email 2>$null
        
        if (-not $userName -or -not $userEmail) {
            Write-Status "Git user name or email not set" "WARN"
            Write-Status "  Run: git config --global user.name 'Your Name'" "INFO"
            Write-Status "  Run: git config --global user.email 'your@email.com'" "INFO"
            return @{ Passed = $false; UserName = $userName; UserEmail = $userEmail }
        }
        
        Write-Status "Git configured: $userName <$userEmail>" "OK"
        return @{ Passed = $true; UserName = $userName; UserEmail = $userEmail }
    } catch {
        Write-Status "Git config check failed: $_" "WARN"
        return @{ Passed = $false }
    }
}

function Test-LineEndingConfiguration {
    Write-Status "Checking Git line ending configuration..." "STEP"
    
    $git = Get-Command git -ErrorAction SilentlyContinue
    if (-not $git) {
        return @{ Passed = $true }  # Skip if git not available
    }
    
    $coreAutocrlf = git config core.autocrlf 2>$null
    
    if ($coreAutocrlf -eq "true" -or $coreAutocrlf -eq "input") {
        Write-Status "Git core.autocrlf = $coreAutocrlf [OK]" "OK"
        return @{ Passed = $true; Setting = $coreAutocrlf }
    } else {
        Write-Status "Git core.autocrlf not set (recommended: true)" "WARN"
        Write-Status "  Run: git config --global core.autocrlf true" "INFO"
        return @{ 
            Passed = $true  # Not a blocking issue
            Setting = $coreAutocrlf
            Recommendation = "git config --global core.autocrlf true"
        }
    }
}

function Test-TownStructure {
    Write-Status "Checking Gastown town structure..." "STEP"
    
    $gt = Get-Command gt -ErrorAction SilentlyContinue
    if (-not $gt) {
        Write-Status "gt CLI not found, cannot check town structure" "WARN"
        return @{ Passed = $false; Reason = "gt not available" }
    }
    
    try {
        $townRoot = & gt root 2>$null
        if ($LASTEXITCODE -eq 0 -and $townRoot) {
            Write-Status "In Gastown town: $townRoot" "OK"
            
            # Check for required directories
            $requiredDirs = @(".beads", ".githooks")
            $missingDirs = @()
            
            foreach ($dir in $requiredDirs) {
                $fullPath = Join-Path $townRoot $dir
                if (-not (Test-Path $fullPath)) {
                    $missingDirs += $dir
                }
            }
            
            if ($missingDirs.Count -eq 0) {
                Write-Status "All required directories present" "OK"
                return @{ Passed = $true; TownRoot = $townRoot }
            } else {
                Write-Status "Missing directories: $($missingDirs -join ', ')" "WARN"
                return @{ Passed = $true; TownRoot = $townRoot; MissingDirs = $missingDirs }
            }
        } else {
            Write-Status "Not in a Gastown town" "WARN"
            Write-Status "  Run: gt init (to initialize a new town)" "INFO"
            return @{ Passed = $false; Reason = "Not in a town" }
        }
    } catch {
        Write-Status "Town check failed: $_" "WARN"
        return @{ Passed = $false; Reason = $_.Exception.Message }
    }
}

function Test-PythonAvailability {
    Write-Status "Checking Python availability..." "STEP"
    
    $pythonCommands = @("python", "python3", "py")
    $foundPython = $null
    
    foreach ($cmd in $pythonCommands) {
        $found = Get-Command $cmd -ErrorAction SilentlyContinue
        if ($found) {
            try {
                $version = & $cmd --version 2>&1 | Select-Object -First 1
                Write-Status "Python found: $cmd - $version" "OK"
                $foundPython = @{ Command = $cmd; Path = $found.Source; Version = $version }
                break
            } catch {
                continue
            }
        }
    }
    
    if (-not $foundPython) {
        Write-Status "Python not found in PATH" "ERROR"
        Write-Status "  Kimi CLI requires Python 3.8+" "INFO"
        return @{ Passed = $false }
    }
    
    return @{ Passed = $true; Python = $foundPython }
}

#endregion

#region Main

Write-Header

Write-Status "Checking prerequisites for Ralph-Gastown..." "STEP"
Write-Host ""

$results = @{
    PowerShell = Test-PowerShellVersion
    ExecutionPolicy = Test-ExecutionPolicy
    Python = Test-PythonAvailability
    Git = Test-CommandAvailable -Name "git" -DisplayName "Git" -VersionFlag "--version" -Required:$true
    GitConfig = Test-GitConfiguration
    LineEndings = Test-LineEndingConfiguration
    Kimi = Test-CommandAvailable -Name "kimi" -DisplayName "Kimi CLI" -Required:$true
    Go = Test-CommandAvailable -Name "go" -DisplayName "Go" -VersionFlag "version" -Required:$true
    GT = Test-CommandAvailable -Name "gt" -DisplayName "Gastown CLI (gt)" -Required:$true
    BD = Test-CommandAvailable -Name "bd" -DisplayName "Beads CLI (bd)" -Required:$false
    Town = Test-TownStructure
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  PREREQUISITE CHECK SUMMARY            " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$requiredPassed = 0
$requiredTotal = 0
$warnings = 0

foreach ($check in $results.GetEnumerator()) {
    $name = $check.Key
    $result = $check.Value
    
    $isRequired = $name -in @("PowerShell", "ExecutionPolicy", "Git", "Kimi", "Go", "GT")
    
    if ($isRequired) {
        $requiredTotal++
        if ($result.Passed) {
            $requiredPassed++
            Write-Host "[PASS] $name" -ForegroundColor Green
        } else {
            Write-Host "[FAIL] $name" -ForegroundColor Red
        }
    } else {
        if ($result.Passed) {
            Write-Host "[OK]   $name" -ForegroundColor Green
        } else {
            Write-Host "[WARN] $name" -ForegroundColor Yellow
            $warnings++
        }
    }
}

Write-Host ""
Write-Host "Required: $requiredPassed/$requiredTotal passed" -ForegroundColor $(if($requiredPassed -eq $requiredTotal){"Green"}else{"Red"})
Write-Host "Warnings: $warnings" -ForegroundColor $(if($warnings -eq 0){"Green"}else{"Yellow"})

Write-Host ""

if ($requiredPassed -eq $requiredTotal) {
    Write-Status "ALL PREREQUISITES MET" "OK"
    Write-Status "You can now use Ralph-Gastown" "OK"
    
    if ($Install) {
        Write-InstallHelp
    }
    
    exit 0
} else {
    Write-Status "MISSING PREREQUISITES" "ERROR"
    Write-Status "Please install the missing dependencies listed above" "ERROR"
    
    Write-InstallHelp
    
    exit 1
}

#endregion
