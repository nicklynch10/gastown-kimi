# Ralph-Gastown 24/7 SDLC Setup Prompt

> **Copy and paste this entire prompt to a new AI agent to set up the Ralph-Gastown system on a clean project.**

---

## YOUR MISSION

Set up the Ralph-Gastown 24/7 SDLC system on a CLEAN project. This is a Windows-native AI agent orchestration system that provides:

- **Gastown** = Durable work tracking (Beads, hooks, convoys)
- **Ralph** = Retry-until-verified execution (DoD enforcement)
- **24/7 Watchdog** = Always-on monitoring and recovery

---

## CONTEXT

You are working with the gastown-kimi repository at:
`C:\Users\Nick Lynch\Desktop\Coding Projects\KimiGasTown`

The project contains:
- PowerShell-based Ralph scripts in `scripts/ralph/`
- Bead formulas in `.beads/formulas/`
- Demo applications in `examples/`
- Full documentation in `docs/`

---

## PREREQUISITES CHECK

Before starting, verify these are installed:

```powershell
# Check PowerShell version (MUST be 5.1+)
$PSVersionTable.PSVersion

# Check execution policy
Get-ExecutionPolicy
# Should be: RemoteSigned or Unrestricted
# If not: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Check Git
git --version

# Check optional tools (system works without these)
Get-Command gt -ErrorAction SilentlyContinue  # Gastown CLI
Get-Command bd -ErrorAction SilentlyContinue  # Beads CLI
Get-Command kimi -ErrorAction SilentlyContinue # Kimi CLI
Get-Command go -ErrorAction SilentlyContinue   # Go compiler
```

---

## SETUP STEPS (Execute in order)

### STEP 1: Navigate to Project Root

```powershell
cd "C:\Users\Nick Lynch\Desktop\Coding Projects\KimiGasTown"
```

### STEP 2: Run Initial Validation

```powershell
# Run system tests to verify baseline
.\scripts\ralph\test\ralph-system-test.ps1 -TestType all
```

**Expected:** 58 tests pass, 0 fail, 1 skip

If tests fail, STOP and investigate before proceeding.

---

### STEP 3: Run Live Tests (Real Operations)

```powershell
# This creates actual files and runs real commands
.\scripts\ralph\test\ralph-live-test.ps1
```

**Expected:** 26/26 tests pass

---

### STEP 4: Run Full Validation

```powershell
# Complete 56-test validation suite
.\scripts\ralph\ralph-validate.ps1
```

**Expected:** 56/56 tests pass

---

### STEP 5: Check Ralph System Status

```powershell
.\scripts\ralph\ralph-master.ps1 -Command status
```

You should see:
- Ralph Formulas: All OK
- Ralph Scripts: All OK
- Gate Status: Features allowed

---

### STEP 6: Set Up Watchdog (24/7 Monitoring)

```powershell
# Check if watchdog is already installed
.\scripts\ralph\manage-watchdog.ps1 -Action status

# If not installed, install it
.\scripts\ralph\setup-watchdog.ps1

# Verify installation
.\scripts\ralph\manage-watchdog.ps1 -Action status
```

**Expected:** Watchdog shows as "Ready" with next run time

---

### STEP 7: Test Demo Applications

#### Calculator Demo:
```powershell
cd examples\ralph-demo
.\test.ps1
cd ..\..
```

**Expected:** 5/5 tests pass

#### Task Manager Demo:
```powershell
cd examples\taskmanager-app
.\tests\Simple.Tests.ps1
cd ..\..
```

**Expected:** 12/12 tests pass

---

### STEP 8: Create Your First Real Bead

```powershell
# Create a bead with actual DoD verifiers
.\scripts\ralph\ralph-master.ps1 -Command create-bead -Intent "Test bead for validation"
```

This creates a JSON file in `.ralph/beads/`.

Verify it was created:
```powershell
Get-ChildItem .ralph\beads\*.json | Select-Object -First 5
```

---

### STEP 9: Create Your First Gate

```powershell
# Create a smoke test gate
.\scripts\ralph\ralph-master.ps1 -Command create-gate -GateType smoke

# Create a build gate
.\scripts\ralph\ralph-master.ps1 -Command create-gate -GateType build
```

Verify gates were created:
```powershell
Get-ChildItem .ralph\gates\*.json | Select-Object -First 5
```

---

### STEP 10: Run Governor Check

```powershell
.\scripts\ralph\ralph-governor.ps1 -Action check
```

**Expected:** "POLICY: Features allowed - All gates green"

---

### STEP 11: Test Ralph Executor

```powershell
# Get a demo bead ID
$beadId = (Get-ChildItem .ralph\beads\*.json | Select-Object -First 1).BaseName

# Run executor (dry run mode)
.\scripts\ralph\ralph-executor-simple.ps1 -BeadId $beadId -MaxIterations 1 -Verbose
```

---

### STEP 12: Test Resilience Module

```powershell
# Import module
Import-Module .\scripts\ralph\ralph-resilience.psm1 -Force

# Test retry functionality
$result = Invoke-WithRetry -ScriptBlock { 
    Write-Output "Success" 
} -MaxRetries 3 -InitialBackoffSeconds 1

Write-Host "Retry test result: $result"

# Test circuit breaker
$cbResult = Invoke-WithCircuitBreaker -Name "test-setup" -ScriptBlock {
    Write-Output "Circuit breaker test"
} -FailureThreshold 3 -TimeoutSeconds 30

Write-Host "Circuit breaker test completed"
```

---

### STEP 13: Test Browser Module

```powershell
# Import module
Import-Module .\scripts\ralph\ralph-browser.psm1 -Force

# Create test context
$ctx = New-BrowserTestContext -TestName "setup-test" -BaseUrl "https://example.com"

Write-Host "Browser context created:"
Write-Host "  Test Name: $($ctx.TestName)"
Write-Host "  Base URL: $($ctx.BaseUrl)"
Write-Host "  Start Time: $($ctx.StartTime)"
```

---

### STEP 14: Verify Watchdog is Running

```powershell
# Check Windows Scheduled Task
Get-ScheduledTask -TaskName "RalphWatchdog" -ErrorAction SilentlyContinue | 
    Select-Object TaskName, State, LastRunTime, NextRunTime

# Check with management script
.\scripts\ralph\manage-watchdog.ps1 -Action status
```

**Expected:** State = "Ready", LastResult = 0

---

### STEP 15: Run Manual Watchdog Test

```powershell
# Run one iteration manually to verify
.\scripts\ralph\ralph-watchdog.ps1 -RunOnce -Verbose
```

**Expected:** Scanning hooks, no errors, clean exit

---

## VERIFICATION CHECKLIST

After setup, verify:

- [ ] All 56 validation tests pass
- [ ] All 26 live tests pass
- [ ] Watchdog is installed and running
- [ ] Beads can be created
- [ ] Gates can be created
- [ ] Governor reports all gates green
- [ ] Demo Calculator tests pass (5/5)
- [ ] Demo Task Manager tests pass (12/12)
- [ ] Resilience module loads and works
- [ ] Browser module loads and works
- [ ] Ralph-master commands work (status, verify, create-bead, create-gate)

---

## COMMON ISSUES & FIXES

### Issue: "Script won't run"
**Fix:** Check execution policy
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Issue: "Tests fail with CLI errors"
**Fix:** This is expected if Gastown CLI (`gt`) is not installed. The system gracefully degrades.

### Issue: "Watchdog not found"
**Fix:** Run setup-watchdog.ps1 as Administrator if needed, or check Windows Task Scheduler permissions.

### Issue: "Module won't load"
**Fix:** Check PowerShell version is 5.1+
```powershell
$PSVersionTable.PSVersion
```

---

## POST-SETUP WORKFLOW

After setup is complete, the normal workflow is:

### Daily Operations:
```powershell
# Check status
.\scripts\ralph\ralph-master.ps1 -Command status

# Check watchdog
.\scripts\ralph\manage-watchdog.ps1 -Action status

# Run validation (weekly)
.\scripts\ralph\ralph-validate.ps1
```

### Creating Work:
```powershell
# Create a bead
.\scripts\ralph\ralph-master.ps1 -Command create-bead -Intent "Implement feature X"

# Create a gate
.\scripts\ralph\ralph-master.ps1 -Command create-gate -GateType test

# Check gates
.\scripts\ralph\ralph-governor.ps1 -Action check
```

---

## IMPORTANT NOTES

1. **PowerShell 5.1 Compatibility:** All scripts are written for PowerShell 5.1 (not 7.x). Some PS7-only operators (??, ?., ??=) are avoided.

2. **Error Handling:** The system uses graceful degradation. If optional tools (gt, bd, kimi) are missing, it logs warnings but continues.

3. **Watchdog:** The watchdog runs as a Windows Scheduled Task every 5 minutes. It scans for stale work and nudges/restarts as needed.

4. **Bead Storage:** Beads are stored as JSON files in `.ralph/beads/` and `.ralph/gates/`

5. **Documentation:** Full docs are in:
   - `AGENTS.md` - Agent guide
   - `docs/guides/QUICKSTART.md` - Quick start
   - `docs/reference/RALPH_INTEGRATION.md` - Architecture

---

## FILES YOU SHOULD KNOW

| File | Purpose |
|------|---------|
| `scripts/ralph/ralph-master.ps1` | Main control interface |
| `scripts/ralph/ralph-executor.ps1` | DoD enforcement executor |
| `scripts/ralph/ralph-governor.ps1` | Policy/gate enforcement |
| `scripts/ralph/ralph-watchdog.ps1` | 24/7 monitoring |
| `scripts/ralph/ralph-resilience.psm1` | Retry/circuit breaker |
| `scripts/ralph/ralph-browser.psm1` | Browser testing |
| `scripts/ralph/ralph-validate.ps1` | Full validation suite |
| `scripts/ralph/manage-watchdog.ps1` | Watchdog management |
| `.beads/formulas/*.formula.toml` | Bead formulas |
| `examples/ralph-demo/` | Calculator demo app |
| `examples/taskmanager-app/` | Task Manager demo app |

---

## FINAL VERIFICATION COMMAND

Run this to verify everything is working:

```powershell
Write-Host "=== FINAL SETUP VERIFICATION ===" -ForegroundColor Cyan

$results = @()

# Test 1: Validation
Write-Host "`n[1/6] Running validation..." -ForegroundColor Yellow
$val = .\scripts\ralph\ralph-validate.ps1 2>&1
$results += @{ Name = "Validation"; Pass = ($val -match "ALL VALIDATION CHECKS PASSED") }

# Test 2: Master status
Write-Host "[2/6] Checking master status..." -ForegroundColor Yellow
$status = .\scripts\ralph\ralph-master.ps1 -Command status 2>&1
$results += @{ Name = "Master Status"; Pass = ($status -match "molecule-ralph-work.*OK") }

# Test 3: Watchdog
Write-Host "[3/6] Checking watchdog..." -ForegroundColor Yellow
$wd = .\scripts\ralph\manage-watchdog.ps1 -Action status 2>&1
$results += @{ Name = "Watchdog"; Pass = ($wd -match "Status:") }

# Test 4: Calculator
Write-Host "[4/6] Testing Calculator..." -ForegroundColor Yellow
cd examples\ralph-demo
$calc = .\test.ps1 2>&1
cd ..\..
$results += @{ Name = "Calculator"; Pass = ($calc -match "5 passed, 0 failed") }

# Test 5: Task Manager
Write-Host "[5/6] Testing Task Manager..." -ForegroundColor Yellow
cd examples\taskmanager-app
$tm = .\tests\Simple.Tests.ps1 2>&1
cd ..\..
$results += @{ Name = "Task Manager"; Pass = ($tm -match "All tests passed") }

# Test 6: Bead creation
Write-Host "[6/6] Testing bead creation..." -ForegroundColor Yellow
$bead = .\scripts\ralph\ralph-master.ps1 -Command create-bead -Intent "Setup verification" 2>&1
$results += @{ Name = "Bead Creation"; Pass = ($bead -match "Created bead") }

# Summary
Write-Host "`n=== VERIFICATION RESULTS ===" -ForegroundColor Cyan
foreach ($r in $results) {
    $icon = if ($r.Pass) { "✅" } else { "❌" }
    $color = if ($r.Pass) { "Green" } else { "Red" }
    Write-Host "$icon $($r.Name)" -ForegroundColor $color
}

$passed = ($results | Where-Object { $_.Pass }).Count
$total = $results.Count
Write-Host "`nTotal: $passed/$total passed" -ForegroundColor $(if ($passed -eq $total) { "Green" } else { "Yellow" })
```

**Expected:** 6/6 tests pass

---

## REPORT BACK

After completing setup, report:
1. How many validation tests passed
2. Watchdog status
3. Any errors encountered
4. Confirmation that the system is operational

---

**Setup Prompt Version:** 1.0.0  
**Last Updated:** 2026-02-03  
**System:** Ralph-Gastown 24/7 SDLC
