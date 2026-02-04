# Ralph-Gastown Quickstart Guide

> **New User? Start here!** Get up and running in 5 minutes.

---

## ⚡ 5-Minute Quickstart

### Step 0: Install Prerequisites (First Time Only)

If you haven't installed the prerequisites yet, see **[SETUP.md](SETUP.md)** for complete instructions.

Quick check:
```powershell
# Verify tools are installed
git --version
go version
gt version
```

---

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
Passed: 60
Failed: 0
Skipped: 1

ALL TESTS PASSED
```

✅ **If tests pass:** System is operational. Continue to Step 2.  
❌ **If tests fail:** See [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

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
Passed:  26
Failed:  0

ALL LIVE TESTS PASSED
```

✅ **If tests pass:** System can execute real work. Continue to Step 3.

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
```

🎉 **Success!** You now have a working Ralph-Gastown system.

---

## 🎯 Common Tasks

### Create Your First Bead

```powershell
# Create a bead with DoD
.\scripts\ralph\ralph-master.ps1 -Command create-bead -Intent "Implement feature X"

# The bead ID is printed (e.g., gt-ralph-1234)
# View all beads
.\scripts\ralph\ralph-master.ps1 -Command status
```

### Run Quality Checks

```powershell
# Check gates
.\scripts\ralph\ralph-governor.ps1 -Action check

# Show convoy status
.\scripts\ralph\ralph-governor.ps1 -Action status
```

---

## 📁 Key Files and Locations

| Component | Location |
|-----------|----------|
| Main script | `scripts/ralph/ralph-master.ps1` |
| Executor | `scripts/ralph/ralph-executor.ps1` |
| Governor | `scripts/ralph/ralph-governor.ps1` |
| Watchdog | `scripts/ralph/ralph-watchdog.ps1` |
| Formulas | `.beads/formulas/molecule-ralph-*.toml` |
| Demo app | `examples/ralph-demo/` |

---

## 🧪 Testing Cheat Sheet

```powershell
# Full system validation
.\scripts\ralph\test\ralph-system-test.ps1 -TestType all

# Live operations test
.\scripts\ralph\test\ralph-live-test.ps1

# Demo app test
cd examples/ralph-demo
.\test.ps1
```

---

## 🚀 Next Steps

1. **[SETUP.md](SETUP.md)** - If you need to install prerequisites
2. **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - If you encounter issues
3. **[AGENTS.md](../../AGENTS.md)** - Complete guide for AI agents
4. **[RALPH_INTEGRATION.md](../reference/RALPH_INTEGRATION.md)** - Technical architecture

---

## 🆘 Quick Troubleshooting

### "Script won't run"

```powershell
# Check execution policy
Get-ExecutionPolicy

# Set policy (if needed)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### "Command not found"

```powershell
# Check prerequisites
.\scripts\ralph\ralph-prereq-check.ps1
```

### "Tests fail"

```powershell
# Run with verbose output
.\scripts\ralph\test\ralph-live-test.ps1 -Verbose

# Keep artifacts for inspection
.\scripts\ralph\test\ralph-live-test.ps1 -KeepTestArtifacts
```

---

**You're ready to go!** Start with the demo, then create your first bead.
