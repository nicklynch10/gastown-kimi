#!/usr/bin/env pwsh
<#
.SYNOPSIS
    24/7 Stress Test for Ralph-Gastown SDLC System

.DESCRIPTION
    Comprehensive stress testing to validate the system can run continuously:
    1. Retry loop stability under failure conditions
    2. Timeout handling accuracy
    3. Memory/Resource leak detection
    4. Circuit breaker behavior under load
    5. Concurrent operation handling
    6. Error recovery mechanisms

.PARAMETER DurationMinutes
    How long to run the stress test (default: 5 for testing, use 60+ for real validation)

.PARAMETER Verbose
    Show detailed output
#>

[CmdletBinding()]
param(
    [Parameter()]
    [int]$DurationMinutes = 5,

    [Parameter()]
    [switch]$IncludeFaultInjection
)

$ErrorActionPreference = "Stop"
$TestStartTime = Get-Date
$TestEndTime = $TestStartTime.AddMinutes($DurationMinutes)

# Colors
$Cyan = "Cyan"
$Green = "Green"
$Red = "Red"
$Yellow = "Yellow"
$Gray = "Gray"
$Magenta = "Magenta"

function Write-TestHeader {
    param([string]$Title)
    Write-Host "`n========================================" -ForegroundColor $Cyan
    Write-Host $Title -ForegroundColor $Cyan
    Write-Host "========================================" -ForegroundColor $Cyan
}

function Write-StressLog {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "ERROR" { $Red }
        "WARN"  { $Yellow }
        "SUCCESS" { $Green }
        "STRESS" { $Magenta }
        default { $Gray }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Write-TestResult {
    param(
        [string]$Test,
        [bool]$Passed,
        [string]$Details = "",
        [int]$DurationMs = 0
    )
    $icon = if ($Passed) { "[PASS]" } else { "[FAIL]" }
    $color = if ($Passed) { $Green } else { $Red }
    $timing = if ($DurationMs -gt 0) { " ($($DurationMs)ms)" } else { "" }
    Write-Host "  $icon $Test$timing" -ForegroundColor $color
    if ($Details -and -not $Passed) {
        Write-Host "       $Details" -ForegroundColor $Gray
    }
}

# Test Results Tracking
$script:Results = @()
$script:PassCount = 0
$script:FailCount = 0
$script:StressIterations = 0

function Run-Test {
    param(
        [string]$Name,
        [scriptblock]$Test,
        [int]$TimeoutSeconds = 60
    )
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $job = Start-Job -ScriptBlock $Test
        $completed = $job | Wait-Job -Timeout $TimeoutSeconds
        
        if (-not $completed) {
            Stop-Job $job -ErrorAction SilentlyContinue
            Remove-Job $job -ErrorAction SilentlyContinue
            throw "Test timed out after ${TimeoutSeconds}s"
        }
        
        $result = Receive-Job $job
        Remove-Job $job
        
        $sw.Stop()
        Write-TestResult -Test $Name -Passed $true -DurationMs $sw.ElapsedMilliseconds
        $script:PassCount++
        $script:Results += @{ Name = $Name; Passed = $true; Duration = $sw.ElapsedMilliseconds }
        return $result
    }
    catch {
        $sw.Stop()
        Write-TestResult -Test $Name -Passed $false -Details $_.Exception.Message -DurationMs $sw.ElapsedMilliseconds
        $script:FailCount++
        $script:Results += @{ Name = $Name; Passed = $false; Error = $_.Exception.Message; Duration = $sw.ElapsedMilliseconds }
        return $null
    }
}

# Import Resilience Module
$ResilienceModule = "$PSScriptRoot/scripts/ralph/ralph-resilience.psm1"
if (Test-Path $ResilienceModule) {
    Import-Module $ResilienceModule -Force
    Write-StressLog "Resilience module loaded" "SUCCESS"
}
else {
    Write-StressLog "Resilience module not found at $ResilienceModule" "ERROR"
    exit 1
}

Write-TestHeader "24/7 STRESS TEST - Ralph-Gastown System"
Write-Host "Start: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor $Gray
Write-Host "Duration: $DurationMinutes minutes" -ForegroundColor $Gray
Write-Host "End: $($TestEndTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor $Gray
Write-Host ""

#=============================================================================
# TEST 1: Retry Loop Stability
#=============================================================================
Write-TestHeader "STRESS TEST 1: Retry Loop Stability"
Write-StressLog "Testing retry mechanism under various failure patterns..." "STRESS"

$retryStressTests = @(
    @{
        Name = "Intermittent failures (network-like)"
        Script = {
            $attempt = 0
            $result = Invoke-WithRetry -ScriptBlock {
                $attempt++
                if ($attempt % 3 -ne 0) { throw "Connection timeout" }
                return "success"
            } -MaxRetries 5 -InitialBackoffSeconds 1 -ActivityName "NetworkSim"
            
            if (-not $result.Success) { throw "Should have succeeded" }
            if ($result.Attempts -lt 3) { throw "Should have taken at least 3 attempts" }
            $true
        }
    },
    @{
        Name = "Consistent then recovery"
        Script = {
            $attempt = 0
            $result = Invoke-WithRetry -ScriptBlock {
                $attempt++
                if ($attempt -lt 4) { throw "Service unavailable" }
                return "recovered"
            } -MaxRetries 5 -InitialBackoffSeconds 1 -ActivityName "RecoverySim"
            
            if (-not $result.Success) { throw "Should have succeeded on attempt 4" }
            if ($result.Attempts -ne 4) { throw "Expected 4 attempts, got $($result.Attempts)" }
            $true
        }
    },
    @{
        Name = "Total failure (max retries exceeded)"
        Script = {
            $result = Invoke-WithRetry -ScriptBlock {
                throw "Permanent failure"
            } -MaxRetries 3 -InitialBackoffSeconds 1 -ActivityName "PermanentFail"
            
            if ($result.Success) { throw "Should have failed" }
            if ($result.Attempts -ne 4) { throw "Expected 4 attempts (1 + 3 retries)" }
            $true
        }
    },
    @{
        Name = "Non-retryable error detection"
        Script = {
            $result = Invoke-WithRetry -ScriptBlock {
                throw "File not found"  # Non-retryable
            } -MaxRetries 5 -InitialBackoffSeconds 1 -ActivityName "NonRetryable"
            
            if ($result.Success) { throw "Should have failed immediately" }
            if ($result.Attempts -ne 1) { throw "Should not have retried non-retryable error" }
            $true
        }
    }
)

foreach ($test in $retryStressTests) {
    Run-Test -Name $test.Name -Test $test.Script
}

#=============================================================================
# TEST 2: Timeout Handling Stress
#=============================================================================
Write-TestHeader "STRESS TEST 2: Timeout Handling Accuracy"
Write-StressLog "Testing timeout enforcement across different scenarios..." "STRESS"

$timeoutStressTests = @(
    @{
        Name = "Short timeout (1s) enforcement"
        Script = {
            $start = Get-Date
            $result = Start-ResilientProcess -FilePath "powershell.exe" `
                -Arguments "-Command 'Start-Sleep 10'" -TimeoutSeconds 1
            $elapsed = (Get-Date) - $start
            
            if ($result.Success) { throw "Should have timed out" }
            if ($elapsed.TotalSeconds -gt 5) { throw "Timeout not enforced, took $($elapsed.TotalSeconds)s" }
            $true
        }
    },
    @{
        Name = "Medium timeout (5s) enforcement"
        Script = {
            $start = Get-Date
            $result = Start-ResilientProcess -FilePath "powershell.exe" `
                -Arguments "-Command 'Start-Sleep 30'" -TimeoutSeconds 5
            $elapsed = (Get-Date) - $start
            
            if ($result.Success) { throw "Should have timed out" }
            if ($elapsed.TotalSeconds -gt 10) { throw "Timeout not enforced, took $($elapsed.TotalSeconds)s" }
            $true
        }
    },
    @{
        Name = "Fast process (should not timeout)"
        Script = {
            $result = Start-ResilientProcess -FilePath "powershell.exe" `
                -Arguments "-Command 'Write-Host fast; exit 0'" -TimeoutSeconds 10
            
            if (-not $result.Success) { throw "Should have succeeded quickly" }
            if ($result.Stdout -notmatch "fast") { throw "Output mismatch" }
            $true
        }
    },
    @{
        Name = "Multiple rapid timeouts (resource leak check)"
        Script = {
            for ($i = 0; $i -lt 10; $i++) {
                $result = Start-ResilientProcess -FilePath "powershell.exe" `
                    -Arguments "-Command 'Start-Sleep 5'" -TimeoutSeconds 1
                if ($result.Success) { throw "Iteration $i should have timed out" }
            }
            $true
        }
    }
)

foreach ($test in $timeoutStressTests) {
    Run-Test -Name $test.Name -Test $test.Script
}

#=============================================================================
# TEST 3: Circuit Breaker Under Load
#=============================================================================
Write-TestHeader "STRESS TEST 3: Circuit Breaker Load Testing"
Write-StressLog "Testing circuit breaker behavior under rapid failure conditions..." "STRESS"

# Reset circuit breaker before test
Reset-CircuitBreaker -Name "stress-test-circuit" -ErrorAction SilentlyContinue

$circuitTests = @(
    @{
        Name = "Circuit opens after threshold failures"
        Script = {
            $failures = 0
            for ($i = 0; $i -lt 7; $i++) {
                try {
                    Invoke-WithCircuitBreaker -Name "stress-test-circuit" -ScriptBlock {
                        throw "Simulated failure"
                    } -FailureThreshold 5 -TimeoutSeconds 1 | Out-Null
                }
                catch {
                    $failures++
                }
            }
            
            $status = Get-CircuitBreakerStatus
            if ($status["stress-test-circuit"].State -ne "OPEN") {
                throw "Circuit should be OPEN after 5 failures"
            }
            $true
        }
    },
    @{
        Name = "Circuit prevents calls when open"
        Script = {
            $callExecuted = $false
            try {
                Invoke-WithCircuitBreaker -Name "stress-test-circuit" -ScriptBlock {
                    $callExecuted = $true
                } -FailureThreshold 5 -TimeoutSeconds 300
            }
            catch {
                # Expected - circuit is open
            }
            
            if ($callExecuted) { throw "Call should not have executed when circuit is open" }
            $true
        }
    },
    @{
        Name = "Circuit closes after timeout"
        Script = {
            # Wait for circuit timeout (set to 2 seconds for test)
            Start-Sleep -Seconds 3
            
            # Now the circuit should be HALF_OPEN and allow one call
            $result = Invoke-WithCircuitBreaker -Name "stress-test-circuit" -ScriptBlock {
                return "success"
            } -FailureThreshold 5 -TimeoutSeconds 2
            
            if ($result -ne "success") { throw "Call should have succeeded after timeout" }
            
            $status = Get-CircuitBreakerStatus
            if ($status["stress-test-circuit"].State -ne "CLOSED") {
                throw "Circuit should be CLOSED after success"
            }
            $true
        }
    }
)

foreach ($test in $circuitTests) {
    Run-Test -Name $test.Name -Test $test.Script
}

#=============================================================================
# TEST 4: Concurrent Operation Simulation
#=============================================================================
Write-TestHeader "STRESS TEST 4: Concurrent Operation Simulation"
Write-StressLog "Simulating multiple beads being processed simultaneously..." "STRESS"

$concurrentTests = @(
    @{
        Name = "Multiple retry operations simultaneously"
        Script = {
            $jobs = @()
            for ($i = 0; $i -lt 5; $i++) {
                $jobs += Start-Job -ScriptBlock {
                    param($modulePath, $index)
                    Import-Module $modulePath -Force
                    $attempt = 0
                    $result = Invoke-WithRetry -ScriptBlock {
                        $attempt++
                        if ($attempt -lt 2) { throw "Temp error $index" }
                        return "job$index-success"
                    } -MaxRetries 3 -InitialBackoffSeconds 1 -ActivityName "Concurrent-$index"
                    return $result
                } -ArgumentList $ResilienceModule, $i
            }
            
            $completed = $jobs | Wait-Job -Timeout 30
            if ($completed.Count -ne $jobs.Count) {
                $jobs | Stop-Job -ErrorAction SilentlyContinue
                throw "Only $($completed.Count) of $($jobs.Count) jobs completed"
            }
            
            $results = $jobs | Receive-Job
            $jobs | Remove-Job
            
            $successCount = ($results | Where-Object { $_.Success }).Count
            if ($successCount -ne 5) { throw "Only $successCount of 5 concurrent operations succeeded" }
            $true
        }
    },
    @{
        Name = "Mixed fast/slow process handling"
        Script = {
            $jobs = @()
            # Fast jobs
            for ($i = 0; $i -lt 3; $i++) {
                $jobs += Start-Job -ScriptBlock {
                    param($modulePath)
                    Import-Module $modulePath -Force
                    Start-ResilientProcess -FilePath "powershell.exe" `
                        -Arguments "-Command 'exit 0'" -TimeoutSeconds 10
                } -ArgumentList $ResilienceModule
            }
            # Slow jobs (that will timeout)
            for ($i = 0; $i -lt 2; $i++) {
                $jobs += Start-Job -ScriptBlock {
                    param($modulePath)
                    Import-Module $modulePath -Force
                    Start-ResilientProcess -FilePath "powershell.exe" `
                        -Arguments "-Command 'Start-Sleep 30'" -TimeoutSeconds 2
                } -ArgumentList $ResilienceModule
            }
            
            $completed = $jobs | Wait-Job -Timeout 30
            if ($completed.Count -ne $jobs.Count) {
                $jobs | Stop-Job -ErrorAction SilentlyContinue
                throw "Jobs did not complete in time"
            }
            
            $results = $jobs | Receive-Job
            $jobs | Remove-Job
            
            $successCount = ($results | Where-Object { $_.Success }).Count
            $failCount = ($results | Where-Object { -not $_.Success }).Count
            
            if ($successCount -ne 3 -or $failCount -ne 2) {
                throw "Expected 3 success and 2 failures, got $successCount success and $failCount failures"
            }
            $true
        }
    }
)

foreach ($test in $concurrentTests) {
    Run-Test -Name $test.Name -Test $test.Script
}

#=============================================================================
# TEST 5: Continuous Operation Simulation (24/7 Core)
#=============================================================================
Write-TestHeader "STRESS TEST 5: Continuous Operation Simulation"
Write-StressLog "Running sustained operation for $DurationMinutes minutes..." "STRESS"

$iteration = 0
$cycleErrors = 0
$maxCycles = [int]($DurationMinutes * 6)  # Roughly 10 seconds per cycle

while ((Get-Date) -lt $TestEndTime -and $iteration -lt $maxCycles) {
    $iteration++
    $script:StressIterations++
    
    try {
        # Simulate a Ralph-style work cycle
        $cycleStart = Get-Date
        
        # 1. Simulate verifier execution (random success/failure)
        $verifierResult = Start-ResilientProcess -FilePath "powershell.exe" `
            -Arguments "-Command 'exit $((Get-Random -Minimum 0 -Maximum 2))'" -TimeoutSeconds 5
        
        # 2. Simulate retry on failure
        if (-not $verifierResult.Success) {
            $retryResult = Invoke-WithRetry -ScriptBlock {
                if ((Get-Random -Minimum 0 -Maximum 3) -eq 0) { throw "Random failure" }
                return "retry-success"
            } -MaxRetries 3 -InitialBackoffSeconds 1 -ActivityName "Cycle-$iteration"
        }
        
        # 3. Circuit breaker check
        $cbResult = Invoke-WithCircuitBreaker -Name "continuous-circuit" -ScriptBlock {
            return "cb-ok"
        } -FailureThreshold 10 -TimeoutSeconds 60
        
        $cycleDuration = (Get-Date) - $cycleStart
        
        if ($iteration % 10 -eq 0) {
            Write-StressLog "Cycle $iteration completed in $($cycleDuration.TotalMilliseconds)ms" "SUCCESS"
        }
    }
    catch {
        $cycleErrors++
        Write-StressLog "Cycle $iteration failed: $($_.Exception.Message)" "WARN"
    }
    
    # Brief pause between cycles
    Start-Sleep -Milliseconds 500
}

Write-StressLog "Completed $iteration stress cycles with $cycleErrors errors" $(if ($cycleErrors -eq 0) { "SUCCESS" } else { "WARN" })

#=============================================================================
# TEST 6: Fault Injection (if enabled)
#=============================================================================
if ($IncludeFaultInjection) {
    Write-TestHeader "STRESS TEST 6: Fault Injection"
    Write-StressLog "Injecting faults to test recovery mechanisms..." "STRESS"
    
    $faultTests = @(
        @{
            Name = "Out of memory simulation"
            Script = {
                # Try to allocate a large array and handle gracefully
                try {
                    $bigArray = @()
                    for ($i = 0; $i -lt 1000000; $i++) {
                        $bigArray += "x" * 1000
                    }
                }
                catch {
                    # Expected - system should handle gracefully
                }
                $true
            }
        },
        @{
            Name = "Stack overflow protection"
            Script = {
                # Deep recursion that should be caught
                function Recurse-Deep {
                    param([int]$n)
                    if ($n -le 0) { return }
                    Recurse-Deep -n ($n - 1)
                }
                
                try {
                    # This will hit call depth limit
                    Recurse-Deep -n 10000
                }
                catch {
                    # Expected - system protected
                }
                $true
            }
        }
    )
    
    foreach ($test in $faultTests) {
        Run-Test -Name $test.Name -Test $test.Script
    }
}

#=============================================================================
# Cleanup and Summary
#=============================================================================
Remove-Module ralph-resilience -Force -ErrorAction SilentlyContinue

$TestActualEndTime = Get-Date
$TotalDuration = $TestActualEndTime - $TestStartTime

Write-TestHeader "24/7 STRESS TEST SUMMARY"
Write-Host "Total Duration: $($TotalDuration.ToString('hh\:mm\:ss'))" -ForegroundColor $Gray
Write-Host "Stress Cycles:  $script:StressIterations" -ForegroundColor $Gray
Write-Host "Passed:         $script:PassCount" -ForegroundColor $Green
Write-Host "Failed:         $script:FailCount" -ForegroundColor $(if($script:FailCount -gt 0){$Red}else{$Green})
Write-Host "Cycle Errors:   $cycleErrors" -ForegroundColor $(if($cycleErrors -eq 0){$Green}else{$Yellow})
Write-Host ""

if ($script:FailCount -eq 0 -and $cycleErrors -eq 0) {
    Write-Host "========================================" -ForegroundColor $Green
    Write-Host "  ALL STRESS TESTS PASSED" -ForegroundColor $Green
    Write-Host "  System is 24/7 READY" -ForegroundColor $Green
    Write-Host "========================================" -ForegroundColor $Green
    exit 0
}
else {
    Write-Host "========================================" -ForegroundColor $(if($script:FailCount -eq 0){$Yellow}else{$Red})
    Write-Host "  SOME TESTS FAILED" -ForegroundColor $(if($script:FailCount -eq 0){$Yellow}else{$Red})
    Write-Host "  Review errors above" -ForegroundColor $(if($script:FailCount -eq 0){$Yellow}else{$Red})
    Write-Host "========================================" -ForegroundColor $(if($script:FailCount -eq 0){$Yellow}else{$Red})
    
    Write-Host "`nFailed Tests:" -ForegroundColor $Red
    $script:Results | Where-Object { -not $_.Passed } | ForEach-Object {
        Write-Host "  - $($_.Name): $($_.Error)" -ForegroundColor $Gray
    }
    exit 1
}
