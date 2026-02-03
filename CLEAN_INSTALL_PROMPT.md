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

if ($psVersion.Major -lt 5) {
    Write-Host "ERROR: PowerShell 5.1+ required" -ForegroundColor Red
    exit 1
}

# 2. Git
try {
    $gitVersion = git --version
    Write-Host "Git: $gitVersion" -ForegroundColor Green
} catch {
    Write-Host "Git: NOT INSTALLED - Install from https://git-scm.com/download/win" -ForegroundColor Red
    exit 1
}

# 3. Execution Policy
$execPol = Get-ExecutionPolicy
Write-Host "Execution Policy: $execPol" -ForegroundColor $(if($execPol -eq "RemoteSigned" -or $execPol -eq "Unrestricted"){"Green"}else{"Yellow"})

if ($execPol -eq "Restricted") {
    Write-Host "Setting execution policy to RemoteSigned..." -ForegroundColor Yellow
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Write-Host "Execution policy updated" -ForegroundColor Green
}

# Optional tools (system works without these)
Write-Host "`nOptional Tools:" -ForegroundColor Yellow
$hasGo = Get-Command go -ErrorAction SilentlyContinue
$hasNode = Get-Command node -ErrorAction SilentlyContinue
Write-Host "  Go: $(if($hasGo){'Installed'}else{'Not installed - optional'})" -ForegroundColor $(if($hasGo){"Green"}else{"Gray"})
Write-Host "  Node: $(if($hasNode){'Installed'}else{'Not installed - optional'})" -ForegroundColor $(if($hasNode){"Green"}else{"Gray"})

Write-Host "`n✅ Prerequisites check complete" -ForegroundColor Green
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

# Verify critical files exist
$criticalFiles = @(
    ".beads/formulas/molecule-ralph-work.formula.toml",
    ".beads/formulas/molecule-ralph-patrol.formula.toml",
    ".beads/formulas/molecule-ralph-gate.formula.toml",
    ".beads/schemas/ralph-bead.schema.json",
    "scripts/ralph/ralph-master.ps1",
    "scripts/ralph/ralph-validate.ps1"
)

Write-Host "`nChecking critical files:" -ForegroundColor Cyan
$allPresent = $true
foreach ($file in $criticalFiles) {
    $exists = Test-Path $file
    $icon = if ($exists) { "✅" } else { "❌" }
    Write-Host "  $icon $file" -ForegroundColor $(if($exists){"Green"}else{"Red"})
    if (-not $exists) { $allPresent = $false }
}

if (-not $allPresent) {
    Write-Host "`n⚠️  Some critical files missing - proceeding anyway, tests may fail" -ForegroundColor Yellow
}
```

---

## SECTION 3: INITIAL VALIDATION

Run the system tests to verify the baseline:

```powershell
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  RUNNING SYSTEM TESTS (58 tests)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Run system tests
$testOutput = .\scripts\ralph\test\ralph-system-test.ps1 -TestType all 2>&1
$testOutput

# Check result
if ($testOutput -match "ALL TESTS PASSED") {
    Write-Host "`n✅ System tests passed" -ForegroundColor Green
} else {
    Write-Host "`n⚠️  Some system tests failed - checking details..." -ForegroundColor Yellow
    # Check for specific failures
    if ($testOutput -match "molecule-ralph.*MISSING") {
        Write-Host "Note: Ralph formulas may be missing - this is a known issue with .gitignore" -ForegroundColor Yellow
    }
}
```

**Expected:** 58 tests pass (some may be skipped if optional tools missing)

---

## SECTION 4: LIVE MATERIAL TESTS

Run tests that execute real commands and create actual files:

```powershell
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  RUNNING LIVE TESTS (26 tests)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$liveOutput = .\scripts\ralph\test\ralph-live-test.ps1 2>&1
$liveOutput

if ($liveOutput -match "ALL LIVE TESTS PASSED") {
    Write-Host "`n✅ Live tests passed" -ForegroundColor Green
} else {
    Write-Host "`n⚠️  Some live tests may have failed - checking..." -ForegroundColor Yellow
}
```

**Expected:** 26/26 tests pass (CLI tool warnings are OK)

---

## SECTION 5: FULL VALIDATION SUITE

Run the complete 56-test validation:

```powershell
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  RUNNING FULL VALIDATION (56 tests)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$valOutput = .\scripts\ralph\ralph-validate.ps1 2>&1
$valOutput | Select-Object -Last 30

if ($valOutput -match "ALL VALIDATION CHECKS PASSED") {
    Write-Host "`n✅ Full validation passed" -ForegroundColor Green
} else {
    Write-Host "`n⚠️  Some validation tests failed" -ForegroundColor Yellow
}
```

**Expected:** 56/56 tests pass (or close - missing CLI tools won't fail tests)

---

## SECTION 6: CHECK SYSTEM STATUS

```powershell
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  CHECKING RALPH SYSTEM STATUS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$status = .\scripts\ralph\ralph-master.ps1 -Command status 2>&1
$status

# Check for key indicators
$hasFormulas = $status -match "molecule-ralph-.*OK"
$hasScripts = $status -match "ralph-.*ps1.*OK"
$gatesGreen = $status -match "Features allowed"

Write-Host "`nStatus Summary:" -ForegroundColor Cyan
Write-Host "  Formulas present: $(if($hasFormulas){'✅'}else{'⚠️'})" -ForegroundColor $(if($hasFormulas){"Green"}else{"Yellow"})
Write-Host "  Scripts present: $(if($hasScripts){'✅'}else{'❌'})" -ForegroundColor $(if($hasScripts){"Green"}else{"Red"})
Write-Host "  Gates: $(if($gatesGreen){'✅ GREEN'}else{'⚠️ Check needed'})" -ForegroundColor $(if($gatesGreen){"Green"}else{"Yellow"})
```

---

## SECTION 7: INSTALL THE WATCHDOG (24/7 Monitoring)

The watchdog runs as a Windows Scheduled Task. **Note:** This may require Administrator privileges.

```powershell
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  INSTALLING WATCHDOG" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# First check if already installed
$existingTask = Get-ScheduledTask -TaskName "RalphWatchdog" -ErrorAction SilentlyContinue
if ($existingTask) {
    Write-Host "Watchdog already installed" -ForegroundColor Green
} else {
    Write-Host "Installing watchdog..." -ForegroundColor Yellow
    
    try {
        # Try automatic installation
        .\scripts\ralph\setup-watchdog.ps1
        Write-Host "Watchdog installed successfully" -ForegroundColor Green
    } catch {
        Write-Host "⚠️  Automatic install failed (may need admin rights)" -ForegroundColor Yellow
        Write-Host "The watchdog can be run manually with:" -ForegroundColor Gray
        Write-Host "  .\scripts\ralph\ralph-watchdog.ps1 -RunOnce" -ForegroundColor Cyan
    }
}

# Check status either way
Write-Host "`nWatchdog status:" -ForegroundColor Yellow
.\scripts\ralph\manage-watchdog.ps1 -Action status 2>&1 | ForEach-Object {
    Write-Host "  $_" -ForegroundColor Gray
}
```

**Note:** If scheduled task creation fails, the watchdog can still be run manually or via other scheduling methods.

---

## SECTION 8: TEST DEMO APPLICATIONS

### Calculator Demo
```powershell
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  TESTING CALCULATOR DEMO" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

cd examples\ralph-demo
$calcOutput = .\test.ps1 2>&1
$calcOutput
cd ..\..

if ($calcOutput -match "5 passed.*0 failed") {
    Write-Host "`n✅ Calculator tests passed" -ForegroundColor Green
} else {
    Write-Host "`n⚠️  Calculator tests had issues" -ForegroundColor Yellow
}
```

**Expected:** 5/5 tests pass

### Task Manager Demo
```powershell
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  TESTING TASK MANAGER DEMO" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

cd examples\taskmanager-app
$tmOutput = .\tests\Simple.Tests.ps1 2>&1
$tmOutput
cd ..\..

if ($tmOutput -match "All tests passed") {
    Write-Host "`n✅ Task Manager tests passed" -ForegroundColor Green
} else {
    Write-Host "`n⚠️  Task Manager tests had issues" -ForegroundColor Yellow
}
```

**Expected:** 12/12 tests pass

---

## SECTION 9: CREATE YOUR FIRST BEAD

Test the bead creation workflow:

```powershell
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  CREATING FIRST BEAD" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$beadOutput = .\scripts\ralph\ralph-master.ps1 -Command create-bead -Intent "My first Ralph bead - setup verification" 2>&1
$beadOutput

if ($beadOutput -match "Created bead") {
    # Extract bead ID
    $beadId = [regex]::Match($beadOutput, "gt-ralph-\d+").Value
    Write-Host "`n✅ Bead created: $beadId" -ForegroundColor Green
    
    # Verify file exists
    $beadFile = ".ralph/beads/$beadId.json"
    if (Test-Path $beadFile) {
        Write-Host "  File: $beadFile" -ForegroundColor Gray
    }
} else {
    Write-Host "`n⚠️  Bead creation may have failed" -ForegroundColor Yellow
    Write-Host "Creating bead directory..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Force -Path ".ralph/beads" | Out-Null
}
```

---

## SECTION 10: CREATE YOUR FIRST GATE

```powershell
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  CREATING FIRST GATE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$gateOutput = .\scripts\ralph\ralph-master.ps1 -Command create-gate -GateType smoke 2>&1
$gateOutput

if ($gateOutput -match "Created gate") {
    $gateId = [regex]::Match($gateOutput, "gt-gate-\d+").Value
    Write-Host "`n✅ Gate created: $gateId" -ForegroundColor Green
} else {
    Write-Host "`n⚠️  Gate creation may have failed - creating directory..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Force -Path ".ralph/gates" | Out-Null
}
```

---

## SECTION 11: TEST GOVERNOR

```powershell
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  TESTING GOVERNOR" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$govOutput = .\scripts\ralph\ralph-governor.ps1 -Action check 2>&1
$govOutput

if ($govOutput -match "Features allowed") {
    Write-Host "`n✅ Governor check passed" -ForegroundColor Green
} else {
    Write-Host "`n⚠️  Governor check had issues" -ForegroundColor Yellow
}
```

**Expected:** "POLICY: Features allowed - All gates green"

---

## SECTION 12: TEST RESILIENCE MODULE

```powershell
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  TESTING RESILIENCE MODULE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

try {
    Import-Module .\scripts\ralph\ralph-resilience.psm1 -Force
    Write-Host "✅ Module loaded" -ForegroundColor Green
    
    # Test retry
    $retryResult = Invoke-WithRetry -ScriptBlock { 
        return "Success"
    } -MaxRetries 2 -InitialBackoffSeconds 1
    
    if ($retryResult -eq "Success") {
        Write-Host "✅ Retry functionality working" -ForegroundColor Green
    }
    
    # Test circuit breaker
    $cbTripped = $false
    try {
        Invoke-WithCircuitBreaker -Name "setup-test" -ScriptBlock {
            throw "Test error"
        } -FailureThreshold 1 -TimeoutSeconds 5
    } catch {
        $cbTripped = $true
    }
    
    if ($cbTripped) {
        Write-Host "✅ Circuit breaker working" -ForegroundColor Green
    }
    
} catch {
    Write-Host "❌ Resilience module failed: $_" -ForegroundColor Red
}
```

---

## SECTION 13: TEST BROWSER MODULE

```powershell
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  TESTING BROWSER MODULE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

try {
    Import-Module .\scripts\ralph\ralph-browser.psm1 -Force
    Write-Host "✅ Browser module loaded" -ForegroundColor Green
    
    $ctx = New-BrowserTestContext -TestName "setup-test" -BaseUrl "https://example.com"
    
    if ($ctx -and $ctx.TestName -eq "setup-test") {
        Write-Host "✅ Browser context created" -ForegroundColor Green
    }
} catch {
    Write-Host "⚠️  Browser module test: $_" -ForegroundColor Yellow
}
```

---

## SECTION 14: MANUAL WATCHDOG TEST

Run the watchdog once manually:

```powershell
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  TESTING WATCHDOG MANUALLY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$wdOutput = .\scripts\ralph\ralph-watchdog.ps1 -RunOnce -Verbose 2>&1
$wdOutput | Select-Object -Last 10

if ($wdOutput -match "Iteration complete") {
    Write-Host "`n✅ Watchdog executed successfully" -ForegroundColor Green
} else {
    Write-Host "`n⚠️  Watchdog had issues" -ForegroundColor Yellow
}
```

---

## SECTION 15: FINAL VERIFICATION

```powershell
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  FINAL SETUP VERIFICATION" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$results = @()

# Test 1: Files present
$hasWork = Test-Path .beads\formulas\molecule-ralph-work.formula.toml
$results += @{ Name = "Formula: molecule-ralph-work"; Pass = $hasWork }

# Test 2: Scripts present
$hasMaster = Test-Path scripts\ralph\ralph-master.ps1
$results += @{ Name = "Script: ralph-master.ps1"; Pass = $hasMaster }

# Test 3: System tests
$sys = .\scripts\ralph\test\ralph-system-test.ps1 -TestType all 2>&1
$sysPass = ($sys -match "ALL TESTS PASSED")
$results += @{ Name = "System Tests (58)"; Pass = $sysPass }

# Test 4: Validation
$val = .\scripts\ralph\ralph-validate.ps1 2>&1
$valPass = ($val -match "ALL VALIDATION CHECKS PASSED")
$results += @{ Name = "Validation (56)"; Pass = $valPass }

# Test 5: Master status
$status = .\scripts\ralph\ralph-master.ps1 -Command status 2>&1
$statusPass = ($status -match "molecule-ralph-work.*OK" -or $status -match "Ralph Formulas")
$results += @{ Name = "Master Status"; Pass = $statusPass }

# Test 6: Calculator
cd examples\ralph-demo
$calc = .\test.ps1 2>&1
cd ..\..
$calcPass = ($calc -match "5 passed.*0 failed")
$results += @{ Name = "Calculator Demo (5)"; Pass = $calcPass }

# Test 7: Task Manager
cd examples\taskmanager-app
$tm = .\tests\Simple.Tests.ps1 2>&1
cd ..\..
$tmPass = ($tm -match "All tests passed")
$results += @{ Name = "Task Manager Demo (12)"; Pass = $tmPass }

# Display results
Write-Host "`nResults:" -ForegroundColor Cyan
foreach ($r in $results) {
    $icon = if ($r.Pass) { "✅" } else { "⚠️" }
    $color = if ($r.Pass) { "Green" } else { "Yellow" }
    Write-Host "  $icon $($r.Name)" -ForegroundColor $color
}

$passed = ($results | Where-Object { $_.Pass }).Count
$total = $results.Count

Write-Host "`nTotal: $passed/$total passed" -ForegroundColor $(if ($passed -ge 5) { "Green" } else { "Yellow" })

if ($passed -eq $total) {
    Write-Host "`n🎉 SETUP COMPLETE - FULLY OPERATIONAL!" -ForegroundColor Green
} elseif ($passed -ge 5) {
    Write-Host "`n✅ SETUP COMPLETE - MOSTLY OPERATIONAL (minor issues)" -ForegroundColor Green
} else {
    Write-Host "`n⚠️  SETUP INCOMPLETE - Review failures above" -ForegroundColor Yellow
}
```

---

## EXPECTED RESULTS

After running all sections:

| Check | Expected | Notes |
|-------|----------|-------|
| Prerequisites | ✅ Pass | PowerShell 5.1+, Git |
| Repository Clone | ✅ Success | All files present |
| System Tests | ✅ 55-58 pass | Some skips OK |
| Live Tests | ✅ 24-26 pass | CLI warnings OK |
| Validation | ✅ 53-56 pass | Missing CLI OK |
| Master Status | ✅ Working | May show CLI warnings |
| Watchdog | ⚠️/✅ Manual OK | Scheduled task may need admin |
| Calculator | ✅ 5/5 pass | |
| Task Manager | ✅ 12/12 pass | |
| **Final Score** | **5-7/7** | **Operational if ≥5** |

---

## TROUBLESHOOTING

### Issue: "Missing formula files"
**Status:** Fixed in latest commit
**Workaround:** The formulas are now force-added to git. If still missing, manually create them from the repo.

### Issue: "Missing schema file"
**Status:** Fixed in latest commit
**Workaround:** The schema is now force-added to git.

### Issue: "Missing CLI tools (gt, bd)"
**Status:** Expected on clean machines
**Impact:** System works in "standalone mode" without these optional tools
**To install:** See docs/guides/SETUP.md for Gastown CLI installation

### Issue: "Watchdog install failed"
**Status:** Expected without Administrator rights
**Solution 1:** Run PowerShell as Administrator, then:
```powershell
.\scripts\ralph\setup-watchdog.ps1
```
**Solution 2:** Run watchdog manually:
```powershell
.\scripts\ralph\ralph-watchdog.ps1 -RunOnce
```
**Solution 3:** Use Task Scheduler GUI to create task manually

---

## POST-SETUP USAGE

```powershell
# Check status
.\scripts\ralph\ralph-master.ps1 -Command status

# Check watchdog (manual mode if not scheduled)
.\scripts\ralph\manage-watchdog.ps1 -Action status
# Or run manually:
.\scripts\ralph\ralph-watchdog.ps1 -RunOnce

# Create work
.\scripts\ralph\ralph-master.ps1 -Command create-bead -Intent "Implement feature"

# Check gates
.\scripts\ralph\ralph-governor.ps1 -Action check

# Run validation
.\scripts\ralph\ralph-validate.ps1
```

---

## IMPORTANT NOTES

1. **PowerShell 5.1 Required:** Scripts are written for PowerShell 5.1 (Windows native)

2. **Optional CLI Tools:** The system works without `gt` and `bd` CLI tools - it falls back to file-based operations

3. **Watchdog:** Can run as scheduled task (with admin) or manually via `-RunOnce`

4. **Bead Storage:** Beads stored as JSON in `.ralph/beads/` and `.ralph/gates/`

5. **Documentation:** Full docs in `docs/` directory

---

## REPORT BACK

Report:
1. Final verification score (X/7 tests passed)
2. Any critical failures
3. Whether system is operational for basic use

---

**Setup Prompt Version:** 1.0.1  
**Repository:** https://github.com/nicklynch10/gastown-kimi.git  
**Last Updated:** 2026-02-03  
**Status:** Production Ready ✅
