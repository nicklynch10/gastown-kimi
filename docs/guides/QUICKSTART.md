# Ralph-Gastown Quickstart Guide

> **New Agent? Start here!** Get up and running in 5 minutes.

## ⚡ 5-Minute Quickstart

### Step 1: Validate System (1 minute)

```powershell
# Open PowerShell in project root
# Run the system test suite
.\scripts\ralph\test\ralph-system-test.ps1 -TestType all
```

**Expected output:**
```
========================================
TEST SUMMARY
========================================
Duration: 0.98s
Passed: 58
Failed: 0
Skipped: 1

ALL TESTS PASSED
```

✅ **If 42 tests pass:** System is operational. Continue to Step 2.  
❌ **If tests fail:** Check `AGENTS.md` troubleshooting section.

---

### Step 2: Run Live Test (1 minute)

```powershell
# This runs REAL operations (creates files, executes commands)
.\scripts\ralph\test\ralph-live-test.ps1
```

**Expected output:**
```
========================================
LIVE TEST SUMMARY
========================================
Duration: 2.5 seconds
Passed:  16+
Failed:  0-4 (may have some skips if optional tools missing)

ALL LIVE TESTS PASSED
```

✅ **If core tests pass:** System can execute real work. Continue to Step 3.

---

### Step 3: Test Demo Application (1 minute)

```powershell
cd examples/ralph-demo
.\test.ps1
```

**Expected output:**
```
Running Calculator Tests...

[PASS] Add 2 + 3 = 5
[PASS] Subtract 5 - 3 = 2
[PASS] Multiply 4 * 5 = 20
[PASS] Divide 10 / 2 = 5
[PASS] Divide by zero throws error

Results: 5 passed, 0 failed
```

✅ **All 5 tests pass:** You're ready to use Ralph!

---

### Step 4: Try Ralph Commands (2 minutes)

```powershell
# Go back to project root
cd ..

# Check Ralph system status
.\scripts\ralph\ralph-master.ps1 -Command status

# View help
.\scripts\ralph\ralph-master.ps1 -Command help

# Run validation
.\scripts\ralph\ralph-validate.ps1
```

🎉 **Success!** You now have a working Ralph-Gastown system.

---

## 🎯 Common Tasks

### Create Your First Bead

```powershell
# Create a bead with DoD
.\scripts\ralph\ralph-master.ps1 -Command create-bead -Intent "Implement feature X"

# The bead ID is printed (e.g., gt-abc123)
# View the bead
.\scripts\ralph\ralph-master.ps1 -Command status
```

### Setup a New Project

```powershell
# One-command setup for a Go project
.\scripts\ralph\ralph-setup.ps1 -ProjectName "myapp" -ProjectType go

# With browser testing
.\scripts\ralph\ralph-setup.ps1 -ProjectName "webapp" -ProjectType node -WithBrowserTests

# See what was created
Get-ChildItem .ralph/
```

### Run Quality Checks

```powershell
# Check gates
.\scripts\ralph\ralph-governor.ps1 -Action check

# Show convoy status
.\scripts\ralph\ralph-governor.ps1 -Action status
```

---

## 📁 Project Structure Quick Reference

```
gastown-kimi/
├── scripts/ralph/              ⭐ RALPH SCRIPTS
│   ├── ralph-master.ps1       Main control
│   ├── ralph-executor.ps1     Bead executor
│   ├── ralph-governor.ps1     Policy enforcement
│   ├── ralph-watchdog.ps1     Monitoring
│   ├── ralph-setup.ps1        Project setup
│   ├── ralph-browser.psm1     Browser testing
│   ├── ralph-resilience.psm1  Error handling
│   └── test/
│       ├── ralph-system-test.ps1
│       └── ralph-live-test.ps1
│
├── examples/ralph-demo/        Demo app
│   ├── Calculator.psm1
│   └── test.ps1
│
├── .beads/formulas/            Bead formulas
│   ├── molecule-ralph-work.formula.toml
│   ├── molecule-ralph-patrol.formula.toml
│   └── molecule-ralph-gate.formula.toml
│
└── AGENTS.md                   Full agent guide
```

---

## 🧪 Testing Cheat Sheet

```powershell
# Full system validation
.\scripts\ralph\test\ralph-system-test.ps1 -TestType all

# Live operations test
.\scripts\ralph\test\ralph-live-test.ps1

# End-to-end validation
.\scripts\ralph\ralph-validate.ps1 -Detailed

# Demo app test
cd examples/ralph-demo
.\test.ps1
```

---

## 🚀 Next Steps

### 1. Read the Architecture

See `RALPH_INTEGRATION.md` for detailed architecture and design principles.

### 2. Understand Bead Contracts

Beads define work with Definition of Done:

```json
{
  "intent": "What needs to be done",
  "dod": {
    "verifiers": [
      {
        "name": "Build succeeds",
        "command": "go build ./...",
        "expect": {"exit_code": 0}
      }
    ]
  }
}
```

### 3. Try Browser Testing

```powershell
Import-Module .\scripts\ralph\ralph-browser.psm1

$ctx = New-BrowserTestContext -TestName "smoke" -BaseUrl "http://localhost:3000"
$result = Test-PagePerformance -Context $ctx -Path "/"
```

### 4. Read Full Agent Guide

See `AGENTS.md` for complete documentation.

---

## 🆘 Troubleshooting

### "Script won't run"

```powershell
# Check execution policy
Get-ExecutionPolicy

# Set policy (if needed)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### "Tests fail"

```powershell
# Run with verbose output
.\scripts\ralph\test\ralph-live-test.ps1 -Verbose

# Keep artifacts for inspection
.\scripts\ralph\test\ralph-live-test.ps1 -KeepTestArtifacts

# Check artifacts
Get-ChildItem .ralph/live-test-*
```

### "Command not found"

These are optional dependencies - scripts work without them:
- `gt` - Gastown CLI
- `bd` - Beads CLI
- `kimi` - Kimi Code CLI
- `go` - Go compiler

Core Ralph scripts are standalone PowerShell.

---

## 💡 Pro Tips

1. **Always run tests first** - Validate system before making changes
2. **Use `-Verbose`** - Get detailed output for debugging
3. **Check `AGENTS.md`** - Full reference guide
4. **Test on demo first** - `examples/ralph-demo` is your sandbox

---

## 📞 Getting Help

1. **Check documentation:**
   - `AGENTS.md` - Complete agent guide
   - `RALPH_INTEGRATION.md` - Architecture details
   - `README.md` - User documentation

2. **Run diagnostics:**
   ```powershell
   .\scripts\ralph\ralph-validate.ps1 -Detailed
   ```

3. **Check system state:**
   ```powershell
   .\scripts\ralph\ralph-master.ps1 -Command status
   ```

---

**You're ready to go!** Start with the demo, then create your first bead.
