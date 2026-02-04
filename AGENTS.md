# Agent Instructions for Gastown-Kimi

> **For AI Agents:** This file contains setup and development information for working with this codebase.

## Quick Setup (5 Minutes)

### 1. Validate System Works

```powershell
# Run comprehensive test suite
.\scripts\ralph\test\ralph-system-test.ps1 -TestType all

# Expected: 60+ tests pass, 0 fail
```

### 2. Run Live Tests

```powershell
# Tests actual operations (creates files, runs commands)
.\scripts\ralph\test\ralph-live-test.ps1

# Expected: 16+ tests pass
```

### 3. You're Ready!

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

**Optional:**
- Kimi Code CLI (`kimi`): `pip install kimi-cli`
- Go 1.21+: `winget install GoLang.Go` (for building gt/bd CLIs)
- Gastown CLI (`gt`): `go install github.com/nicklynch10/gastown-cli/cmd/gt@latest`
- Beads CLI (`bd`): `go install github.com/nicklynch10/beads-cli/cmd/bd@latest`

**Stand-alone Mode:**
The `ralph-executor-standalone.ps1` can operate without gt/bd using local JSON files.

---

## Additional Documentation

- [docs/guides/QUICKSTART.md](docs/guides/QUICKSTART.md) - Quick start guide
- [docs/guides/SETUP.md](docs/guides/SETUP.md) - Detailed setup instructions
- [docs/guides/TROUBLESHOOTING.md](docs/guides/TROUBLESHOOTING.md) - Common issues and fixes
- [docs/reference/RALPH_INTEGRATION.md](docs/reference/RALPH_INTEGRATION.md) - Technical integration guide

---

**Last Updated:** 2026-02-03
