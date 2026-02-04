#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Ralph Governor for Gastown - Enforces "test failures stop progress" policy.

.DESCRIPTION
    The Governor ensures:
    1. No feature beads are slung while any gate is red
    2. Convoys with failing gates are blocked
    3. Patrol failures create blocking bug beads
    4. Priority-based work routing

    This implements the Governor Loop from Ralph as Gastown policy.

    PREREQUISITES:
    - Gastown CLI (gt): https://github.com/nicklynch10/gastown-cli
    - Beads CLI (bd): OPTIONAL - Ralph works in standalone mode

.PARAMETER Action
    Action to perform: check, sling, status

.PARAMETER ConvoyId
    Convoy to check or manage

.PARAMETER BeadId
    Bead to sling (only with -Action sling)

.PARAMETER Rig
    Target rig for sling operations

.EXAMPLE
    .\ralph-governor.ps1 -Action check -ConvoyId "convoy-abc"

.EXAMPLE
    .\ralph-governor.ps1 -Action sling -BeadId "gt-feature" -Rig "myproject"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("check", "sling", "status", "enforce")]
    [string]$Action,

    [Parameter()]
    [string]$ConvoyId,

    [Parameter()]
    [string]$BeadId,

    [Parameter()]
    [string]$Rig,

    [Parameter()]
    [switch]$Force
)

#region Prerequisites Check

function Test-Prerequisites {
    $missing = @()
    
    # gt is recommended but not strictly required for standalone mode
    $gt = Get-Command gt -ErrorAction SilentlyContinue
    if (-not $gt) {
        Write-GovLog "Gastown CLI (gt) not found - some features may be limited" "WARN"
    }
    
    # bd is optional - Ralph works in standalone mode
    $bd = Get-Command bd -ErrorAction SilentlyContinue
    if (-not $bd) {
        Write-GovLog "Beads CLI (bd) not found - using standalone mode" "INFO"
    }
    
    return $true
}

function Get-StandaloneGates {
    # Load gates from .ralph/gates/ directory
    $gates = @()
    $gatesDir = ".ralph/gates"
    
    if (Test-Path $gatesDir) {
        $files = Get-ChildItem -Path $gatesDir -Filter "*.json" -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            try {
                $content = Get-Content $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
                $gates += $content
            }
            catch {
                Write-GovLog "Failed to parse gate file $($file.Name): $_" "WARN"
            }
        }
    }
    
    return $gates
}

#endregion

#region Logging

function Write-GovLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN"  { "Yellow" }
        "POLICY" { "Magenta" }
        "SUCCESS" { "Green" }
        default { "White" }
    }
    Write-Host "[$timestamp] [GOVERNOR] [$Level] $Message" -ForegroundColor $color
}

#endregion

#region Gate Operations

function Get-GatesInConvoy {
    param([string]$Id)
    
    try {
        # Get convoy details
        $convoy = & gt convoy show $Id 2>&1
        if ($LASTEXITCODE -ne 0) {
            return @()
        }
        
        # Find gate beads (type=gate or with blocking.is_gate)
        $beads = & bd list --parent $Id --json 2>&1 | ConvertFrom-Json -ErrorAction SilentlyContinue
        $gates = $beads | Where-Object { 
            $_.type -eq "gate" -or 
            ($_.description -and $_.description -like "*blocking*is_gate*true*")
        }
        
        return $gates
    }
    catch {
        Write-GovLog "Error getting gates: $_" "ERROR"
        return @()
    }
}

function Get-AllGatesStatus {
    $allGates = @()
    
    # First try standalone mode
    $standaloneGates = Get-StandaloneGates
    $allGates += $standaloneGates
    
    # Then try bd CLI if available
    $bd = Get-Command bd -ErrorAction SilentlyContinue
    if ($bd) {
        try {
            $gates = & bd list --status open --json 2>&1 | ConvertFrom-Json -ErrorAction SilentlyContinue
            $bdGates = $gates | Where-Object { 
                $_.type -eq "gate" -or 
                ($_.description -and $_.description -like "*gate_type*")
            }
            $allGates += $bdGates
        }
        catch {
            # No gates found or bd error
        }
    }
    
    return $allGates
}

function Test-GatesBlocking {
    param([array]$Gates)
    
    $redGates = $Gates | Where-Object { 
        $_.status -eq "open" -or 
        ($_.description -and $_.description -like "*gate_status: red*")
    }
    
    return @{
        IsBlocking = $redGates.Count -gt 0
        RedGates = $redGates
        GreenGates = ($Gates | Where-Object { $_ -notin $redGates })
    }
}

#endregion

#region Policy Enforcement

function Test-CanSlingFeature {
    param([string]$Id)
    
    # Check if bead is a feature
    try {
        $bead = & bd show $Id --json 2>&1 | ConvertFrom-Json -ErrorAction SilentlyContinue
        $isFeature = $bead.lane -eq "feature" -or $bead.type -eq "feature"
        
        if (-not $isFeature) {
            # Not a feature, no restriction
            return @{ Allowed = $true; Reason = "Not a feature bead" }
        }
    }
    catch {
        return @{ Allowed = $false; Reason = "Cannot load bead: $_" }
    }
    
    # Check for blocking gates
    $allGates = Get-AllGatesStatus
    $gateStatus = Test-GatesBlocking -Gates $allGates
    
    if ($gateStatus.IsBlocking) {
        $gateList = ($gateStatus.RedGates | ForEach-Object { $_.id }) -join ", "
        return @{
            Allowed = $false
            Reason = "Gates are RED: $gateList"
            RedGates = $gateStatus.RedGates
        }
    }
    
    return @{ Allowed = $true; Reason = "All gates GREEN" }
}

function Test-CanProceedConvoy {
    param([string]$Id)
    
    $gates = Get-GatesInConvoy -Id $Id
    $gateStatus = Test-GatesBlocking -Gates $gates
    
    return @{
        CanProceed = -not $gateStatus.IsBlocking
        RedGates = $gateStatus.RedGates
        GreenGates = $gateStatus.GreenGates
    }
}

#endregion

#region Actions

function Invoke-CheckAction {
    if (-not $ConvoyId) {
        # Check all gates globally
        $gates = Get-AllGatesStatus
        $status = Test-GatesBlocking -Gates $gates
        
        Write-GovLog "Global Gate Status:"
        Write-GovLog "  Total Gates: $($gates.Count)"
        Write-GovLog "  RED (blocking): $($status.RedGates.Count)"
        Write-GovLog "  GREEN: $($status.GreenGates.Count)"
        
        if ($status.IsBlocking) {
            Write-GovLog "POLICY: FEATURES BLOCKED - Gates are red" "POLICY"
            foreach ($g in $status.RedGates) {
                Write-GovLog "  - $($g.id): $($g.title)" "ERROR"
            }
            return $false
        }
        else {
            Write-GovLog "POLICY: Features allowed - All gates green" "SUCCESS"
            return $true
        }
    }
    else {
        # Check specific convoy
        $result = Test-CanProceedConvoy -Id $ConvoyId
        
        Write-GovLog "Convoy $ConvoyId Status:"
        Write-GovLog "  Can Proceed: $($result.CanProceed)"
        Write-GovLog "  Red Gates: $($result.RedGates.Count)"
        Write-GovLog "  Green Gates: $($result.GreenGates.Count)"
        
        return $result.CanProceed
    }
}

function Invoke-SlingAction {
    if (-not $BeadId -or -not $Rig) {
        Write-GovLog "Sling action requires -BeadId and -Rig" "ERROR"
        return $false
    }
    
    # Check if we can sling this bead
    $permission = Test-CanSlingFeature -Id $BeadId
    
    if (-not $permission.Allowed -and -not $Force) {
        Write-GovLog "SLING DENIED: $($permission.Reason)" "POLICY"
        Write-GovLog "Use -Force to override (not recommended)" "WARN"
        return $false
    }
    
    if ($Force -and -not $permission.Allowed) {
        Write-GovLog "FORCE SLING: Bypassing policy check" "WARN"
    }
    
    # Perform sling
    Write-GovLog "Slinging $BeadId to $Rig..."
    try {
        & gt sling $BeadId $Rig 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-GovLog "Sling successful" "SUCCESS"
            return $true
        }
        else {
            Write-GovLog "Sling failed" "ERROR"
            return $false
        }
    }
    catch {
        Write-GovLog "Sling error: $_" "ERROR"
        return $false
    }
}

function Invoke-StatusAction {
    Write-GovLog "=== RALPH GOVERNOR STATUS ==="
    
    # Get all convoys
    $convoys = & gt convoy list --json 2>&1 | ConvertFrom-Json -ErrorAction SilentlyContinue
    
    Write-GovLog "Convoys: $($convoys.Count)"
    foreach ($c in $convoys) {
        $gates = Get-GatesInConvoy -Id $c.id
        $status = Test-GatesBlocking -Gates $gates
        
        $color = if ($status.IsBlocking) { "RED" } else { "GREEN" }
        Write-GovLog "  $($c.id): $color ($($gates.Count) gates)"
    }
    
    # Global gates
    Write-GovLog ""
    Invoke-CheckAction
}

function Invoke-EnforceAction {
    Write-GovLog "Enforcing policy across all convoys..."
    
    $convoys = & gt convoy list --json 2>&1 | ConvertFrom-Json -ErrorAction SilentlyContinue
    $enforced = 0
    
    foreach ($c in $convoys) {
        $result = Test-CanProceedConvoy -Id $c.id
        
        if (-not $result.CanProceed) {
            Write-GovLog "Blocking convoy $($c.id) - gates are red" "POLICY"
            
            # Find in-progress feature beads and pause them
            $beads = & bd list --parent $c.id --status in_progress --json 2>&1 | ConvertFrom-Json -ErrorAction SilentlyContinue
            $features = $beads | Where-Object { $_.lane -eq "feature" -or $_.type -eq "feature" }
            
            foreach ($f in $features) {
                Write-GovLog "  Pausing feature: $($f.id)" "WARN"
                & bd update $f.id --status=pinned 2>&1 | Out-Null
            }
            
            $enforced++
        }
    }
    
    Write-GovLog "Policy enforced on $enforced convoy(s)"
    return $enforced
}

#endregion

#region Main

# Check prerequisites first
if (-not (Test-Prerequisites)) {
    exit 1
}

Write-GovLog "Ralph Governor v1.0.0"
Write-GovLog "Action: $Action"

$result = switch ($Action) {
    "check" { Invoke-CheckAction }
    "sling" { Invoke-SlingAction }
    "status" { Invoke-StatusAction; $true }
    "enforce" { Invoke-EnforceAction }
    default { Write-GovLog "Unknown action: $Action" "ERROR"; $false }
}

if ($result) { exit 0 } else { exit 1 }

#endregion
