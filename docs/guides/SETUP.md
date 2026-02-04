# Ralph-Gastown Setup Guide

> **Complete setup instructions for new users and AI agents.**

This guide covers everything you need to install before using Ralph-Gastown.

**Having trouble?** See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for solutions to common installation issues.

---

## Prerequisites Overview

| Component | Required | Purpose | Install Time |
|-----------|----------|---------|--------------|
| Windows 10/11 | Yes | Operating System | - |
| PowerShell 5.1+ | Yes | Script execution | Pre-installed |
| Git for Windows | Yes | Version control | 2 min |
| Go 1.21+ | Yes | Build Gastown CLI | 3 min |
| Gastown CLI (gt) | Yes | Work orchestration | 1 min |
| Kimi CLI | Recommended | AI implementation | 2 min |

**Total setup time: ~10 minutes**

---

## Step-by-Step Installation

### 1. Verify Windows & PowerShell

```powershell
# Check Windows version
winver

# Check PowerShell version
$PSVersionTable.PSVersion
# Should show 5.1 or higher
```

**If PowerShell is older than 5.1:** Update Windows or install PowerShell 7 from https://github.com/PowerShell/PowerShell/releases

---

### 2. Install Git for Windows

**Option A: Using winget (Windows 10/11)**
```powershell
winget install Git.Git
```

**Option B: Manual download**
1. Go to https://git-scm.com/download/win
2. Download and run the installer
3. Use default settings

**Verify installation:**
```powershell
git --version
# Should show something like: git version 2.42.0
```

---

### 3. Install Go

**Option A: Using winget**
```powershell
winget install GoLang.Go
```

**Option B: Manual download**
1. Go to https://go.dev/dl/
2. Download Windows installer (go1.21.x.windows-amd64.msi or later)
3. Run installer with default settings

**Verify installation:**
```powershell
go version
# Should show something like: go version go1.21.5 windows/amd64
```

**Important:** Close and reopen PowerShell after installing Go to refresh PATH.

---

### 4. Install Gastown CLI (gt)

The Gastown CLI provides work orchestration capabilities.

```powershell
# Install using go install
go install github.com/nicklynch10/gastown-cli/cmd/gt@latest
```

**Verify installation:**
```powershell
gt version
# Should show version information
```

**Note:** The `gt` binary will be installed to `%USERPROFILE%\go\bin\gt.exe`. Make sure this directory is in your PATH, or move the binary to a directory that is.

---

### 5. Configure PowerShell Execution Policy

PowerShell scripts need permission to run:

```powershell
# Check current policy
Get-ExecutionPolicy

# Set policy to allow signed scripts (recommended)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Or for this session only
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
```

---

### 6. Install Kimi CLI (Recommended)

Kimi CLI enables AI-powered code implementation.

**Prerequisites:**
- Python 3.8 or higher: https://www.python.org/downloads/

**Installation:**
```powershell
# Install using pip
pip install kimi-cli

# Or if you have multiple Python versions
pip3 install kimi-cli
```

**Verify installation:**
```powershell
kimi --version
```

**Get API Key:**
1. Visit https://www.kimi.com/code
2. Sign up and get an API key
3. Configure Kimi: `kimi configure`

---

## Quick Verification

After installing all prerequisites, run the system test:

```powershell
# Clone the repository (if not already)
git clone https://github.com/nicklynch10/gastown-kimi.git
cd gastown-kimi

# Run system tests
.\scripts\ralph\test\ralph-system-test.ps1 -TestType all
```

**Expected output:**
```
========================================
TEST SUMMARY
========================================
Duration: ~1s
Passed: 60
Failed: 0
Skipped: 1

ALL TESTS PASSED
```

---

## Optional: Verify All Tools

Run the prerequisite checker to see what's installed:

```powershell
.\scripts\ralph\ralph-prereq-check.ps1 -Verbose
```

This will show:
- ✓ PowerShell version
- ✓ Git installation
- ✓ Go installation
- ✓ Gastown CLI
- ✓ Kimi CLI (optional)

---

## Troubleshooting Installation

### "go: command not found"

**Problem:** Go not in PATH after installation.

**Solution:**
```powershell
# Add to PATH for current session
$env:PATH += ";$env:USERPROFILE\go\bin"

# Add permanently (requires admin)
[Environment]::SetEnvironmentVariable("PATH", $env:PATH + ";$env:USERPROFILE\go\bin", "User")
```

### "gt: command not found"

**Problem:** Go bin directory not in PATH.

**Solution:** Same as above, or move `gt.exe` to a directory already in PATH:
```powershell
# Copy to Windows directory (requires admin)
Copy-Item "$env:USERPROFILE\go\bin\gt.exe" "C:\Windows\gt.exe"
```

### "Scripts won't run"

**Problem:** Execution policy blocking scripts.

**Solution:**
```powershell
# Check current policy
Get-ExecutionPolicy

# Set less restrictive policy
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### "Cannot install Kimi"

**Problem:** pip not available or Python not installed.

**Solution:**
1. Install Python from https://www.python.org/downloads/
2. Ensure "Add Python to PATH" is checked during installation
3. Close and reopen PowerShell
4. Try: `python -m pip install kimi-cli`

---

## Next Steps

Once all prerequisites are installed:

1. **[Quick Start Guide](QUICKSTART.md)** - Get up and running in 5 minutes
2. **[README](../../README.md)** - Overview and basic usage
3. **[AGENTS.md](../../AGENTS.md)** - Complete guide for AI agents

---

## Uninstalling

If you need to remove the tools:

```powershell
# Remove Gastown CLI
Remove-Item "$env:USERPROFILE\go\bin\gt.exe"

# Remove Kimi CLI
pip uninstall kimi-cli

# Uninstall Go (via Windows Add/Remove Programs)
# Uninstall Git (via Windows Add/Remove Programs)
```

---

**Last Updated:** 2026-02-04
