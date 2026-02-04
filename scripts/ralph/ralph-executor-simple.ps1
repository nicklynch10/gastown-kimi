#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Simplified Ralph executor for Gastown - Windows-native retry loop.

.DESCRIPTION
    A simplified implementation of the Ralph executor that focuses on
    core functionality with cleaner PowerShell syntax.
    
    Can operate in two modes:
    1. Database mode (-BeadId): Uses bd CLI to load beads from database
    2. Standalone mode (-BeadFile): Loads beads from JSON files directly

.PARAMETER BeadId
    The bead ID to implement (requires bd CLI).

.PARAMETER BeadFile
    Path to a bead JSON file (standalone mode, no bd CLI required).

.PARAMETER MaxIterations
    Maximum number of retry iterations.

.PARAMETER DryRun
    Show what would be done without executing.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, ParameterSetName = "Database")]
    [string]$BeadId,

    [Parameter(Mandatory = $true, ParameterSetName = "Standalone")]
    [string]$BeadFile,

    [Parameter()]
    [int]$MaxIterations = 10,

    [Parameter()]
    [switch]$DryRun
)

$RALPH_VERSION = "1.0.0"
$DEFAULT_BACKOFF = 30

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $colorMap = @{
        "ERROR" = "Red"
        "WARN" = "Yellow"
        "SUCCESS" = "Green"
    }
    $color = $colorMap[$Level]
    if (-not $color) { $color = "White" }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Show-PrereqError {
    Write-Log "Missing required tools. Please install:" "ERROR"
    Write-Log "  - Kimi CLI: pip install kimi-cli" "INFO"
    Write-Log "  - Beads CLI: OPTIONAL - Ralph works in standalone mode" "INFO"
    Write-Log "See RALPH_INTEGRATION.md for details" "INFO"
}

Write-Log "Ralph Executor Simple v$RALPH_VERSION"
if ($BeadFile) {
    Write-Log "Mode: Standalone (BeadFile)"
    Write-Log "Bead File: $BeadFile"
} else {
    Write-Log "Mode: Database (BeadId)"
    Write-Log "Bead: $BeadId"
}
Write-Log "Max Iterations: $MaxIterations"

# Check prerequisites
$kimi = Get-Command kimi -ErrorAction SilentlyContinue
if (-not $kimi) {
    Write-Log "Kimi CLI not found" "ERROR"
    Show-PrereqError
    exit 1
}

# Load bead (supports both database and standalone modes)
if ($BeadFile) {
    # Standalone mode - load from JSON file
    Write-Log "Loading bead from file..."
    if (-not (Test-Path $BeadFile)) {
        Write-Log "Bead file not found: $BeadFile" "ERROR"
        exit 1
    }
    try {
        $beadJson = Get-Content $BeadFile -Raw -Encoding UTF8
        $bead = $beadJson | ConvertFrom-Json
        Write-Log "Bead loaded: $($bead.title)"
    } catch {
        Write-Log "Failed to parse bead file: $_" "ERROR"
        exit 1
    }
} else {
    # Database mode - requires bd CLI
    $bd = Get-Command bd -ErrorAction SilentlyContinue
    if (-not $bd) {
        Write-Log "Beads CLI not found. Use -BeadFile for standalone mode." "ERROR"
        Show-PrereqError
        exit 1
    }
    
    Write-Log "Loading bead from database..."
    try {
        $beadJson = & bd show $BeadId --json 2>&1
        $bead = $beadJson | ConvertFrom-Json
        Write-Log "Bead loaded: $($bead.title)"
    } catch {
        Write-Log "Failed to load bead: $_" "ERROR"
        exit 1
    }
}

# Validate bead
if (-not $bead.intent) {
    Write-Log "Bead missing intent field" "ERROR"
    exit 1
}

if (-not $bead.dod -or -not $bead.dod.verifiers) {
    Write-Log "Bead missing DoD verifiers" "ERROR"
    exit 1
}

Write-Log "Intent: $($bead.intent)"
Write-Log "Verifiers: $($bead.dod.verifiers.Count)"

if ($DryRun) {
    Write-Log "DRY RUN - Would execute:"
    Write-Log "  1. Run verifiers (expecting failures - TDD)"
    Write-Log "  2. Invoke Kimi with context"
    Write-Log "  3. Re-run verifiers until all pass"
    Write-Log "  4. Mark bead complete"
    exit 0
}

# Main Ralph loop
$iteration = 0
$verifiers = $bead.dod.verifiers
$maxIter = $bead.constraints.max_iterations
if (-not $maxIter) { $maxIter = $MaxIterations }

while ($iteration -lt $maxIter) {
    $iteration++
    Write-Log "Iteration $iteration / $maxIter" "WARN"
    
    # Build prompt for Kimi
    $intent = $bead.intent
    $verifierList = ($verifiers | ForEach-Object { "- $($_.name): $($_.command)" }) -join "`n"
    
    $promptText = @"
RALPH IMPLEMENTATION TASK

Intent: $intent

Definition of Done - ALL these verifiers MUST pass:
$verifierList

IMPORTANT: PowerShell 5.1 Environment
- Use semicolons (;) instead of && for command chaining
- Example: git add file.ps1; git commit -m "message"
- Use Set-Location instead of cd
- Nest Join-Path calls: Join-Path (Join-Path $root "subdir") "file.txt"

Instructions:
1. First, run the verifiers to understand what needs to be implemented (TDD)
2. Implement the solution to satisfy the intent
3. Run verifiers again - they MUST all pass
4. Do NOT mark work complete until ALL verifiers pass

Output:
- Implement the solution
- Ensure all verifiers pass
- Commit changes
"@
    
    # Save prompt to temp file
    $tempFile = [System.IO.Path]::GetTempFileName()
    $promptText | Out-File -FilePath $tempFile -Encoding utf8
    
    Write-Log "Invoking Kimi..."
    
    try {
        # Use --print mode with piped stdin (PowerShell 5.1 compatible)
        $proc = Start-Process -FilePath "kimi" `
            -ArgumentList @("--yolo", "--print") `
            -RedirectStandardInput $tempFile `
            -Wait -PassThru -NoNewWindow
        $kimiExit = $proc.ExitCode
    } catch {
        Write-Log "Kimi invocation failed: $_" "ERROR"
        Remove-Item $tempFile -ErrorAction SilentlyContinue
        continue
    }
    
    Remove-Item $tempFile -ErrorAction SilentlyContinue
    
    if ($kimiExit -ne 0) {
        Write-Log "Kimi exited with code $kimiExit" "WARN"
    }
    
    # Run verifiers
    Write-Log "Running verifiers..."
    $allPassed = $true
    
    foreach ($v in $verifiers) {
        Write-Log "  Verifier: $($v.name)"
        
        $cmd = $v.command
        $timeout = $v.timeout_seconds
        if (-not $timeout) { $timeout = 300 }
        
        try {
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = "powershell.exe"
            $psi.Arguments = "-NoProfile -Command `"$cmd`""
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true
            $psi.UseShellExecute = $false
            $psi.WorkingDirectory = (Get-Location)
            
            $process = [System.Diagnostics.Process]::Start($psi)
            $completed = $process.WaitForExit($timeout * 1000)
            
            if (-not $completed) {
                $process.Kill()
                Write-Log "    TIMEOUT after ${timeout}s" "ERROR"
                $allPassed = $false
                continue
            }
            
            $exitCode = $process.ExitCode
            $stdout = $process.StandardOutput.ReadToEnd()
            $process.Dispose()
            
            $expectedExit = $v.expect.exit_code
            if (-not $expectedExit) { $expectedExit = 0 }
            
            if ($exitCode -eq $expectedExit) {
                Write-Log "    PASSED" "SUCCESS"
            } else {
                Write-Log "    FAILED (exit $exitCode)" "ERROR"
                $allPassed = $false
            }
        } catch {
            Write-Log "    ERROR: $_" "ERROR"
            $allPassed = $false
        }
    }
    
    if ($allPassed) {
        Write-Log "ALL VERIFIERS PASSED" "SUCCESS"
        Write-Log "DoD satisfied after $iteration iteration(s)"
        
        # Update bead
        & bd update $BeadId --status=completed 2>&1 | Out-Null
        
        exit 0
    }
    
    Write-Log "Some verifiers failed, retrying..." "WARN"
    Start-Sleep -Seconds $DEFAULT_BACKOFF
}

Write-Log "Max iterations reached without satisfying DoD" "ERROR"
exit 1
