# Ralph-Gastown 24/7 SDLC - Clean Installation Prompt

> **Copy and paste this entire prompt to set up the Ralph-Gastown system on a CLEAN computer.**
> 
> **Repository:** https://github.com/nicklynch10/gastown-kimi.git

---

## YOUR MISSION

Set up the Ralph-Gastown 24/7 SDLC system on a **clean Windows machine** from scratch. This system provides:

- **Gastown** = Durable work tracking (Beads, hooks, convoys)
- **Ralph** = Retry-until-verified execution (DoD enforcement)
- **24/7 Watchdog** = Always-on monitoring and recovery

---

## SECTION 1: PREREQUISITES CHECK

Before cloning, verify these are installed on the clean machine:

```powershell
# Open PowerShell and run:

Write-Host "=== PREREQUISITES CHECK ===" -ForegroundColor Cyan

# 1. PowerShell version (MUST be 5.1+)
$psVersion = $PSVersionTable.PSVersion
Write-Host "PowerShell: $($psVersion.Major).$($psVersion.Minor)" -ForegroundColor $(if($psVersion.Major -ge 5){"Green"}else{"Red"})

# 2. Git
try {
    $gitVersion = git --version
    Write-Host "Git: $gitVersion" -ForegroundColor Green
} catch {
    Write-Host "Git: NOT INSTALLED - Install from https://git-scm.com/download/win" -ForegroundColor Red
}

# 3. Execution Policy
$execPol = Get-ExecutionPolicy
Write-Host "Execution Policy: $execPol" -ForegroundColor $(if($execPol -eq "RemoteSigned" -or $execPol -eq "Unrestricted"){"Green"}else{"Yellow"})

# If execution policy is Restricted, run:
# Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Optional tools (system works without these)
Write-Host "`nOptional Tools:" -ForegroundColor Yellow
Get-Command go -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "  Go: $($_.Source)" -ForegroundColor Green }
Get-Command node -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "  Node: $($_.Source)" -ForegroundColor Green }
```

**Required:** PowerShell 5.1+, Git, RemoteSigned execution policy

---

## SECTION 2: CLONE THE REPOSITORY

```powershell
# Navigate to where you want the project
cd $env:USERPROFILE\Documents  # Or your preferred location

# Clone the repository
git clone https://github.com/nicklynch10/gastown-kimi.git

# Enter the project directory
cd gastown-kimi

# Verify clone worked
Write-Host "`nRepository contents:" -ForegroundColor Cyan
Get-ChildItem | Select-Object -First 10
```

**Expected:** You should see directories: `scripts/`, `docs/`, `examples/`, `.beads/`, etc.

---

## SECTION 3: INITIAL VALIDATION

Run the system tests to verify the baseline:

```powershell
# Run system tests (58 tests)
.\scripts\ralph\test\ralph-system-test.ps1 -TestType all
```

**Expected:**
```
========================================
TEST SUMMARY
========================================
Duration: ~1s
Passed: 58
Failed: 0
Skipped: 1

ALL TESTS PASSED
```

If tests fail, STOP and report errors before proceeding.

---

## SECTION 4: LIVE MATERIAL TESTS

Run tests that execute real commands and create actual files:

```powershell
# Run live tests (26 tests with real operations)
.\scripts\ralph\test\ralph-live-test.ps1
```

**Expected:** 26/26 tests pass

---

## SECTION 5: FULL VALIDATION SUITE

Run the complete 56-test validation:

```powershell
# Run full validation
.\scripts\ralph\ralph-validate.ps1
```

**Expected:** 56/56 tests pass

---

## SECTION 6: CHECK SYSTEM STATUS

```powershell
# Check Ralph system status
.\scripts\ralph\ralph-master.ps1 -Command status
```

**Expected output includes:**
- Ralph Formulas: All OK
- Ralph Scripts: All OK
- Gate Status: Features allowed

---

## SECTION 7: INSTALL THE WATCHDOG (24/7 Monitoring)

The watchdog runs as a Windows Scheduled Task to monitor the system every 5 minutes.

```powershell
# Option A: Using the setup script (recommended)
.\scripts\ralph\setup-watchdog.ps1

# Option B: Manual setup
.\scripts\ralph\manage-watchdog.ps1 -Action install
```

**Verify installation:**
```powershell
.\scripts\ralph\manage-watchdog.ps1 -Action status
```

**Expected:**
```
=== Ralph Watchdog Manager ===
Status: Ready
Next Run: [timestamp]
Last Run: [timestamp]
Last Result: 0
==============================
```

---

## SECTION 8: TEST DEMO APPLICATIONS

### Calculator Demo
```powershell
cd examples\ralph-demo
.\test.ps1
cd ..\..
```

**Expected:** 5/5 tests pass

### Task Manager Demo
```powershell
cd examples\taskmanager-app
.\tests\Simple.Tests.ps1
cd ..\..
```

**Expected:** 12/12 tests pass

---

## SECTION 9: CREATE YOUR FIRST BEAD

Test the bead creation workflow:

```powershell
# Create a bead with DoD
.\scripts\ralph\ralph-master.ps1 -Command create-bead -Intent "My first Ralph bead"
```

**Verify it was created:**
```powershell
Get-ChildItem .ralph\beads\*.json | Select-Object -First 5
```

---

## SECTION 10: CREATE YOUR FIRST GATE

```powershell
# Create a smoke test gate
.\scripts\ralph\ralph-master.ps1 -Command create-gate -GateType smoke

# Create a build gate
.\scripts\ralph\ralph-master.ps1 -Command create-gate -GateType build
```

**Verify gates were created:**
```powershell
Get-ChildItem .ralph\gates\*.json | Select-Object -First 5
```

---

## SECTION 11: TEST GOVERNOR

```powershell
# Check gate status
.\scripts\ralph\ralph-governor.ps1 -Action check
```

**Expected:** "POLICY: Features allowed - All gates green"

---

## SECTION 12: TEST RESILIENCE MODULE

```powershell
# Import and test the resilience module
Import-Module .\scripts\ralph\ralph-resilience.psm1 -Force

# Test retry functionality
$result = Invoke-WithRetry -ScriptBlock { 
    Write-Output "Success"
} -MaxRetries 3 -InitialBackoffSeconds 1

Write-Host "Retry test: $result"

# Test circuit breaker
try {
    $cbResult = Invoke-WithCircuitBreaker -Name "setup-test" -ScriptBlock {
        throw "Test failure"
    } -FailureThreshold 2 -TimeoutSeconds 5
} catch {
    Write-Host "Circuit breaker correctly tripped" -ForegroundColor Green
}
```

---

## SECTION 13: TEST BROWSER MODULE

```powershell
# Import browser module
Import-Module .\scripts\ralph\ralph-browser.psm1 -Force

# Create test context
$ctx = New-BrowserTestContext -TestName "setup-test" -BaseUrl "https://example.com"

Write-Host "Browser context created:" -ForegroundColor Green
Write-Host "  Test Name: $($ctx.TestName)"
Write-Host "  Base URL: $($ctx.BaseUrl)"
```

---

## SECTION 14: MANUAL WATCHDOG TEST

Run the watchdog once manually to verify it works:

```powershell
.\scripts\ralph\ralph-watchdog.ps1 -RunOnce -Verbose
```

**Expected:**
- "Ralph Watchdog STARTED"
- "Scanning hooks..."
- "Iteration complete: 0 processed, 0 nudged, 0 restarted"
- Clean exit

---

## SECTION 15: FINAL VERIFICATION

Run this comprehensive verification:

```powershell
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  FINAL SETUP VERIFICATION" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$results = @()

# Test 1: System tests
Write-Host "`n[1/7] System tests..." -ForegroundColor Yellow
$sys = .\scripts\ralph\test\ralph-system-test.ps1 -TestType all 2>&1
$sysPass = ($sys -match "ALL TESTS PASSED")
$results += @{ Name = "System Tests (58)"; Pass = $sysPass }
Write-Host "  $(if($sysPass){'✅'}else{'❌'})" -ForegroundColor $(if($sysPass){"Green"}else{"Red"})

# Test 2: Live tests
Write-Host "[2/7] Live tests..." -ForegroundColor Yellow
$live = .\scripts\ralph\test\ralph-live-test.ps1 2>&1
$livePass = ($live -match "ALL LIVE TESTS PASSED")
$results += @{ Name = "Live Tests (26)"; Pass = $livePass }
Write-Host "  $(if($livePass){'✅'}else{'❌'})" -ForegroundColor $(if($livePass){"Green"}else{"Red"})

# Test 3: Validation
Write-Host "[3/7] Full validation..." -ForegroundColor Yellow
$val = .\scripts\ralph\ralph-validate.ps1 2>&1
$valPass = ($val -match "ALL VALIDATION CHECKS PASSED")
$results += @{ Name = "Validation (56)"; Pass = $valPass }
Write-Host "  $(if($valPass){'✅'}else{'❌'})" -ForegroundColor $(if($valPass){"Green"}else{"Red"})

# Test 4: Master status
Write-Host "[4/7] Master status..." -ForegroundColor Yellow
$status = .\scripts\ralph\ralph-master.ps1 -Command status 2>&1
$statusPass = ($status -match "molecule-ralph-work.*OK")
$results += @{ Name = "Master Status"; Pass = $statusPass }
Write-Host "  $(if($statusPass){'✅'}else{'❌'})" -ForegroundColor $(if($statusPass){"Green"}else{"Red"})

# Test 5: Watchdog
Write-Host "[5/7] Watchdog..." -ForegroundColor Yellow
$wd = .\scripts\ralph\manage-watchdog.ps1 -Action status 2>&1
$wdPass = ($wd -match "Status:")
$results += @{ Name = "Watchdog"; Pass = $wdPass }
Write-Host "  $(if($wdPass){'✅'}else{'❌'})" -ForegroundColor $(if($wdPass){"Green"}else{"Red"})

# Test 6: Calculator
Write-Host "[6/7] Calculator demo..." -ForegroundColor Yellow
cd examples\ralph-demo
$calc = .\test.ps1 2>&1
cd ..\..
$calcPass = ($calc -match "5 passed, 0 failed")
$results += @{ Name = "Calculator (5)"; Pass = $calcPass }
Write-Host "  $(if($calcPass){'✅'}else{'❌'})" -ForegroundColor $(if($calcPass){"Green"}else{"Red"})

# Test 7: Task Manager
Write-Host "[7/7] Task Manager..." -ForegroundColor Yellow
cd examples\taskmanager-app
$tm = .\tests\Simple.Tests.ps1 2>&1
cd ..\..
$tmPass = ($tm -match "All tests passed")
$results += @{ Name = "Task Manager (12)"; Pass = $tmPass }
Write-Host "  $(if($tmPass){'✅'}else{'❌'})" -ForegroundColor $(if($tmPass){"Green"}else{"Red"})

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  VERIFICATION SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

foreach ($r in $results) {
    $icon = if ($r.Pass) { "✅" } else { "❌" }
    $color = if ($r.Pass) { "Green" } else { "Red" }
    Write-Host "$icon $($r.Name)" -ForegroundColor $color
}

$passed = ($results | Where-Object { $_.Pass }).Count
$total = $results.Count

Write-Host "`nTotal: $passed/$total passed" -ForegroundColor $(if ($passed -eq $total) { "Green" } else { "Yellow" })

if ($passed -eq $total) {
    Write-Host "`n🎉 SETUP COMPLETE - SYSTEM OPERATIONAL!" -ForegroundColor Green
} else {
    Write-Host "`n⚠️ Some tests failed - review output above" -ForegroundColor Yellow
}
```

---

## EXPECTED RESULTS

After running all sections:

| Check | Expected Result |
|-------|-----------------|
| Prerequisites | PowerShell 5.1+, Git installed |
| Repository Clone | Success, all files present |
| System Tests | 58/58 pass |
| Live Tests | 26/26 pass |
| Validation | 56/56 pass |
| Watchdog Status | Ready/Running |
| Calculator | 5/5 pass |
| Task Manager | 12/12 pass |
| **Final Verification** | **7/7 pass** |

---

## TROUBLESHOOTING

### Issue: "Execution of scripts is disabled"
**Fix:**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Issue: "Git is not recognized"
**Fix:** Install Git from https://git-scm.com/download/win

### Issue: "Tests fail with CLI errors"
**Note:** This is expected if Gastown CLI (`gt`) is not installed. The system gracefully degrades.

### Issue: "Watchdog install fails"
**Fix:** Run PowerShell as Administrator, or check Windows Task Scheduler permissions.

---

## POST-SETUP USAGE

After setup is complete, normal workflow:

```powershell
# Check system status
.\scripts\ralph\ralph-master.ps1 -Command status

# Check watchdog
.\scripts\ralph\manage-watchdog.ps1 -Action status

# Create a bead
.\scripts\ralph\ralph-master.ps1 -Command create-bead -Intent "Implement feature"

# Create a gate
.\scripts\ralph\ralph-master.ps1 -Command create-gate -GateType test

# Check gates
.\scripts\ralph\ralph-governor.ps1 -Action check

# Run validation
.\scripts\ralph\ralph-validate.ps1
```

---

## IMPORTANT NOTES

1. **PowerShell 5.1 Required:** All scripts are written for PowerShell 5.1 (Windows native)

2. **Graceful Degradation:** If optional tools (gt, bd, kimi) are missing, the system logs warnings but continues operating.

3. **Watchdog:** Runs as a Windows Scheduled Task every 5 minutes. It scans for stale work and nudges/restarts as needed.

4. **Bead Storage:** Beads and gates are stored as JSON files in `.ralph/beads/` and `.ralph/gates/`

5. **Documentation:** Full docs are in the `docs/` directory:
   - `docs/guides/QUICKSTART.md` - Quick start guide
   - `docs/reference/RALPH_INTEGRATION.md` - Architecture details
   - `AGENTS.md` - Agent reference

---

## REPORT BACK

After completing setup, report:
1. Final verification score (X/7 tests passed)
2. Watchdog status
3. Any errors encountered
4. Confirmation that the system is operational

---

**Setup Prompt Version:** 1.0.0  
**Repository:** https://github.com/nicklynch10/gastown-kimi.git  
**Last Updated:** 2026-02-03  
**Status:** Production Ready ✅
