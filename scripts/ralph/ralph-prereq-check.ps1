#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Ralph-Gastown Prerequisites Checker

.DESCRIPTION
    Comprehensive prerequisite validation for the Ralph-Gastown SDLC system.
    Checks all required tools, versions, and environment settings.

.PARAMETER Fix
    Attempt to fix missing prerequisites where possible

.PARAMETER Quiet
    Return exit code only, minimal output

.EXAMPLE
    .\ralph-prereq-check.ps1

.EXAMPLE
    .\ralph-prereq-check.ps1 -Fix
#>

[CmdletBinding()]
param(
    [switch]$Fix,
    [switch]$Quiet
)

$SCRIPT_VERSION = "1.0.0"

#region Requirements Definition

$REQUIREMENTS = @{
    PowerShell = @{
        Name = "PowerShell"
        MinVersion = [Version]"5.1"
        Command = { $PSVersionTable.PSVersion }
        Required = $true
        InstallHelp = "PowerShell 5.1+ is included with Windows. For PowerShell 7+, visit https://github.com/PowerShell/PowerShell"
    }
    Git = @{
        Name = "Git"
        Command = "git"
        VersionArg = "--version"
        Required = $true
        InstallHelp = "Download from https://git-scm.com/download/win or run: winget install Git.Git"
    }
    Kimi = @{
        Name = "Kimi Code CLI"
        Command = "kimi"
        VersionArg = "--version"
        Required = $true
        InstallHelp = "Install: pip install kimi-cli (requires Python 3.8+)"
    }
    Go = @{
        Name = "Go"
        Command = "go"
        VersionArg = "version"
        Required = $false  # Optional - only needed for Go projects
        InstallHelp = "Download from https://go.dev/dl/ or run: winget install GoLang.Go"
    }
    Node = @{
        Name = "Node.js"
        Command = "node"
        VersionArg = "--version"
        Required = $false  # Optional - only needed for Node.js/browser testing
        InstallHelp = "Download from https://nodejs.org/ or run: winget install OpenJS.NodeJS"
    }
}

#endregion

#region Output Functions

function Write-CheckHeader {
    if ($Quiet) { return }
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "    RALPH-GASTOWN PREREQUISITE CHECK    " -ForegroundColor Cyan
    Write-Host "    Version $SCRIPT_VERSION                  " -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-CheckResult {
    param(
        [string]$Tool,
        [bool]$Passed,
        [string]$Version = "",
        [string]$Message = "",
        [bool]$IsOptional = $false
    )
    if ($Quiet) { return }
    
    $icon = if ($Passed) { "[OK]" } else { if ($IsOptional) { "[WARN]" } else { "[FAIL]" } }
    $color = if ($Passed) { "Green" } elseif ($IsOptional) { "Yellow" } else { "Red" }
    
    $versionStr = if ($Version) { " ($Version)" } else { "" }
    Write-Host "  $icon $Tool$versionStr" -ForegroundColor $color
    
    if ($Message) {
        Write-Host "       $Message" -ForegroundColor Gray
    }
}

function Write-Section {
    param([string]$Title)
    if ($Quiet) { return }
    Write-Host ""
    Write-Host "$Title" -ForegroundColor Yellow
    Write-Host ("-" * 50) -ForegroundColor Gray
}

function Write-Footer {
    param([bool]$AllPassed, [bool]$HasOptionalMissing)
    if ($Quiet) { return }
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    if ($AllPassed) {
        Write-Host "    ALL PREREQUISITES SATISFIED        " -ForegroundColor Green
    } else {
        Write-Host "    PREREQUISITES MISSING              " -ForegroundColor Red
    }
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

#endregion

#region Check Functions

function Test-CommandExists {
    param([string]$Command)
    return (Get-Command $Command -ErrorAction SilentlyContinue) -ne $null
}

function Get-ToolVersion {
    param([string]$Command, [string]$VersionArg)
    
    try {
        $output = & $Command $VersionArg 2>&1 | Select-Object -First 1
        return $output
    } catch {
        return $null
    }
}

function Test-PowerShellVersion {
    $version = $PSVersionTable.PSVersion
    $minVersion = $REQUIREMENTS.PowerShell.MinVersion
    
    return @{
        Passed = $version -ge $minVersion
        Version = $version.ToString()
        Message = if ($version -ge $minVersion) { "" } else { "Version $version is below minimum $minVersion" }
    }
}

function Test-Tool {
    param([hashtable]$Requirement)
    
    $exists = Test-CommandExists -Command $Requirement.Command
    
    if (-not $exists) {
        return @{
            Passed = $false
            Version = ""
            Message = "Not found in PATH. $($Requirement.InstallHelp)"
        }
    }
    
    $version = if ($Requirement.VersionArg) {
        Get-ToolVersion -Command $Requirement.Command -VersionArg $Requirement.VersionArg
    } else { "" }
    
    return @{
        Passed = $true
        Version = $version
        Message = ""
    }
}

function Test-ExecutionPolicy {
    $policy = Get-ExecutionPolicy
    $effectivePolicy = Get-ExecutionPolicy -Scope Process
    
    $isRestricted = $policy -eq "Restricted" -or $effectivePolicy -eq "Restricted"
    
    return @{
        Passed = -not $isRestricted
        CurrentPolicy = $policy
        ProcessPolicy = $effectivePolicy
        Message = if ($isRestricted) { "Execution policy is Restricted. Run: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser" } else { "" }
    }
}

function Test-GitConfiguration {
    try {
        $userName = git config user.name 2>$null
        $userEmail = git config user.email 2>$null
        
        $missing = @()
        if (-not $userName) { $missing += "user.name" }
        if (-not $userEmail) { $missing += "user.email" }
        
        return @{
            Passed = $missing.Count -eq 0
            Message = if ($missing.Count -gt 0) { "Missing git config: $($missing -join ', '). Run: git config --global user.name 'Your Name' && git config --global user.email 'your@email.com'" } else { "" }
        }
    } catch {
        return @{
            Passed = $false
            Message = "Git configuration check failed: $_"
        }
    }
}

#endregion

#region Main Check Logic

function Start-PrerequisiteCheck {
    Write-CheckHeader
    
    $results = @{
        RequiredPassed = 0
        RequiredTotal = 0
        OptionalPassed = 0
        OptionalTotal = 0
        Failed = @()
    }
    
    Write-Section -Title "Core Requirements"
    
    # Check PowerShell
    $psResult = Test-PowerShellVersion
    $results.RequiredTotal++
    if ($psResult.Passed) { $results.RequiredPassed++ }
    else { $results.Failed += "PowerShell" }
    Write-CheckResult -Tool "PowerShell" -Passed $psResult.Passed -Version $psResult.Version -Message $psResult.Message
    
    # Check Execution Policy
    $execResult = Test-ExecutionPolicy
    if (-not $Quiet) {
        $icon = if ($execResult.Passed) { "[OK]" } else { "[WARN]" }
        $color = if ($execResult.Passed) { "Green" } else { "Yellow" }
        Write-Host "  $icon Execution Policy: $($execResult.CurrentPolicy) (Process: $($execResult.ProcessPolicy))" -ForegroundColor $color
        if ($execResult.Message) {
            Write-Host "       $($execResult.Message)" -ForegroundColor Gray
        }
    }
    
    # Check Git
    $gitResult = Test-Tool -Requirement $REQUIREMENTS.Git
    $results.RequiredTotal++
    if ($gitResult.Passed) { $results.RequiredPassed++ }
    else { $results.Failed += "Git" }
    Write-CheckResult -Tool "Git" -Passed $gitResult.Passed -Version $gitResult.Version -Message $gitResult.Message
    
    # Check Git configuration
    if ($gitResult.Passed) {
        $gitConfigResult = Test-GitConfiguration
        if (-not $Quiet) {
            $icon = if ($gitConfigResult.Passed) { "[OK]" } else { "[WARN]" }
            $color = if ($gitConfigResult.Passed) { "Green" } else { "Yellow" }
            Write-Host "  $icon Git Configuration" -ForegroundColor $color
            if ($gitConfigResult.Message) {
                Write-Host "       $($gitConfigResult.Message)" -ForegroundColor Gray
            }
        }
    }
    
    # Check Kimi (Required)
    Write-Section -Title "Ralph-Specific Requirements"
    $kimiResult = Test-Tool -Requirement $REQUIREMENTS.Kimi
    $results.RequiredTotal++
    if ($kimiResult.Passed) { $results.RequiredPassed++ }
    else { $results.Failed += "Kimi" }
    Write-CheckResult -Tool "Kimi Code CLI" -Passed $kimiResult.Passed -Version $kimiResult.Version -Message $kimiResult.Message
    
    Write-Section -Title "Optional Requirements"
    
    # Check Go (Optional)
    $goResult = Test-Tool -Requirement $REQUIREMENTS.Go
    $results.OptionalTotal++
    if ($goResult.Passed) { $results.OptionalPassed++ }
    Write-CheckResult -Tool "Go" -Passed $goResult.Passed -Version $goResult.Version -Message $goResult.Message -IsOptional:$true
    
    # Check Node (Optional)
    $nodeResult = Test-Tool -Requirement $REQUIREMENTS.Node
    $results.OptionalTotal++
    if ($nodeResult.Passed) { $results.OptionalPassed++ }
    Write-CheckResult -Tool "Node.js" -Passed $nodeResult.Passed -Version $nodeResult.Version -Message $nodeResult.Message -IsOptional:$true
    
    # Summary
    $allRequiredPassed = $results.RequiredPassed -eq $results.RequiredTotal
    $hasOptionalMissing = $results.OptionalPassed -lt $results.OptionalTotal
    
    Write-Footer -AllPassed $allRequiredPassed -HasOptionalMissing:$hasOptionalMissing
    
    if (-not $Quiet) {
        Write-Host "Required: $($results.RequiredPassed)/$($results.RequiredTotal) passed" -ForegroundColor $(if($allRequiredPassed){"Green"}else{"Red"})
        Write-Host "Optional: $($results.OptionalPassed)/$($results.OptionalTotal) passed" -ForegroundColor Yellow
        
        if ($results.Failed.Count -gt 0) {
            Write-Host ""
            Write-Host "Missing Required Tools:" -ForegroundColor Red
            foreach ($tool in $results.Failed) {
                Write-Host "  - $tool" -ForegroundColor Yellow
            }
        }
    }
    
    return $allRequiredPassed
}

#endregion

#region Main

$passed = Start-PrerequisiteCheck

if ($passed) {
    exit 0
} else {
    exit 1
}

#endregion
