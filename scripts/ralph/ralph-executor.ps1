#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Ralph executor for Gastown - Windows-native retry loop with DoD enforcement.

.DESCRIPTION
    Implements a bead using Ralph retry semantics:
    1. Parse DoD verifiers from bead
    2. Run verifiers (TDD - expecting failures first)
    3. Invoke Kimi with context
    4. Re-run verifiers until all pass or max iterations

.PARAMETER BeadId
    The bead ID to implement.

.PARAMETER MaxIterations
    Maximum number of Ralph retry iterations (default: 10).

.PARAMETER KimiArgs
    Additional arguments to pass to Kimi CLI.

.PARAMETER EvidenceDir
    Directory to store evidence (default: .ralph/evidence/<bead_id>).

.EXAMPLE
    .\ralph-executor.ps1 -BeadId "gt-abc12"

.EXAMPLE
    .\ralph-executor.ps1 -BeadId "gt-abc12" -MaxIterations 5 -Verbose
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$BeadId,

    [Parameter()]
    [int]$MaxIterations = 10,

    [Parameter()]
    [string]$KimiArgs = "--yolo",

    [Parameter()]
    [string]$EvidenceDir = "",

    [Parameter()]
    [switch]$DryRun
)

# Error action preference
$ErrorActionPreference = "Stop"

#region Constants

$RALPH_VERSION = "1.0.0"
$DEFAULT_BACKOFF_SECONDS = 30

#endregion

#region Logging Functions

function Write-RalphLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN"  { "Yellow" }
        "SUCCESS" { "Green" }
        default { "White" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Write-RalphBanner {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "RALPH EXECUTOR v$RALPH_VERSION" -ForegroundColor Cyan
    Write-Host "Windows-Native DoD Enforcement" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
}

#endregion

#region Bead Operations

function Get-BeadData {
    param([string]$Id)
    
    Write-RalphLog "Loading bead $Id..."
    
    try {
        $output = & bd show $Id --json 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "bd show failed: $output"
        }
        return $output | ConvertFrom-Json
    }
    catch {
        throw "Failed to load bead ${Id}: $_"
    }
}

function Update-RalphMeta {
    param(
        [string]$Id,
        [hashtable]$Meta
    )
    
    $json = $Meta | ConvertTo-Json -Compress -Depth 10
    $escaped = $json -replace '"', '\"'
    
    try {
        & bd update $Id --notes "ralph_meta: $json" | Out-Null
    }
    catch {
        Write-RalphLog "Warning: Failed to update ralph_meta: $_" "WARN"
    }
}

#endregion

#region Verifier Execution

function Test-Verifier {
    param([hashtable]$Verifier)
    
    $name = $Verifier.name
    $command = $Verifier.command
    $expect = $Verifier.expect
    $timeout = if ($Verifier.timeout_seconds) { $Verifier.timeout_seconds } else { 300 }
    
    Write-RalphLog "Running verifier: $name"
    Write-RalphLog "  Command: $command"
    
    try {
        # Create temporary files for output capture
        $stdoutFile = [System.IO.Path]::GetTempFileName()
        $stderrFile = [System.IO.Path]::GetTempFileName()
        
        # Start process with timeout
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"$command`""
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.UseShellExecute = $false
        $psi.WorkingDirectory = (Get-Location)
        
        $process = [System.Diagnostics.Process]::Start($psi)
        
        # Wait with timeout
        $completed = $process.WaitForExit($timeout * 1000)
        
        if (-not $completed) {
            $process.Kill()
            throw "Verifier timed out after ${timeout}s"
        }
        
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        $exitCode = $process.ExitCode
        
        $process.Dispose()
        
        # Check exit code
        $expectedExit = if ($expect.exit_code) { $expect.exit_code } else { 0 }
        if ($exitCode -ne $expectedExit) {
            return @{
                Passed = $false
                Reason = "Exit code $exitCode (expected $expectedExit)"
                Stdout = $stdout
                Stderr = $stderr
            }
        }
        
        # Check stdout contains
        if ($expect.stdout_contains) {
            if ($stdout -notlike "*$($expect.stdout_contains)*") {
                return @{
                    Passed = $false
                    Reason = "stdout does not contain: $($expect.stdout_contains)"
                    Stdout = $stdout
                    Stderr = $stderr
                }
            }
        }
        
        # Check stderr contains
        if ($expect.stderr_contains) {
            if ($stderr -notlike "*$($expect.stderr_contains)*") {
                return @{
                    Passed = $false
                    Reason = "stderr does not contain: $($expect.stderr_contains)"
                    Stdout = $stdout
                    Stderr = $stderr
                }
            }
        }
        
        return @{
            Passed = $true
            Stdout = $stdout
            Stderr = $stderr
        }
    }
    catch {
        return @{
            Passed = $false
            Reason = "Exception: $_"
            Stdout = ""
            Stderr = $_.Exception.Message
        }
    }
}

function Test-AllVerifiers {
    param([array]$Verifiers)
    
    $results = @()
    $allPassed = $true
    
    foreach ($v in $Verifiers) {
        $result = Test-Verifier -Verifier $v
        $results += @{
            Name = $v.name
            Passed = $result.Passed
            Reason = $result.Reason
            Timestamp = (Get-Date -Format "o")
        }
        
        if ($result.Passed) {
            Write-RalphLog "  [OK] PASSED: $($v.name)" "SUCCESS"
        }
        else {
            Write-RalphLog "  [FAIL] FAILED: $($v.name) - $($result.Reason)" "ERROR"
            $allPassed = $false
            
            # Stop on failure unless continue is specified
            if ($v.on_failure -ne "continue") {
                break
            }
        }
    }
    
    return @{
        AllPassed = $allPassed
        Results = $results
    }
}

#endregion

#region Kimi Integration

function Invoke-KimiImplementation {
    param(
        [string]$BeadId,
        [hashtable]$BeadData,
        [array]$LastFailureResults,
        [int]$Iteration
    )
    
    Write-RalphLog "Invoking Kimi for iteration $Iteration..."
    
    # Build Kimi prompt
    $intent = $BeadData.intent
    $constraints = $BeadData.constraints | ConvertTo-Json -Depth 5
    
    $verifierList = ($BeadData.dod.verifiers | ForEach-Object { "- $($_.name): $($_.command)" }) -join "`n"
    
    $failureContext = ""
    if ($LastFailureResults) {
        $failures = ($LastFailureResults | Where-Object { -not $_.Passed } | ForEach-Object { 
            "- $($_.Name): $($_.Reason)" 
        }) -join "`n"
        $failureContext = "`n`n## Previous Attempt Failures`nThe following verifiers failed in the last attempt. Fix these issues:`n$failures`n"
    }
    
    $promptLines = @(
        "# Ralph Implementation Task"
        ""
        "## Intent"
        $intent
        ""
        "## Definition of Done (DoD)"
        "You MUST ensure ALL of the following verifiers pass:"
        $verifierList
        ""
        $failureContext
        ""
        "## Constraints"
        '```json'
        $constraints
        '```'
        ""
        "## Instructions"
        "1. First, run the verifiers to understand what needs to be implemented (TDD)"
        "2. Implement the solution to satisfy the intent"
        "3. Run verifiers again - they MUST all pass"
        "4. If any verifier fails, fix the issue and retry"
        "5. Do NOT mark work as complete until ALL verifiers pass"
        ""
        "## Output"
        "- Implement the solution"
        "- Ensure all DoD verifiers pass"
        "- Commit your changes with a descriptive message"
    )
    $prompt = $promptLines -join "`n"
    
    # Create temporary prompt file
    $promptFile = [System.IO.Path]::GetTempFileName()
    $prompt | Out-File -FilePath $promptFile -Encoding utf8
    
    Write-RalphLog "  Prompt file: $promptFile"
    
    if ($DryRun) {
        Write-RalphLog "  [DRY RUN] Would invoke: kimi $KimiArgs --file $promptFile"
        return $true
    }
    
    try {
        # Invoke Kimi
        $kimiProcess = Start-Process -FilePath "kimi" `
            -ArgumentList "$KimiArgs --file `"$promptFile`"" `
            -NoNewWindow -Wait -PassThru
        
        return $kimiProcess.ExitCode -eq 0
    }
    catch {
        Write-RalphLog "Kimi invocation failed: $_" "ERROR"
        return $false
    }
    finally {
        Remove-Item $promptFile -ErrorAction SilentlyContinue
    }
}

#endregion

#region Main Ralph Loop

function Start-RalphLoop {
    param(
        [string]$Id,
        [hashtable]$Data
    )
    
    $verifiers = $Data.dod.verifiers
    $maxIter = if ($Data.constraints.max_iterations) { $Data.constraints.max_iterations } else { $MaxIterations }
    $backoff = if ($Data.ralph_meta.retry_backoff_seconds) { $Data.ralph_meta.retry_backoff_seconds } else { $DEFAULT_BACKOFF_SECONDS }
    
    Write-RalphLog "Starting Ralph loop for bead $Id"
    Write-RalphLog "  Verifiers: $($verifiers.Count)"
    Write-RalphLog "  Max iterations: $maxIter"
    Write-RalphLog "  Backoff: ${backoff}s"
    
    $lastResults = $null
    $iteration = 0
    
    while ($iteration -lt $maxIter) {
        $iteration++
        Write-RalphLog "`n=== Iteration $iteration / $maxIter ===" "WARN"
        
        # Update metadata
        Update-RalphMeta -Id $Id -Meta @{
            attempt_count = $iteration
            last_attempt = (Get-Date -Format "o")
        }
        
        # Step 1: Invoke Kimi with context
        $success = Invoke-KimiImplementation `
            -BeadId $Id `
            -BeadData $Data `
            -LastFailureResults (if ($lastResults) { $lastResults.Results } else { $null }) `
            -Iteration $iteration
        
        if (-not $success) {
            Write-RalphLog "Kimi invocation failed, will retry..." "WARN"
            Start-Sleep -Seconds $backoff
            continue
        }
        
        # Step 2: Run verifiers
        Write-RalphLog "Running verifiers..."
        $verifyResult = Test-AllVerifiers -Verifiers $verifiers
        $lastResults = $verifyResult
        
        # Store results in bead
        Update-RalphMeta -Id $Id -Meta @{
            verifier_results = $verifyResult.Results
            last_failure_summary = if ($verifyResult.AllPassed) { "" } else { 
                ($verifyResult.Results | Where-Object { -not $_.Passed } | ForEach-Object { $_.Reason }) -join "; "
            }
        }
        
        # Step 3: Check if all passed
        if ($verifyResult.AllPassed) {
            Write-RalphLog "ALL VERIFIERS PASSED" "SUCCESS"
            Write-RalphLog "DoD satisfied after $iteration iteration(s)"
            return @{
                Success = $true
                Iterations = $iteration
                Results = $verifyResult.Results
            }
        }
        
        # Step 4: Retry with backoff
        Write-RalphLog "Some verifiers failed, retrying after ${backoff}s..." "WARN"
        Start-Sleep -Seconds $backoff
        
        # Exponential backoff (cap at 5 minutes)
        $backoff = [Math]::Min($backoff * 2, 300)
    }
    
    # Max iterations reached
    Write-RalphLog "`n=== MAX ITERATIONS REACHED ===" "ERROR"
    Write-RalphLog "Failed to satisfy DoD after $maxIter iterations" "ERROR"
    
    return @{
        Success = $false
        Iterations = $iteration
        Results = $lastResults.Results
    }
}

#endregion

#region Main

function Show-PrereqError {
    Write-RalphLog "Missing required tools. Please install:" "ERROR"
    Write-RalphLog "  - Kimi CLI: pip install kimi-cli" "WARN"
    Write-RalphLog "  - Beads CLI: go install github.com/nicklynch10/beads-cli/cmd/bd@latest" "WARN"
    Write-RalphLog "See RALPH_INTEGRATION.md for details" "WARN"
}

function Main {
    Write-RalphBanner
    
    # Validate Kimi is available
    $kimiPath = Get-Command kimi -ErrorAction SilentlyContinue
    if (-not $kimiPath) {
        Write-RalphLog "Kimi CLI not found in PATH. Please install Kimi Code CLI." "ERROR"
        Show-PrereqError
        exit 1
    }
    Write-RalphLog "Kimi found: $($kimiPath.Source)"
    
    # Validate bd is available
    $bdPath = Get-Command bd -ErrorAction SilentlyContinue
    if (-not $bdPath) {
        Write-RalphLog "Beads CLI (bd) not found in PATH. Please install beads." "ERROR"
        Show-PrereqError
        exit 1
    }
    Write-RalphLog "Beads found: $($bdPath.Source)"
    
    # Load bead
    try {
        $beadData = Get-BeadData -Id $BeadId
    }
    catch {
        Write-RalphLog $_ "ERROR"
        exit 1
    }
    
    # Validate bead has required fields
    if (-not $beadData.intent) {
        Write-RalphLog "Bead missing required field: intent" "ERROR"
        exit 1
    }
    if (-not $beadData.dod -or -not $beadData.dod.verifiers) {
        Write-RalphLog "Bead missing required field: dod.verifiers" "ERROR"
        exit 1
    }
    
    Write-RalphLog "Bead loaded: $($beadData.title)"
    Write-RalphLog "Intent: $($beadData.intent)"
    
    # Setup evidence directory
    if (-not $EvidenceDir) {
        $EvidenceDir = Join-Path ".ralph" "evidence" $BeadId
    }
    New-Item -ItemType Directory -Force -Path $EvidenceDir | Out-Null
    Write-RalphLog "Evidence directory: $EvidenceDir"
    
    # Run Ralph loop
    $result = Start-RalphLoop -Id $BeadId -Data $beadData
    
    # Output result
    Write-Host "`n"
    if ($result.Success) {
        Write-RalphLog "RALPH EXECUTION SUCCESSFUL" "SUCCESS"
        Write-RalphLog "Iterations: $($result.Iterations)"
        Write-RalphLog "All DoD verifiers satisfied"
        exit 0
    }
    else {
        Write-RalphLog "RALPH EXECUTION FAILED" "ERROR"
        Write-RalphLog "Iterations: $($result.Iterations)"
        Write-RalphLog "Some DoD verifiers still failing"
        exit 1
    }
}

# Run main
Main

#endregion
