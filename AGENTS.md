# Agent Instructions for Gastown-Kimi

> **For AI Agents:** This file contains setup and development information for working with this codebase.

## First Time Setup

**New to this project?** Start here:
1. **[SETUP.md](docs/guides/SETUP.md)** - Install prerequisites (Git, Go, etc.)
2. **[QUICKSTART.md](docs/guides/QUICKSTART.md)** - Get running in 5 minutes

## Quick Setup (5 Minutes)

### 1. Build Gastown CLI

```powershell
# Build gt.exe with proper version info (Windows)
.\scripts\build-gt-windows.ps1

# Verify the build
.\gt.exe version
# Should show: gt version vX.X.X (dev: main@XXXXXXX)
```

### 2. Validate System Works

```powershell
# Run comprehensive test suite
.\scripts\ralph\test\ralph-system-test.ps1 -TestType all

# Expected: 60+ tests pass, 0 fail
```

### 3. Run Live Tests

```powershell
# Tests actual operations (creates files, runs commands)
.\scripts\ralph\test\ralph-live-test.ps1

# Expected: 26+ tests pass
```

### 4. You're Ready!

If all tests pass, the system is operational.

---

## Project Overview

This is **Gastown** with full **Ralph-Gastown integration** - a Windows-native AI agent orchestration system.

**Core Philosophy:**
- **Gastown** = Durable work tracking (Beads, hooks, convoys)
- **Ralph** = Retry-until-verified execution (DoD enforcement)
- **Kimi** = AI implementation (Kimi Code CLI)

**The Rule:** Test failures stop progress. No green, no features.

---

## Critical Configuration Notes

### Kimi CLI Configuration (Windows)

When creating the Kimi config file on Windows, use **BOM-free UTF-8 encoding**:

```powershell
# CORRECT - No BOM (required for TOML parsing)
[System.IO.File]::WriteAllText("$configDir\config.toml", $config, [System.Text.UTF8Encoding]::new($false))

# WRONG - PowerShell 5.1 Out-File writes UTF-8-BOM which breaks TOML parsing
$config | Out-File -FilePath "$configDir\config.toml" -Encoding utf8
```

**Provider type must be "kimi" (not "moonshot"):**
```toml
[providers.moonshot]
type = "kimi"  # NOT "moonshot" - this is the provider implementation type
base_url = "https://api.moonshot.ai/v1"
api_key = "YOUR_API_KEY"
```

### Standalone Mode (No bd CLI Required)

Ralph works **without** the `bd` (Beads) CLI:
- Beads stored as JSON files in `.ralph/beads/*.json`
- Automatic fallback when `bd` is not installed
- Full Ralph functionality available in standalone mode

**You only need `bd` if:**
- You want database backend instead of JSON files
- You need advanced bead querying

---

## PowerShell 5.1 Compatibility

**CRITICAL:** All scripts must be compatible with PowerShell 5.1 (Windows built-in).

### Common Issues and Fixes

#### 1. Join-Path Multiple Arguments

PowerShell 5.1 does NOT support multiple arguments to Join-Path:

```powershell
# WRONG (PowerShell 7+ only):
Join-Path $root "subdir" "file.txt"

# CORRECT (PowerShell 5.1):
Join-Path (Join-Path $root "subdir") "file.txt"
```

#### 2. Split-Path -LeafBase

PowerShell 5.1 does NOT have `-LeafBase`:

```powershell
# WRONG:
Split-Path $path -LeafBase

# CORRECT:
[System.IO.Path]::GetFileNameWithoutExtension($path)
```

#### 3. && Command Chaining

PowerShell 5.1 does NOT support `&&`:

```powershell
# WRONG:
cd test-app && python -c "..."

# CORRECT:
Set-Location test-app; python -c "..."
```

#### 4. Kimi CLI Invocation

Kimi CLI requires `--print` with piped stdin:

```powershell
# WRONG:
kimi --yolo -p $promptContent

# CORRECT:
$promptContent | Out-File $tempFile -Encoding utf8
Start-Process -FilePath "kimi" -ArgumentList @("--yolo", "--print") -RedirectStandardInput $tempFile -Wait -PassThru -NoNewWindow
```

---

## Windows-Specific Notes

### About tmux

**Ralph-Gastown is pure PowerShell** and does NOT require tmux. Only `gt mayor` commands (session management) use tmux.

**For Ralph-only workflows:** No tmux needed.

### SQLite3 (Optional)

SQLite3 is used by `gt doctor` for diagnostics. Core Ralph functionality works without it.

Install if desired:
```powershell
winget install SQLite.SQLite
```

### gt.exe Detection

On Windows, scripts automatically look for `gt.exe` (not just `gt`). Ensure your `gt.exe` is in PATH or current directory.

---

## Working with Ralph Scripts

### Key Commands

```powershell
# Master control
.\scripts\ralph\ralph-master.ps1 -Command <command>

# Available commands:
#   init [-Rig <rig>]           Initialize Ralph in current town
#   status                      Show Ralph-Gastown status
#   run -Bead <id>              Run Ralph executor on a bead
#   patrol [-Rig <rig>]         Start patrol molecule
#   govern [-Convoy <id>]       Check/apply governor policies
#   watchdog                    Start watchdog monitor
#   verify                      Verify integration health
#   create-bead -Intent <text>  Create a new Ralph bead
#   create-gate -Type <type>    Create a gate bead
#   help                        Show help
```

### Watchdog Management

```powershell
# Check status
.\scripts\ralph\manage-watchdog.ps1 -Action status

# Start/stop/restart
.\scripts\ralph\manage-watchdog.ps1 -Action stop
.\scripts\ralph\manage-watchdog.ps1 -Action start
.\scripts\ralph\manage-watchdog.ps1 -Action restart
```

---

## Ralph Bead Contract

### Structure

```json
{
  "id": "gt-feature-001",
  "title": "Implement feature",
  "intent": "Behavior-level change description",
  "dod": {
    "verifiers": [
      {
        "name": "Build succeeds",
        "command": "go build ./...",
        "expect": {"exit_code": 0},
        "timeout_seconds": 60
      }
    ],
    "evidence_required": true
  },
  "constraints": {
    "max_iterations": 10,
    "time_budget_minutes": 60
  },
  "lane": "feature",
  "priority": 2,
  "ralph_meta": {
    "attempt_count": 0,
    "retry_backoff_seconds": 30
  }
}
```

### Required Fields

- `intent` - What needs to be done
- `dod.verifiers` - List of verification commands

### Verifier Structure

- `name` - Human-readable name
- `command` - PowerShell command to execute
- `expect.exit_code` - Expected exit code (default: 0)
- `expect.stdout_contains` - Optional string to check
- `timeout_seconds` - Timeout (default: 300)

---

## Development Guidelines

### PowerShell Script Structure

```powershell
#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Brief description
.DESCRIPTION
    Detailed description
.PARAMETER Name
    Parameter description
.EXAMPLE
    .\script.ps1 -Name value
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Name
)

# Error handling
$ErrorActionPreference = "Stop"

# Your code here
```

### PowerShell 5.1 Compatibility

**AVOID these PS7-only features:**
- `??` null coalescing operator
- `?.` null conditional member access
- `??=` null coalescing assignment

**Use instead:**
```powershell
# Instead of: $timeout = $verifier.timeout ?? 300
$timeout = if ($verifier.timeout) { $verifier.timeout } else { 300 }

# Instead of: $value = $obj?.property
$value = if ($obj) { $obj.property } else { $null }
```

### Testing Changes

Before submitting changes:

```powershell
# 1. Test scripts parse
$scripts = Get-ChildItem scripts/ralph/*.ps1
foreach ($s in $scripts) {
    $content = Get-Content $s.FullName -Raw
    try {
        [scriptblock]::Create($content) | Out-Null
        Write-Host "[OK] $($s.Name)"
    } catch {
        Write-Host "[FAIL] $($s.Name): $_"
    }
}

# 2. Run system tests
.\scripts\ralph\test\ralph-system-test.ps1

# 3. Run live tests
.\scripts\ralph\test\ralph-live-test.ps1

# 4. Test demo
.\examples\ralph-demo\test.ps1

# 5. Run full validation
.\scripts\ralph\ralph-validate.ps1
```

---

## Module Usage

### Browser Testing Module

```powershell
Import-Module .\scripts\ralph\ralph-browser.psm1

# Create test context
$ctx = New-BrowserTestContext -TestName "smoke" -BaseUrl "http://localhost:3000"

# Run performance test
$result = Test-PagePerformance -Context $ctx -Path "/"

# Check results
if ($result.Success) {
    Write-Host "Load time: $($result.performance.metrics.loadTime)ms"
}
```

### Resilience Module

```powershell
Import-Module .\scripts\ralph\ralph-resilience.psm1

# Retry with backoff
$result = Invoke-WithRetry -ScriptBlock {
    Invoke-SomeOperation
} -MaxRetries 5 -InitialBackoffSeconds 10

# Circuit breaker
$result = Invoke-WithCircuitBreaker -Name "api" -ScriptBlock {
    Call-ExternalAPI
} -FailureThreshold 3 -TimeoutSeconds 60
```

---

## Testing

### Test Types

| Test | Command | Purpose |
|------|---------|---------|
| System | `ralph-system-test.ps1` | Script parsing, compatibility |
| Live | `ralph-live-test.ps1` | Real operations, file creation |
| Validation | `ralph-validate.ps1` | E2E validation |

### Running Tests

```powershell
# System tests
.\scripts\ralph\test\ralph-system-test.ps1 -TestType all

# Live tests (creates actual files)
.\scripts\ralph\test\ralph-live-test.ps1 -Verbose

# Full validation
.\scripts\ralph\ralph-validate.ps1 -Detailed
```

---

## Examples

### Ralph Demo (Calculator)

```powershell
cd examples/ralph-demo

# Run tests
.\test.ps1

# Use calculator
.\ralph-demo.ps1 -Operation add -A 5 -B 3
```

### Task Manager App

```powershell
cd examples/taskmanager-app

# Run tests
.\tests\Simple.Tests.ps1

# Import module
Import-Module .\TaskManager.psm1

# Use task manager
Add-Task -Title "Buy groceries" -Priority high
Get-Tasks -Status pending
```

---

## Troubleshooting

### Scripts Won't Parse

```powershell
# Check specific line
$content = Get-Content "script.ps1"
$content[89]  # Line 90 (0-indexed)

# Check for special characters
$content | ForEach-Object { 
    $line = $_
    $unusual = $line.ToCharArray() | Where-Object { $_ -gt 127 }
    if ($unusual) { Write-Host "Line has unusual chars: $line" }
}
```

### Tests Failing

1. **Check Prerequisites:**
   ```powershell
   .\scripts\ralph\ralph-prereq-check.ps1
   ```

2. **Check PowerShell version:**
   ```powershell
   $PSVersionTable.PSVersion  # Must be 5.1+
   ```

3. **Check execution policy:**
   ```powershell
   Get-ExecutionPolicy  # Should be RemoteSigned or Unrestricted
   ```

4. **Run with verbose:**
   ```powershell
   .\script.ps1 -Verbose
   ```

### Watchdog Issues

```powershell
# Check if scheduled task exists
Get-ScheduledTask -TaskName "RalphWatchdog" -ErrorAction SilentlyContinue

# Check recent runs
Get-ScheduledTaskInfo -TaskName "RalphWatchdog"

# View watchdog logs
Get-Content .\ralph\logs\watchdog.log -Tail 20
```

---

## Quick Reference Card

```powershell
# VALIDATE SYSTEM
.\scripts\ralph\test\ralph-system-test.ps1
.\scripts\ralph\test\ralph-live-test.ps1
.\scripts\ralph\ralph-validate.ps1

# BASIC OPERATIONS
.\scripts\ralph\ralph-master.ps1 -Command status
.\scripts\ralph\ralph-master.ps1 -Command create-bead -Intent "task"
.\scripts\ralph\ralph-master.ps1 -Command run -Bead <id>
.\scripts\ralph\ralph-master.ps1 -Command govern

# WATCHDOG
.\scripts\ralph\manage-watchdog.ps1 -Action status
.\scripts\ralph\manage-watchdog.ps1 -Action restart

# TEST DEMO
.\examples\ralph-demo\test.ps1

# VALIDATE
.\scripts\ralph\ralph-validate.ps1 -Detailed
```

---

## External Dependencies

**Required:**
- PowerShell 5.1+ (built into Windows)
- Git for Windows: `winget install Git.Git`

**Required for Full Mode:**
- Go 1.21+: `winget install GoLang.Go`
- Gastown CLI (`gt`): `go install github.com/nicklynch10/gastown-cli/cmd/gt@latest`

**Optional:**
- Kimi Code CLI (`kimi`): `pip install kimi-cli` or `uv tool install kimi-cli`
- Beads CLI (`bd`): `go install github.com/nicklynch10/beads-cli/cmd/bd@latest` (optional - see below)

**About Standalone Mode:**

Ralph works in **standalone mode** without the `bd` CLI. In this mode:
- Beads are stored as JSON files in `.ralph/beads/*.json`
- The `gt` CLI is still required for core functionality
- Formulas are loaded from `.beads/formulas/*.formula.toml`

**Formula Directory Structure:**
```
.beads/
├── formulas/           # Formulas MUST be in this subdirectory
│   ├── molecule-ralph-work.formula.toml
│   ├── molecule-ralph-patrol.formula.toml
│   └── molecule-ralph-gate.formula.toml
├── schemas/
│   └── ralph-bead.schema.json
└── config.yaml
```

The `ralph-master.ps1 -Command init` and `ralph-setup.ps1` scripts automatically create this structure correctly.

**Verify Formula Location:**
```powershell
# Should show formulas in subdirectory, not flat in .beads/
Get-ChildItem .beads/formulas/*.formula.toml

# Should output 3+ formula files
```

---

## Additional Documentation

- [docs/guides/QUICKSTART.md](docs/guides/QUICKSTART.md) - Quick start guide
- [docs/guides/SETUP.md](docs/guides/SETUP.md) - Detailed setup instructions
- [docs/guides/TROUBLESHOOTING.md](docs/guides/TROUBLESHOOTING.md) - Common issues and fixes
- [docs/reference/RALPH_INTEGRATION.md](docs/reference/RALPH_INTEGRATION.md) - Technical integration guide

---

**Last Updated:** 2026-02-04
