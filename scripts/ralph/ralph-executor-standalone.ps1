#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Ralph Standalone Executor - Works with or without GT/BD CLI

.DESCRIPTION
    This executor can run Ralph beads in two modes:
    1. Full Mode: Uses gt/bd CLIs when available (recommended)
    2. Standalone Mode: Uses local JSON files when gt/bd are not available

    REQUIRED DEPENDENCIES (must be installed before running):
    - PowerShell 5.1+ (Windows built-in)
    - Git for Windows
    - Gastown CLI (gt): go install github.com/nicklynch10/gastown-cli/cmd/gt@latest
    - Beads CLI (bd): go install github.com/nicklynch10/beads-cli/cmd/bd@latest
    - Kimi Code CLI: pip install kimi-cli

.PARAMETER BeadId
    The bead ID to execute (for full mode)

.PARAMETER BeadFile
    Path to a bead JSON file (for standalone mode)

.PARAMETER MaxIterations
    Maximum number of retry iterations

.PARAMETER EvidenceDir
    Directory to store evidence

.PARAMETER Standalone
    Force standalone mode (no gt/bd dependency)

.PARAMETER ProjectRoot
    Project root directory (for standalone mode)

.EXAMPLE
    # Full mode (requires gt/bd)
    .\ralph-executor-standalone.ps1 -BeadId gt-abc-123

.EXAMPLE
    # Standalone mode (no gt/bd required)
    .\ralph-executor-standalone.ps1 -BeadFile .\my-bead.json -Standalone
#>

[CmdletBinding()]
param(
    [Parameter(ParameterSetName = "Full")]
    [string]$BeadId,
    
    [Parameter(ParameterSetName = "Standalone")]
    [string]$BeadFile,
    
    [Parameter()]
    [int]$MaxIterations = 10,
    
    [Parameter()]
    [string]$EvidenceDir = "",
    
    [Parameter(ParameterSetName = "Standalone")]
    [switch]$Standalone,
    
    [Parameter(ParameterSetName = "Standalone")]
    [string]$ProjectRoot = "."
)

$ErrorActionPreference = "Stop"
$RALPH_VERSION = "1.1.0"

#region Logging Setup

$script:LogFile = $null

function Initialize-Logging {
    param([string]$BeadId)
    
    $logDir = Join-Path $ProjectRoot ".ralph/logs"
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    }
    
    $date = Get-Date -Format "yyyy-MM-dd"
    $script:LogFile = Join-Path $logDir "ralph-$date.log"
    
    Write-Log "Ralph Executor v$RALPH_VERSION started" -Level INFO
    Write-Log "Bead: $BeadId" -Level INFO
    Write-Log "Mode: $(if($Standalone){'Standalone'}else{'Full'})" -Level INFO
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("DEBUG", "INFO", "WARN", "ERROR", "FATAL")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Console output
    $colorMap = @{
        "DEBUG" = "Gray"
        "INFO" = "White"
        "WARN" = "Yellow"
        "ERROR" = "Red"
        "FATAL" = "Magenta"
    }
    Write-Host $logEntry -ForegroundColor $colorMap[$Level]
    
    # File output
    if ($script:LogFile) {
        try {
            Add-Content -Path $script:LogFile -Value $logEntry -ErrorAction SilentlyContinue
        } catch {
            # Ignore file write errors
        }
    }
}

#endregion

#region Prerequisite Check

function Test-Prerequisites {
    Write-Log "Checking prerequisites..." -Level INFO
    
    $required = @()
    $missing = @()
    
    # Always required
    $required += @{ Name = "git"; Display = "Git"; Required = $true }
    $required += @{ Name = "kimi"; Display = "Kimi CLI"; Required = $true }
    
    # Only required in full mode
    if (-not $Standalone) {
        $required += @{ Name = "gt"; Display = "Gastown CLI (gt)"; Required = $true }
        $required += @{ Name = "bd"; Display = "Beads CLI (bd)"; Required = $true }
    }
    
    foreach ($tool in $required) {
        $found = Get-Command $tool.Name -ErrorAction SilentlyContinue
        if ($found) {
            Write-Log "  [OK] $($tool.Display)" -Level DEBUG
        } else {
            Write-Log "  [MISSING] $($tool.Display)" -Level ERROR
            if ($tool.Required) {
                $missing += $tool.Display
            }
        }
    }
    
    if ($missing.Count -gt 0) {
        Write-Log "" -Level ERROR
        Write-Log "MISSING REQUIRED DEPENDENCIES:" -Level ERROR
        foreach ($m in $missing) {
            Write-Log "  - $m" -Level ERROR
        }
        Write-Log "" -Level ERROR
        Write-Log "Run the following to check prerequisites:" -Level INFO
        Write-Log "  .\ralph-prereq-check.ps1 -Install" -Level INFO
        return $false
    }
    
    Write-Log "All prerequisites met" -Level INFO
    return $true
}

#endregion

#region Path Handling

function Resolve-ProjectPath {
    param([string]$Path)
    
    # Handle absolute paths
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }
    
    # Handle relative to project root
    $fullPath = Join-Path $ProjectRoot $Path
    return Resolve-Path $fullPath -ErrorAction SilentlyContinue
}

function Ensure-Directory {
    param([string]$Path)
    
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
        Write-Log "Created directory: $Path" -Level DEBUG
    }
}

#endregion

#region Transaction Safety

$script:TransactionStack = @()

function Start-Transaction {
    param([string]$Description)
    
    $tx = @{
        Id = [Guid]::NewGuid().ToString()
        Description = $Description
        StartTime = Get-Date
        Operations = @()
    }
    
    $script:TransactionStack += $tx
    Write-Log "Started transaction: $Description" -Level DEBUG
    return $tx.Id
}

function Add-TransactionOperation {
    param(
        [string]$Type,
        [string]$Source,
        [string]$Target,
        [hashtable]$Metadata = @{}
    )
    
    $tx = $script:TransactionStack[-1]
    if (-not $tx) { return }
    
    $op = @{
        Type = $Type
        Source = $Source
        Target = $Target
        Metadata = $Metadata
        Timestamp = Get-Date
    }
    
    $tx.Operations += $op
}

function Complete-Transaction {
    param([string]$TxId)
    
    $txIndex = -1
    for ($i = 0; $i -lt $script:TransactionStack.Count; $i++) {
        if ($script:TransactionStack[$i].Id -eq $TxId) {
            $txIndex = $i
            break
        }
    }
    
    if ($txIndex -ge 0) {
        $tx = $script:TransactionStack[$txIndex]
        $duration = (Get-Date) - $tx.StartTime
        Write-Log "Completed transaction '$($tx.Description)' in $($duration.TotalSeconds)ms" -Level DEBUG
        $script:TransactionStack = $script:TransactionStack | Where-Object { $_.Id -ne $TxId }
    }
}

function Undo-Transaction {
    param([string]$TxId)
    
    $tx = $script:TransactionStack | Where-Object { $_.Id -eq $TxId }
    if (-not $tx) { return }
    
    Write-Log "Rolling back transaction: $($tx.Description)" -Level WARN
    
    # Rollback operations in reverse order
    for ($i = $tx.Operations.Count - 1; $i -ge 0; $i--) {
        $op = $tx.Operations[$i]
        
        switch ($op.Type) {
            "MoveFile" {
                if (Test-Path $op.Target) {
                    Write-Log "  Restoring: $($op.Target) -> $($op.Source)" -Level DEBUG
                    Move-Item $op.Target $op.Source -Force -ErrorAction SilentlyContinue
                }
            }
            "WriteFile" {
                if (Test-Path $op.Target) {
                    Write-Log "  Removing: $($op.Target)" -Level DEBUG
                    Remove-Item $op.Target -Force -ErrorAction SilentlyContinue
                }
            }
            "ModifyFile" {
                if ($op.Metadata.ContainsKey("BackupPath") -and (Test-Path $op.Metadata.BackupPath)) {
                    Write-Log "  Restoring from backup: $($op.Metadata.BackupPath)" -Level DEBUG
                    Copy-Item $op.Metadata.BackupPath $op.Target -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
    
    $script:TransactionStack = $script:TransactionStack | Where-Object { $_.Id -ne $TxId }
}

function Move-BeadWithTransaction {
    param(
        [string]$Source,
        [string]$Destination
    )
    
    $txId = Start-Transaction -Description "Move bead from $Source to $Destination"
    
    try {
        # Create backup if destination exists
        if (Test-Path $Destination) {
            $backupPath = "$Destination.backup-$(Get-Date -Format 'yyyyMMddHHmmss')"
            Copy-Item $Destination $backupPath -Force
            Add-TransactionOperation -Type "ModifyFile" -Source $backupPath -Target $Destination -Metadata @{ BackupPath = $backupPath }
        }
        
        # Record the move operation
        Add-TransactionOperation -Type "MoveFile" -Source $Source -Target $Destination
        
        # Perform the move
        Move-Item $Source $Destination -Force
        
        Complete-Transaction -TxId $txId
        return $true
    } catch {
        Write-Log "Move failed: $_" -Level ERROR
        Undo-Transaction -TxId $txId
        throw
    }
}

#endregion

#region Bead Operations

function Get-BeadData {
    if ($Standalone) {
        return Get-BeadDataStandalone
    } else {
        return Get-BeadDataFull
    }
}

function Get-BeadDataStandalone {
    if (-not (Test-Path $BeadFile)) {
        throw "Bead file not found: $BeadFile"
    }
    
    try {
        $content = Get-Content $BeadFile -Raw -Encoding UTF8
        $bead = $content | ConvertFrom-Json
        
        # Validate required fields
        if (-not $bead.intent) {
            throw "Bead missing required field: intent"
        }
        
        if (-not $bead.dod -or -not $bead.dod.verifiers) {
            throw "Bead missing required field: dod.verifiers"
        }
        
        return $bead
    } catch {
        throw "Failed to parse bead file: $_"
    }
}

function Get-BeadDataFull {
    if (-not $BeadId) {
        throw "BeadId required in full mode"
    }
    
    try {
        $output = & bd show $BeadId --json 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "bd show failed: $output"
        }
        return $output | ConvertFrom-Json
    } catch {
        throw "Failed to load bead ${BeadId}: $_"
    }
}

function Update-BeadStatus {
    param(
        [string]$Status,
        [hashtable]$Metadata = @{}
    )
    
    if ($Standalone) {
        Update-BeadStatusStandalone -Status $Status -Metadata $Metadata
    } else {
        Update-BeadStatusFull -Status $Status -Metadata $Metadata
    }
}

function Update-BeadStatusStandalone {
    param(
        [string]$Status,
        [hashtable]$Metadata
    )
    
    try {
        $bead = Get-Content $BeadFile -Raw | ConvertFrom-Json
        $bead | Add-Member -NotePropertyName "status" -NotePropertyValue $Status -Force
        
        if ($Metadata.Count -gt 0) {
            if (-not $bead.ralph_meta) {
                $bead | Add-Member -NotePropertyName "ralph_meta" -NotePropertyValue @{} -Force
            }
            foreach ($key in $Metadata.Keys) {
                $bead.ralph_meta | Add-Member -NotePropertyName $key -NotePropertyValue $Metadata[$key] -Force
            }
        }
        
        # Write with backup
        $backupPath = "$BeadFile.backup"
        if (Test-Path $BeadFile) {
            Copy-Item $BeadFile $backupPath -Force
        }
        
        $bead | ConvertTo-Json -Depth 10 | Out-File $BeadFile -Encoding UTF8
        
        # Remove backup on success
        if (Test-Path $backupPath) {
            Remove-Item $backupPath -Force
        }
    } catch {
        # Restore from backup on failure
        if (Test-Path $backupPath) {
            Copy-Item $backupPath $BeadFile -Force
        }
        throw "Failed to update bead status: $_"
    }
}

function Update-BeadStatusFull {
    param(
        [string]$Status,
        [hashtable]$Metadata
    )
    
    try {
        & bd update $BeadId --status=$Status 2>&1 | Out-Null
        
        if ($Metadata.Count -gt 0) {
            $json = $Metadata | ConvertTo-Json -Compress
            $escaped = $json -replace '"', '\"'
            & bd update $BeadId --notes "ralph_meta: $escaped" | Out-Null
        }
    } catch {
        Write-Log "Failed to update bead status: $_" -Level WARN
    }
}

#endregion

#region Verifier Execution

function Invoke-Verifier {
    param([PSCustomObject]$Verifier)
    
    $name = $Verifier.name
    $command = $Verifier.command
    $expect = $Verifier.expect
    $timeout = if ($Verifier.timeout_seconds) { $Verifier.timeout_seconds } else { 300 }
    
    Write-Log "Running verifier: $name" -Level INFO
    Write-Log "  Command: $command" -Level DEBUG
    Write-Log "  Timeout: ${timeout}s" -Level DEBUG
    
    try {
        # Create temp files for output capture
        $stdoutFile = [System.IO.Path]::GetTempFileName()
        $stderrFile = [System.IO.Path]::GetTempFileName()
        
        try {
            # Start process
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = "powershell.exe"
            $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"$command`""
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true
            $psi.UseShellExecute = $false
            $psi.WorkingDirectory = (Resolve-Path $ProjectRoot).Path
            $psi.CreateNoWindow = $true
            
            $process = [System.Diagnostics.Process]::Start($psi)
            
            # Read output asynchronously
            $stdoutTask = $process.StandardOutput.ReadToEndAsync()
            $stderrTask = $process.StandardError.ReadToEndAsync()
            
            # Wait with timeout
            $completed = $process.WaitForExit($timeout * 1000)
            
            if (-not $completed) {
                $process.Kill()
                throw "Verifier timed out after ${timeout}s"
            }
            
            $exitCode = $process.ExitCode
            $stdout = $stdoutTask.Result
            $stderr = $stderrTask.Result
            
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
        } finally {
            # Cleanup temp files
            Remove-Item $stdoutFile -ErrorAction SilentlyContinue
            Remove-Item $stderrFile -ErrorAction SilentlyContinue
        }
    } catch {
        return @{
            Passed = $false
            Reason = "Exception: $_"
            Stdout = ""
            Stderr = $_.Exception.Message
        }
    }
}

function Invoke-AllVerifiers {
    param([array]$Verifiers)
    
    $results = @()
    $allPassed = $true
    
    foreach ($v in $Verifiers) {
        $result = Invoke-Verifier -Verifier $v
        $results += @{
            Name = $v.name
            Passed = $result.Passed
            Reason = $result.Reason
            Timestamp = (Get-Date -Format "o")
        }
        
        if ($result.Passed) {
            Write-Log "  [OK] PASSED: $($v.name)" -Level INFO
        } else {
            Write-Log "  [FAIL] FAILED: $($v.name) - $($result.Reason)" -Level ERROR
            $allPassed = $false
            
            if ($result.Stdout) {
                Write-Log "  stdout: $($result.Stdout.Substring(0, [Math]::Min(200, $result.Stdout.Length)))" -Level DEBUG
            }
            if ($result.Stderr) {
                Write-Log "  stderr: $($result.Stderr.Substring(0, [Math]::Min(200, $result.Stderr.Length)))" -Level DEBUG
            }
            
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

function Invoke-Kimi {
    param(
        [PSCustomObject]$Bead,
        [array]$LastFailures,
        [int]$Iteration
    )
    
    Write-Log "Invoking Kimi for iteration $Iteration..." -Level INFO
    
    $intent = $Bead.intent
    $verifiers = $Bead.dod.verifiers
    
    $verifierList = ($verifiers | ForEach-Object { "- $($_.name): $($_.command)" }) -join "`n"
    
    $failureContext = ""
    if ($LastFailures -and $LastFailures.Count -gt 0) {
        $failures = ($LastFailures | Where-Object { -not $_.Passed } | ForEach-Object {
            "- $($_.Name): $($_.Reason)"
        }) -join "`n"
        $failureContext = "`n`n## Previous Attempt Failures`nThe following verifiers failed in the last attempt. Fix these issues:`n$failures`n"
    }
    
    $prompt = @"
# Ralph Implementation Task

## Intent
$intent

## Definition of Done (DoD)
You MUST ensure ALL of the following verifiers pass:
$verifierList
$failureContext

## Instructions
1. First, run the verifiers to understand what needs to be implemented (TDD)
2. Implement the solution to satisfy the intent
3. Run verifiers again - they MUST all pass
4. Do NOT mark work as complete until ALL verifiers pass

## Output
- Implement the solution
- Ensure all DoD verifiers pass
- Commit your changes with a descriptive message
"@
    
    $promptFile = [System.IO.Path]::GetTempFileName()
    try {
        $prompt | Out-File -FilePath $promptFile -Encoding UTF8
        
        Write-Log "  Prompt file: $promptFile" -Level DEBUG
        
        # Read prompt content and pass via -p flag (Kimi CLI doesn't support --file)
        $promptContent = Get-Content $promptFile -Raw
        
        $kimiProcess = Start-Process -FilePath "kimi" `
            -ArgumentList @("--yolo", "-p", $promptContent) `
            -NoNewWindow -Wait -PassThru
        
        return $kimiProcess.ExitCode -eq 0
    } catch {
        Write-Log "Kimi invocation failed: $_" -Level ERROR
        return $false
    } finally {
        Remove-Item $promptFile -ErrorAction SilentlyContinue
    }
}

#endregion

#region Main Loop

function Start-RalphExecution {
    param([PSCustomObject]$Bead)
    
    $verifiers = $Bead.dod.verifiers
    $maxIter = if ($Bead.constraints.max_iterations) { $Bead.constraints.max_iterations } else { $MaxIterations }
    $backoff = if ($Bead.ralph_meta.retry_backoff_seconds) { $Bead.ralph_meta.retry_backoff_seconds } else { 30 }
    
    Write-Log "Starting Ralph execution" -Level INFO
    Write-Log "  Verifiers: $($verifiers.Count)" -Level INFO
    Write-Log "  Max iterations: $maxIter" -Level INFO
    Write-Log "  Initial backoff: ${backoff}s" -Level INFO
    
    # Setup evidence directory
    $evidencePath = if ($EvidenceDir) { $EvidenceDir } else { Join-Path $ProjectRoot ".ralph/evidence/$(if($Standalone){(Split-Path $BeadFile -LeafBase)}else{$BeadId})" }
    Ensure-Directory -Path $evidencePath
    Write-Log "  Evidence dir: $evidencePath" -Level INFO
    
    $lastResults = $null
    $iteration = 0
    
    while ($iteration -lt $maxIter) {
        $iteration++
        Write-Log "" -Level INFO
        Write-Log "=== Iteration $iteration / $maxIter ===" -Level WARN
        
        # Update metadata
        Update-BeadStatus -Status "in_progress" -Metadata @{
            attempt_count = $iteration
            last_attempt = (Get-Date -Format "o")
        }
        
        # Step 1: Invoke Kimi
        $failureResults = if ($lastResults) { $lastResults.Results } else { $null }
        $success = Invoke-Kimi -Bead $Bead -LastFailures $failureResults -Iteration $iteration
        
        if (-not $success) {
            Write-Log "Kimi invocation failed, will retry..." -Level WARN
            Start-Sleep -Seconds $backoff
            continue
        }
        
        # Step 2: Run verifiers
        Write-Log "Running verifiers..." -Level INFO
        $verifyResult = Invoke-AllVerifiers -Verifiers $verifiers
        $lastResults = $verifyResult
        
        # Update bead with results
        Update-BeadStatus -Status $(if($verifyResult.AllPassed){"completed"}else{"in_progress"}) -Metadata @{
            verifier_results = $verifyResult.Results
            last_failure_summary = if ($verifyResult.AllPassed) { "" } else {
                ($verifyResult.Results | Where-Object { -not $_.Passed } | ForEach-Object { $_.Reason }) -join "; "
            }
        }
        
        # Step 3: Check if all passed
        if ($verifyResult.AllPassed) {
            Write-Log "" -Level INFO
            Write-Log "=== ALL VERIFIERS PASSED ===" -Level INFO
            Write-Log "DoD satisfied after $iteration iteration(s)" -Level INFO
            
            # Save evidence
            $evidenceFile = Join-Path $evidencePath "success-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
            @{
                bead_id = if($Standalone){$BeadFile}else{$BeadId}
                iterations = $iteration
                timestamp = (Get-Date -Format "o")
                results = $verifyResult.Results
            } | ConvertTo-Json -Depth 10 | Out-File $evidenceFile -Encoding UTF8
            
            return @{
                Success = $true
                Iterations = $iteration
                Results = $verifyResult.Results
            }
        }
        
        # Step 4: Retry with backoff
        $backoff = [Math]::Min($backoff * 2, 300)
        Write-Log "Some verifiers failed, retrying after ${backoff}s..." -Level WARN
        Start-Sleep -Seconds $backoff
    }
    
    # Max iterations reached
    Write-Log "" -Level ERROR
    Write-Log "=== MAX ITERATIONS REACHED ===" -Level ERROR
    Write-Log "Failed to satisfy DoD after $maxIter iterations" -Level ERROR
    
    # Save failure evidence
    $evidenceFile = Join-Path $evidencePath "failure-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    @{
        bead_id = if($Standalone){$BeadFile}else{$BeadId}
        iterations = $iteration
        timestamp = (Get-Date -Format "o")
        results = $lastResults.Results
    } | ConvertTo-Json -Depth 10 | Out-File $evidenceFile -Encoding UTF8
    
    Update-BeadStatus -Status "failed" -Metadata @{
        failure_reason = "Max iterations reached"
        final_results = $lastResults.Results
    }
    
    return @{
        Success = $false
        Iterations = $iteration
        Results = $lastResults.Results
    }
}

#endregion

#region Entry Point

function Main {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  RALPH EXECUTOR v$RALPH_VERSION" -ForegroundColor Cyan
    Write-Host "  Windows-Native DoD Enforcement" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Initialize logging
    Initialize-Logging -BeadId $(if($Standalone){(Split-Path $BeadFile -LeafBase)}else{$BeadId})
    
    # Check prerequisites
    if (-not (Test-Prerequisites)) {
        exit 1
    }
    
    # Load bead
    try {
        $bead = Get-BeadData
        Write-Log "Bead loaded: $($bead.title)" -Level INFO
        Write-Log "Intent: $($bead.intent)" -Level INFO
    } catch {
        Write-Log "Failed to load bead: $_" -Level ERROR
        exit 1
    }
    
    # Run execution
    $result = Start-RalphExecution -Bead $bead
    
    Write-Host ""
    if ($result.Success) {
        Write-Host "[SUCCESS] Ralph execution completed" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "[FAILED] Ralph execution failed" -ForegroundColor Red
        exit 1
    }
}

# Run main
Main

#endregion
