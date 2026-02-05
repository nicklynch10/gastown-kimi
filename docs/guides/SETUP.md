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

## Windows-Specific Prerequisites

### SQLite3 (Required for `gt doctor`)

The Gastown CLI's `gt doctor` command checks for SQLite3. While not strictly required for Ralph operation, installing it prevents warnings:

**Option A: Using winget (recommended)**
```powershell
winget install SQLite.SQLite
```

**Option B: Manual download**
1. Download from https://sqlite.org/download.html
2. Download the **Precompiled Binaries for Windows** (sqlite-tools-win32-x86-*.zip)
3. Extract to `C:\sqlite` or add to PATH

**Verify installation:**
```powershell
sqlite3 --version
```

### About tmux Dependency

**Clarification:** Ralph-Gastown itself is **pure PowerShell** and does NOT require tmux. However:

- `gt mayor` commands (session management, daemon) use tmux
- Ralph executor and core workflows work **without tmux**
- If you need `gt mayor` features, install tmux:
  ```powershell
  winget install tmux
  # Or use MSYS2: pacman -S tmux
  ```

**For Ralph-only workflows:** No tmux needed. Ralph works entirely in PowerShell.

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

### 4. Build Gastown CLI (gt)

The Gastown CLI provides work orchestration capabilities. Since this is a development setup, build from source:

**Option A: Using the Windows build script (recommended)**
```powershell
# From the project root
.\scripts\build-gt-windows.ps1

# Or specify custom output path
.\scripts\build-gt-windows.ps1 -OutputPath C:\Tools\gt.exe
```

**Option B: Manual build**
```powershell
# Build with version info
$VERSION = git describe --tags --always --dirty
$COMMIT = git rev-parse --short HEAD
$BUILD_TIME = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
$LDFLAGS = "-X github.com/steveyegge/gastown/internal/cmd.Version=$VERSION -X github.com/steveyegge/gastown/internal/cmd.Commit=$COMMIT -X github.com/steveyegge/gastown/internal/cmd.BuildTime=$BUILD_TIME -X github.com/steveyegge/gastown/internal/cmd.BuiltProperly=1"
go build -ldflags "$LDFLAGS" -o gt.exe ./cmd/gt
```

**Verify installation:**
```powershell
.\gt.exe version
# Should show: gt version vX.X.X (dev: main@XXXXXXX)
# NOT: "ERROR: This binary was built with 'go build' directly"
```

**Note:** If the version shows an error, the binary was built without proper version flags. Use the build script above.

#### gt init vs gt install Clarification

**`gt init`** - Creates a basic workspace structure (mayors/, crews/, etc.)  
**`gt install`** - Full setup including formulas, schemas, and town configuration

**For Ralph-Gastown:** The Ralph setup scripts handle the full initialization. You typically don't need to run `gt init` or `gt install` manually - the Ralph master script sets up what's needed.

```powershell
# After building gt.exe, just run Ralph initialization
# This handles all necessary Gastown setup
.\scripts\ralph\ralph-master.ps1 -Command init
```

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
1. Visit https://platform.moonshot.ai/
2. Sign up and generate an API key
3. Configure Kimi: `kimi configure`

**Create Config File (Alternative):**

If `kimi configure` doesn't work, create the config file manually:

```powershell
# Create the config directory
$configDir = "$env:USERPROFILE\.kimi"
if (-not (Test-Path $configDir)) { 
    New-Item -ItemType Directory -Path $configDir -Force 
}

# Create config.toml with your API key
$config = @"
# Kimi CLI Configuration
default_model = "kimi-k2.5"

# REQUIRED: Your API key from platform.moonshot.ai
api_key = "YOUR_API_KEY_HERE"

# REQUIRED: API endpoint
api_endpoint = "https://api.moonshot.ai/v1"

# Provider configuration
[providers.moonshot]
# ⚠️ CRITICAL: type must be "kimi" (not "moonshot") - this is the provider implementation type
type = "kimi"
base_url = "https://api.moonshot.ai/v1"
api_key = "YOUR_API_KEY_HERE"

# Model configuration
# ⚠️ CRITICAL: Quotes REQUIRED because kimi-k2.5 contains a dot
# Without quotes, TOML parses this as [models.kimi-k2][5] which is WRONG
[models."kimi-k2.5"]
provider = "moonshot"
model = "kimi-k2.5"
max_context_size = 262144
"@

# Write without BOM (PowerShell 5.1 Out-File writes UTF-8-BOM which breaks TOML parsing)
[System.IO.File]::WriteAllText("$configDir\config.toml", $config, [System.Text.UTF8Encoding]::new($false))
Write-Host "Config created at: $configDir\config.toml" -ForegroundColor Green
Write-Host "Edit the file and replace YOUR_API_KEY_HERE with your actual API key from platform.moonshot.ai" -ForegroundColor Yellow
```

**⚠️ CRITICAL - TOML Syntax for Model Names:**

The model name `kimi-k2.5` contains a dot (`.`), so it **MUST be quoted** in TOML:

| Syntax | Result | Status |
|--------|--------|--------|
| `[models."kimi-k2.5"]` | Correctly creates table for `kimi-k2.5` | ✅ CORRECT |
| `[models.kimi-k2.5]` | TOML parses as `models.kimi-k2` + key `5` | ❌ WRONG |

**Why this matters:** TOML interprets unquoted dots as table separators. Without quotes, the parser creates a nested table `kimi-k2` with a numeric key `5`, causing authentication/model errors.

**Verify your config:**
```powershell
# Test Kimi is working
kimi --yolo --prompt "Hello"

# If you get authentication errors, check:
# 1. API key is correct from platform.moonshot.ai (not www.kimi.com)
# 2. Model name is quoted in [models."kimi-k2.5"]
# 3. api_endpoint is https://api.moonshot.ai/v1
```

**Having Kimi auth issues?** See [TROUBLESHOOTING.md](TROUBLESHOOTING.md#kimi-cli-configuration-issues) for detailed help.

---

### 7. Optional: Beads CLI (bd)

**IMPORTANT:** Ralph works in **standalone mode** without the `bd` CLI. In standalone mode:
- Beads are stored as JSON files in `.ralph/beads/*.json`
- The `gt` CLI is still required for core functionality
- Formulas are loaded from `.beads/formulas/*.formula.toml`

**You only need `bd` CLI if:**
- You want to use the Beads database backend instead of JSON files
- You need advanced bead querying capabilities

**To install (optional):**
```powershell
go install github.com/nicklynch10/beads-cli/cmd/bd@latest
```

**Ralph will automatically:**
- Use `bd` CLI if available
- Fall back to JSON file mode if `bd` is not installed
- Work seamlessly in either mode

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
