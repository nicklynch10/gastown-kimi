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

.PARAMETER DryRun
    Show what would be done without making changes.

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

# Error action preference - Continue so we can handle errors gracefully
$ErrorActionPreference = "Continue"

#region Constants

$RALPH_VERSION = "1.1.0"
$DEFAULT_BACKOFF_SECONDS = 30
$LogDir = Join-Path ".ralph" "logs"
$LogFile = Join-Path $LogDir "executor-$(Get-Date -Format 'yyyyMMdd').log"

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
    
    # Write to log file with retry for file locking
    $logEntry = "[$timestamp] [$Level] $Message"
    $maxRetries = 3
    $retryDelay = 100  # milliseconds
    
    for ($i = 0; $i -lt $maxRetries; $i++) {
        try {
            # Ensure log directory exists
            if (-not (Test-Path $LogDir)) {
                New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
            }
            # Use StreamWriter with exclusive access for atomic writes
            $writer = [System.IO.StreamWriter]::new($LogFile, $true)
            $writer.WriteLine($logEntry)
            $writer.Close()
            $writer.Dispose()
            break
        }
        catch {
            if ($i -eq $maxRetries - 1) {
                # Last retry failed, write to console only
                Write-Host "[WARN] Could not write to log file: $_" -ForegroundColor Yellow
            }
            else {
                Start-Sleep -Milliseconds $retryDelay
            }
        }
    }
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
    
    # Try to load from .ralph/beads/ first (local file mode)
    $localBeadPath = Join-Path (Join-Path (Join-Path "." ".ralph") "beads") "$Id.json"
    if (Test-Path $localBeadPath) {
        try {
            $content = Get-Content $localBeadPath -Raw -Encoding UTF8
            return $content | ConvertFrom-Json
        }
        catch {
            Write-RalphLog "Failed to parse local bead file: $_" "ERROR"
            throw "Failed to load bead ${Id}: $_"
        }
    }
    
    # Fall back to bd CLI
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
    
    # Update local file if it exists
    $localBeadPath = Join-Path (Join-Path (Join-Path "." ".ralph") "beads") "$Id.json"
    if (Test-Path $localBeadPath) {
        try {
            $content = Get-Content $localBeadPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if (-not $content.ralph_meta) {
                $content | Add-Member -NotePropertyName "ralph_meta" -NotePropertyValue @{} -Force
            }
            foreach ($key in $Meta.Keys) {
                $content.ralph_meta | Add-Member -NotePropertyName $key -NotePropertyValue $Meta[$key] -Force
            }
            $content | ConvertTo-Json -Depth 10 | Out-File -FilePath $localBeadPath -Encoding utf8
        }
        catch {
            Write-RalphLog "Warning: Failed to update ralph_meta in file: $_" "WARN"
        }
    }
    
    # Note: bd CLI update with notes is not supported, local file update is sufficient
}

function Update-BeadStatus {
    param(
        [string]$Id,
        [string]$Status,
        [string]$ErrorMessage = ""
    )
    
    $localBeadPath = Join-Path (Join-Path (Join-Path "." ".ralph") "beads") "$Id.json"
    if (Test-Path $localBeadPath) {
        try {
            $content = Get-Content $localBeadPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $content | Add-Member -NotePropertyName "status" -NotePropertyValue $Status -Force
            if ($ErrorMessage) {
                $content | Add-Member -NotePropertyName "last_error" -NotePropertyValue $ErrorMessage -Force
            }
            $content | Add-Member -NotePropertyName "last_updated" -NotePropertyValue (Get-Date -Format "o") -Force
            $content | ConvertTo-Json -Depth 10 | Out-File -FilePath $localBeadPath -Encoding utf8
            Write-RalphLog "Updated bead status to: $Status"
        }
        catch {
            Write-RalphLog "Warning: Failed to update bead status: $_" "WARN"
        }
    }
}

#endregion

#region Verifier Execution

function Test-Verifier {
    param([object]$Verifier)
    
    $name = $Verifier.name
    $command = $Verifier.command
    $expect = $Verifier.expect
    $timeout = if ($Verifier.timeout_seconds) { $Verifier.timeout_seconds } else { 300 }
    
    Write-RalphLog "Running verifier: $name"
    Write-RalphLog "  Command: $command"
    
    try {
        # Create a temporary script file to execute the command
        # This is more reliable than passing complex commands via -Command parameter
        $scriptFile = [System.IO.Path]::GetTempFileName()
        $scriptFile = [System.IO.Path]::ChangeExtension($scriptFile, ".ps1")
        
        # Write the command to the script file
        $scriptContent = @"
`$ErrorActionPreference = "Continue"
try {
    $command
    exit `$LASTEXITCODE
} catch {
    Write-Error "`$_"
    exit 1
}
"@
        $scriptContent | Out-File -FilePath $scriptFile -Encoding utf8
        
        # Start process with timeout
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptFile`""
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.UseShellExecute = $false
        $psi.WorkingDirectory = (Get-Location)
        
        $process = [System.Diagnostics.Process]::Start($psi)
        
        # Wait with timeout
        $completed = $process.WaitForExit($timeout * 1000)
        
        if (-not $completed) {
            try { $process.Kill() } catch {}
            Remove-Item $scriptFile -ErrorAction SilentlyContinue
            return @{
                Passed = $false
                Reason = "Verifier timed out after ${timeout}s"
                Stdout = ""
                Stderr = "Timeout: Process did not complete within ${timeout} seconds"
            }
        }
        
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        $exitCode = $process.ExitCode
        
        $process.Dispose()
        Remove-Item $scriptFile -ErrorAction SilentlyContinue
        
        Write-RalphLog "  Exit code: $exitCode"
        if ($stdout) { Write-RalphLog "  Stdout: $($stdout.Substring(0, [Math]::Min(200, $stdout.Length)))..." }
        if ($stderr) { Write-RalphLog "  Stderr: $($stderr.Substring(0, [Math]::Min(200, $stderr.Length)))..." }
        
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
            Stdout = $result.Stdout
            Stderr = $result.Stderr
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
        [object]$BeadData,
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
        Write-RalphLog "  [DRY RUN] Would invoke: kimi $KimiArgs with prompt file"
        Remove-Item $promptFile -ErrorAction SilentlyContinue
        return $true
    }
    
    try {
        # Check if kimi is available
        $kimiPath = Get-Command kimi -ErrorAction SilentlyContinue
        if (-not $kimiPath) {
            Write-RalphLog "Kimi CLI not found. Skipping Kimi invocation." "WARN"
            Remove-Item $promptFile -ErrorAction SilentlyContinue
            return $true  # Return true to allow verifiers to run
        }
        
        # Invoke Kimi with prompt file via stdin
        # Kimi CLI supports: kimi [OPTIONS] COMMAND [ARGS]...
        # We use 'kimi --yolo' and pipe the prompt via stdin
        $promptContent = Get-Content $promptFile -Raw
        
        Write-RalphLog "  Starting Kimi process..."
        
        # Create process to invoke Kimi with piped input
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "kimi"
        $psi.Arguments = $KimiArgs
        $psi.RedirectStandardInput = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.UseShellExecute = $false
        $psi.WorkingDirectory = (Get-Location)
        
        $process = [System.Diagnostics.Process]::Start($psi)
        
        # Write prompt to stdin
        $process.StandardInput.WriteLine($promptContent)
        $process.StandardInput.Close()
        
        # Wait for Kimi to complete (with 10-minute timeout)
        $completed = $process.WaitForExit(600000)
        
        if (-not $completed) {
            try { $process.Kill() } catch {}
            Write-RalphLog "Kimi process timed out after 10 minutes" "ERROR"
            Remove-Item $promptFile -ErrorAction SilentlyContinue
            return $false
        }
        
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        $exitCode = $process.ExitCode
        
        $process.Dispose()
        
        Write-RalphLog "  Kimi exit code: $exitCode"
        if ($stderr) {
            Write-RalphLog "  Kimi stderr: $stderr" "WARN"
        }
        
        Remove-Item $promptFile -ErrorAction SilentlyContinue
        
        # Kimi returns 0 on success, non-zero on failure
        return $exitCode -eq 0
    }
    catch {
        Write-RalphLog "Kimi invocation failed: $_" "ERROR"
        Remove-Item $promptFile -ErrorAction SilentlyContinue
        return $false
    }
}

#endregion

#region Main Ralph Loop

function Start-RalphLoop {
    param(
        [string]$Id,
        [object]$Data
    )
    
    $verifiers = $Data.dod.verifiers
    $maxIter = if ($Data.constraints.max_iterations) { $Data.constraints.max_iterations } else { $MaxIterations }
    $backoff = if ($Data.ralph_meta.retry_backoff_seconds) { $Data.ralph_meta.retry_backoff_seconds } else { $DEFAULT_BACKOFF_SECONDS }
    
    Write-RalphLog "Starting Ralph loop for bead $Id"
    Write-RalphLog "  Verifiers: $($verifiers.Count)"
    Write-RalphLog "  Max iterations: $maxIter"
    Write-RalphLog "  Backoff: ${backoff}s"
    
    # Mark bead as in_progress
    Update-BeadStatus -Id $Id -Status "in_progress"
    
    $lastResults = $null
    $iteration = 0
    
    while ($iteration -lt $maxIter) {
        $iteration++
        Write-RalphLog "`n=== Iteration $iteration / $maxIter ===" "WARN"
        
        # Update metadata
        Update-RalphMeta -Id $Id -Meta @{
            attempt_count = $iteration
            last_attempt = (Get-Date -Format "o")
            status = "in_progress"
        }
        
        # Step 1: Invoke Kimi with context
        $failureResults = if ($lastResults) { $lastResults.Results } else { $null }
        $success = Invoke-KimiImplementation `
            -BeadId $Id `
            -BeadData $Data `
            -LastFailureResults $failureResults `
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
        $failureSummary = ""
        if (-not $verifyResult.AllPassed) { 
            $failureSummary = ($verifyResult.Results | Where-Object { -not $_.Passed } | ForEach-Object { $_.Reason }) -join "; "
        }
        Update-RalphMeta -Id $Id -Meta @{
            verifier_results = $verifyResult.Results
            last_failure_summary = $failureSummary
        }
        
        # Step 3: Check if all passed
        if ($verifyResult.AllPassed) {
            Write-RalphLog "ALL VERIFIERS PASSED" "SUCCESS"
            Write-RalphLog "DoD satisfied after $iteration iteration(s)"
            Update-BeadStatus -Id $Id -Status "completed"
            Update-RalphMeta -Id $Id -Meta @{ status = "completed" }
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
    
    # Max iterations reached - mark as failed
    Write-RalphLog "`n=== MAX ITERATIONS REACHED ===" "ERROR"
    Write-RalphLog "Failed to satisfy DoD after $maxIter iterations" "ERROR"
    
    Update-BeadStatus -Id $Id -Status "failed" -ErrorMessage "Max iterations reached"
    Update-RalphMeta -Id $Id -Meta @{ 
        status = "failed"
        failure_reason = "Max iterations reached"
    }
    
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
    
    # Validate Kimi is available (optional - system works without it in dry-run mode)
    $kimiPath = Get-Command kimi -ErrorAction SilentlyContinue
    if (-not $kimiPath) {
        Write-RalphLog "Kimi CLI not found in PATH. Will run in verification-only mode." "WARN"
    }
    else {
        Write-RalphLog "Kimi found: $($kimiPath.Source)"
    }
    
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
        $EvidenceDir = Join-Path (Join-Path (Join-Path "." ".ralph") "evidence") $BeadId
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
