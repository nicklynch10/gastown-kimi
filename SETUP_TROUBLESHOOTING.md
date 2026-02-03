# Setup Troubleshooting Guide

> **Quick fixes for common setup issues**

---

## Issues Fixed in Latest Update

### 1. Missing Formula Files ✅ FIXED

**Problem:** `molecule-ralph-work`, `molecule-ralph-patrol`, `molecule-ralph-gate` not found

**Root Cause:** The `.beads/` directory was gitignored, so formulas weren't being committed.

**Fix Applied:** Force-added the Ralph-specific formulas to the repository.

**Commit:** `b9600e08` - "fix: Add Ralph formula files and schema to repository"

---

### 2. Missing Schema File ✅ FIXED

**Problem:** `ralph-bead.schema.json` not found

**Root Cause:** Same .gitignore issue as above.

**Fix Applied:** Force-added the schema file to the repository.

---

### 3. Missing CLI Tools (gt, bd) ⚠️ EXPECTED

**Problem:** Gastown CLI (`gt`) and Beads CLI (`bd`) not installed

**Status:** This is **expected** on clean machines and is **not an error**.

**Impact:** System works in "standalone mode" without these tools:
- Beads are created as JSON files directly
- Gates are created as JSON files directly
- All core functionality works

**To Install (Optional):**
```powershell
# Install Go first: https://go.dev/dl/

# Then install Gastown CLI
go install github.com/nicklynch10/gastown-cli/cmd/gt@latest

# Install Beads CLI
go install github.com/nicklynch10/beads-cli/cmd/bd@latest
```

---

### 4. Watchdog Install Failed ⚠️ EXPECTED WITHOUT ADMIN

**Problem:** Scheduled task creation failed

**Status:** This is **expected** without Administrator privileges.

**Solutions:**

#### Option A: Run as Administrator (Recommended for 24/7)
```powershell
# Right-click PowerShell → "Run as Administrator"
# Then:
cd gastown-kimi
.\scripts\ralph\setup-watchdog.ps1
```

#### Option B: Run Manually (No admin needed)
```powershell
# Run once
.\scripts\ralph\ralph-watchdog.ps1 -RunOnce

# Or run continuously (in a dedicated window)
while ($true) {
    .\scripts\ralph\ralph-watchdog.ps1 -RunOnce
    Start-Sleep -Seconds 300  # 5 minutes
}
```

#### Option C: Use Windows Task Scheduler GUI
1. Open Task Scheduler
2. Create Basic Task
3. Name: "RalphWatchdog"
4. Trigger: Every 5 minutes
5. Action: Start PowerShell
6. Arguments: `-ExecutionPolicy Bypass -File "C:\path\to\gastown-kimi\scripts\ralph\ralph-watchdog.ps1"`

---

## Quick Verification After Fixes

Run this to verify everything is working:

```powershell
cd gastown-kimi

# Pull latest changes (if you cloned before fixes)
git pull origin main

# Check critical files exist
Test-Path .beads\formulas\molecule-ralph-work.formula.toml
Test-Path .beads\schemas\ralph-bead.schema.json

# Run validation
.\scripts\ralph\ralph-validate.ps1
```

---

## What "Operational" Means

The system is **operational** if:
- ✅ Validation tests pass (53-56/56)
- ✅ Demo applications work (Calculator 5/5, Task Manager 12/12)
- ✅ Can create beads and gates
- ✅ Governor reports status
- ✅ Watchdog can run (even if just manually)

The system does **NOT** require:
- Gastown CLI (`gt`)
- Beads CLI (`bd`)
- Scheduled task (manual watchdog works)
- Administrator rights (for basic operation)

---

## For Fresh Installs

Use the updated prompt which handles these issues gracefully:

**File:** `CLEAN_INSTALL_PROMPT.md` (updated in commit `28e680fb`)

**Or download directly:**
https://github.com/nicklynch10/gastown-kimi/blob/main/CLEAN_INSTALL_PROMPT.md

---

## Still Having Issues?

Check:
1. PowerShell version: `$PSVersionTable.PSVersion` (need 5.1+)
2. Execution policy: `Get-ExecutionPolicy` (need RemoteSigned)
3. Git is installed: `git --version`
4. Repository is up to date: `git pull origin main`

---

**Last Updated:** 2026-02-03  
**Repository:** https://github.com/nicklynch10/gastown-kimi
