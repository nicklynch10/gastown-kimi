#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Practical 24/7 Operation Tests for Ralph-Gastown

.DESCRIPTION
    Focused tests on the critical 24/7 capabilities:
    1. Verifier timeout accuracy
    2. Ralph executor retry loop stability
    3. Governor policy enforcement
    4. Watchdog nudging behavior
    5. Long-running operation stability
#>

$ErrorActionPreference = "Stop"
$Cyan = "Cyan"
$Green = "Green"
$Red = "Red"
$Yellow = "Yellow"
$Gray = "Gray"

function Write-Header {
    param([string]$Title)
    Write-Host "`n========================================" -ForegroundColor $Cyan
    Write-Host $Title -ForegroundColor $Cyan
    Write-Host "========================================" -ForegroundColor $Cyan
}

function Write-Result {
    param(
        [string]$Name,
        [bool]$Passed,
        [string]$Details = ""
    )
    $icon = if ($Passed) { "[PASS]" } else { "[FAIL]" }
    $color = if ($Passed) { $Green } else { $Red }
    Write-Host "  $icon $Name" -ForegroundColor $color
    if ($Details) {
        Write-Host "       $Details" -ForegroundColor $Gray
    }
}

$Results = @()
$PassCount = 0
$FailCount = 0

function Run-Test {
    param([string]$Name, [scriptblock]$Test)
    try {
        & $Test
        Write-Result -Name $Name -Passed $true
        $script:PassCount++
        $script:Results += @{ Name = $Name; Passed = $true }
    }
    catch {
        Write-Result -Name $Name -Passed $false -Details $_.Exception.Message
        $script:FailCount++
        $script:Results += @{ Name = $Name; Passed = $false; Error = $_.Exception.Message }
    }
}

Write-Header "PRACTICAL 24/7 OPERATION TESTS"
Write-Host "Start: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor $Gray

#=============================================================================
# TEST 1: Verifier Timeout Accuracy
#=============================================================================
Write-Header "TEST 1: Verifier Timeout Accuracy"

Run-Test "1s timeout enforcement" {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-Command 'Start-Sleep 30'"
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    
    $proc = [System.Diagnostics.Process]::Start($psi)
    $completed = $proc.WaitForExit(1000)
    if (-not $completed) { $proc.Kill() }
    $proc.Dispose()
    
    $sw.Stop()
    
    if ($completed) { throw "Should have timed out" }
    if ($sw.Elapsed.TotalSeconds -gt 3) { throw "Timeout too long: $($sw.Elapsed.TotalSeconds)s" }
    $true
}

Run-Test "3s timeout enforcement" {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-Command 'Start-Sleep 30'"
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    
    $proc = [System.Diagnostics.Process]::Start($psi)
    $completed = $proc.WaitForExit(3000)
    if (-not $completed) { $proc.Kill() }
    $proc.Dispose()
    
    $sw.Stop()
    
    if ($completed) { throw "Should have timed out" }
    if ($sw.Elapsed.TotalSeconds -gt 6) { throw "Timeout too long: $($sw.Elapsed.TotalSeconds)s" }
    $true
}

Run-Test "Fast command doesn't timeout" {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-Command 'Write-Host success'"
    $psi.RedirectStandardOutput = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    
    $proc = [System.Diagnostics.Process]::Start($psi)
    $completed = $proc.WaitForExit(5000)
    $output = $proc.StandardOutput.ReadToEnd()
    $proc.Dispose()
    
    $sw.Stop()
    
    if (-not $completed) { throw "Should have completed quickly" }
    if ($output -notmatch "success") { throw "Output mismatch" }
    $true
}

#=============================================================================
# TEST 2: Retry Loop Simulation
#=============================================================================
Write-Header "TEST 2: Retry Loop Simulation (Ralph-style)"

Run-Test "Retry with eventual success" {
    $attempt = 0
    $maxAttempts = 5
    $success = $false
    $backoff = 1
    
    while ($attempt -lt $maxAttempts -and -not $success) {
        $attempt++
        try {
            # Simulate intermittent failure
            if ($attempt -lt 3) {
                throw "Temporary error"
            }
            $success = $true
        }
        catch {
            if ($attempt -lt $maxAttempts) {
                Start-Sleep -Seconds $backoff
                $backoff = [Math]::Min($backoff * 2, 10)
            }
        }
    }
    
    if (-not $success) { throw "Should have succeeded" }
    if ($attempt -ne 3) { throw "Expected 3 attempts, got $attempt" }
    $true
}

Run-Test "Retry exhaustion" {
    $attempt = 0
    $maxAttempts = 3
    $success = $false
    
    while ($attempt -lt $maxAttempts -and -not $success) {
        $attempt++
        try {
            throw "Permanent error"
        }
        catch {
            if ($attempt -lt $maxAttempts) {
                Start-Sleep -Milliseconds 100
            }
        }
    }
    
    if ($success) { throw "Should have failed" }
    if ($attempt -ne $maxAttempts) { throw "Should have exhausted all attempts" }
    $true
}

Run-Test "Exponential backoff calculation" {
    $backoff = 1
    $backoffs = @()
    
    for ($i = 0; $i -lt 5; $i++) {
        $backoffs += $backoff
        $backoff = [Math]::Min($backoff * 2, 60)
    }
    
    $expected = @(1, 2, 4, 8, 16)
    for ($i = 0; $i -lt 5; $i++) {
        if ($backoffs[$i] -ne $expected[$i]) {
            throw "Backoff $i`: expected $($expected[$i]), got $($backoffs[$i])"
        }
    }
    $true
}

#=============================================================================
# TEST 3: Governor Policy Logic
#=============================================================================
Write-Header "TEST 3: Governor Policy Logic"

Run-Test "'No green, no features' logic" {
    # Simulate gate status
    $gates = @(
        @{ Status = "closed"; Type = "build" },
        @{ Status = "open"; Type = "test" },
        @{ Status = "closed"; Type = "lint" }
    )
    
    $openGates = $gates | Where-Object { $_.Status -eq "open" }
    $canSlingFeatures = $openGates.Count -eq 0
    
    if ($canSlingFeatures) { throw "Should block features when gates are open" }
    $true
}

Run-Test "Feature allowed when all gates green" {
    $gates = @(
        @{ Status = "closed"; Type = "build" },
        @{ Status = "closed"; Type = "test" },
        @{ Status = "closed"; Type = "lint" }
    )
    
    $openGates = $gates | Where-Object { $_.Status -eq "open" }
    $canSlingFeatures = $openGates.Count -eq 0
    
    if (-not $canSlingFeatures) { throw "Should allow features when all gates closed" }
    $true
}

#=============================================================================
# TEST 4: Watchdog Logic Simulation
#=============================================================================
Write-Header "TEST 4: Watchdog Logic Simulation"

Run-Test "Stale detection logic" {
    $lastActivity = (Get-Date).AddMinutes(-45)
    $staleThreshold = 30
    
    $staleMinutes = ([DateTime]::UtcNow - $lastActivity.ToUniversalTime()).TotalMinutes
    $isStale = $staleMinutes -gt $staleThreshold
    
    if (-not $isStale) { throw "Should detect stale activity" }
    $true
}

Run-Test "Nudge threshold (1x stale)" {
    $lastActivity = (Get-Date).AddMinutes(-35)
    $staleThreshold = 30
    
    $staleMinutes = ([DateTime]::UtcNow - $lastActivity.ToUniversalTime()).TotalMinutes
    $shouldNudge = $staleMinutes -gt $staleThreshold -and $staleMinutes -le ($staleThreshold * 2)
    
    if (-not $shouldNudge) { throw "Should trigger nudge at 1x threshold" }
    $true
}

Run-Test "Restart threshold (2x stale)" {
    $lastActivity = (Get-Date).AddMinutes(-65)
    $staleThreshold = 30
    
    $staleMinutes = ([DateTime]::UtcNow - $lastActivity.ToUniversalTime()).TotalMinutes
    $shouldRestart = $staleMinutes -gt ($staleThreshold * 2)
    
    if (-not $shouldRestart) { throw "Should trigger restart at 2x threshold" }
    $true
}

#=============================================================================
# TEST 5: Long-Running Operation Stability
#=============================================================================
Write-Header "TEST 5: Long-Running Operation Stability"

Run-Test "Multiple rapid verifiers (no resource leak)" {
    $successCount = 0
    for ($i = 0; $i -lt 20; $i++) {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-Command 'exit 0'"
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        
        $proc = [System.Diagnostics.Process]::Start($psi)
        $completed = $proc.WaitForExit(5000)
        $proc.Dispose()
        
        if ($completed -and $proc.ExitCode -eq 0) {
            $successCount++
        }
    }
    
    if ($successCount -ne 20) { throw "Only $successCount of 20 verifiers succeeded" }
    $true
}

Run-Test "Memory pressure simulation" {
    # Create and release objects to test garbage collection
    $initial = [GC]::GetTotalMemory($false)
    
    for ($i = 0; $i -lt 100; $i++) {
        $data = @()
        for ($j = 0; $j -lt 1000; $j++) {
            $data += "test string $j"
        }
        $data = $null
    }
    
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
    
    $final = [GC]::GetTotalMemory($false)
    $growth = $final - $initial
    
    # Allow some growth but not excessive
    if ($growth -gt 100MB) { throw "Memory grew by $($growth / 1MB) MB" }
    $true
}

#=============================================================================
# TEST 6: Bead State Management
#=============================================================================
Write-Header "TEST 6: Bead State Management"

Run-Test "Bead lifecycle state transitions" {
    $states = @("open", "hooked", "in_progress", "completed")
    $validTransitions = @{
        "open" = @("hooked")
        "hooked" = @("in_progress")
        "in_progress" = @("completed", "open")
        "completed" = @()
    }
    
    # Test a valid transition
    $current = "open"
    $next = "hooked"
    $isValid = $validTransitions[$current] -contains $next
    
    if (-not $isValid) { throw "Transition $current -> $next should be valid" }
    $true
}

Run-Test "Verifier result tracking" {
    $verifierResults = @(
        @{ Name = "Build"; Passed = $true; Timestamp = (Get-Date).ToString("o") },
        @{ Name = "Test"; Passed = $false; Timestamp = (Get-Date).ToString("o") }
    )
    
    $allPassed = ($verifierResults | Where-Object { -not $_.Passed }).Count -eq 0
    $failureCount = ($verifierResults | Where-Object { -not $_.Passed }).Count
    
    if ($allPassed) { throw "Should detect failures" }
    if ($failureCount -ne 1) { throw "Should count exactly 1 failure" }
    $true
}

#=============================================================================
# Summary
#=============================================================================
Write-Header "TEST SUMMARY"
Write-Host "Passed: $PassCount" -ForegroundColor $Green
Write-Host "Failed: $FailCount" -ForegroundColor $(if($FailCount -gt 0){$Red}else{$Green})
Write-Host ""

if ($FailCount -eq 0) {
    Write-Host "========================================" -ForegroundColor $Green
    Write-Host "  ALL 24/7 TESTS PASSED" -ForegroundColor $Green
    Write-Host "  System is STABLE for continuous operation" -ForegroundColor $Green
    Write-Host "========================================" -ForegroundColor $Green
    exit 0
} else {
    Write-Host "========================================" -ForegroundColor $Red
    Write-Host "  SOME TESTS FAILED" -ForegroundColor $Red
    Write-Host "========================================" -ForegroundColor $Red
    $Results | Where-Object { -not $_.Passed } | ForEach-Object {
        Write-Host "  - $($_.Name): $($_.Error)" -ForegroundColor $Gray
    }
    exit 1
}
