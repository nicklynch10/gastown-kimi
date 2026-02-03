# Agent Instructions for Gastown-Kimi

> **For AI Agents:** This file contains setup and development information for working with this codebase.

## 📋 Prerequisites (Required Before Use)

Before using this SDLC system, ensure you have:

### Required Tools

| Tool | Version | Purpose | Install Command |
|------|---------|---------|-----------------|
| PowerShell | 5.1+ | Script execution | Included with Windows |
| Git | Latest | Version control | `winget install Git.Git` |
| Kimi CLI | Latest | AI execution | `pip install kimi-cli` |

### Optional Tools

| Tool | Purpose | Install Command |
|------|---------|-----------------|
| Gastown CLI (gt) | Town management | `go install github.com/nicklynch10/gastown-cli/cmd/gt@latest` |
| Beads CLI (bd) | Bead operations | `go install github.com/nicklynch10/beads-cli/cmd/bd@latest` |
| Go | Building Gastown | `winget install GoLang.Go` |
| Node.js | Browser testing | `winget install OpenJS.NodeJS` |

### Verify Prerequisites

```powershell
# Check all prerequisites
.\scripts\ralph\ralph-prereq-check.ps1

# Should show: All required tools found
```

### Fix Common Issues

**PowerShell Execution Policy:**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**Git Configuration:**
```powershell
git config --global user.name "Your Name"
git config --global user.email "your@email.com"
```

---

## 🚀 Quick Start for New Agents (5 Minutes)

### Step 1: Validate System Works

```powershell
# Run the comprehensive test suite
.\scripts\ralph\test\ralph-system-test.ps1 -TestType all

# Expected: 42 tests pass, 0 fail
```

### Step 2: Run Comprehensive Tests

```powershell
# Run all tests including functional
.\scripts\ralph\test\ralph-comprehensive-test.ps1

# Expected: All tests pass (some may skip if optional tools missing)
```

### Step 3: Test Demo Application

```powershell
cd examples/ralph-demo
.\test.ps1

# Expected: 5/5 tests pass
```

### Step 4: You're Ready!

If all tests pass, the system is operational. See [Usage Guide](#usage-guide) below.

---

## 📋 Repository Overview

This is **Gastown** with full **Ralph-Gastown integration** - a Windows-native AI agent orchestration system.

**Core Philosophy:**
- **Gastown** = Durable work tracking (Beads, hooks, convoys)
- **Ralph** = Retry-until-verified execution (DoD enforcement)
- **Kimi** = AI implementation (Kimi Code CLI)

**The Rule:** Test failures stop progress. No green, no features.

---

## 🗂️ Project Structure

```
gastown-kimi/
├── cmd/gt/                    # Main CLI entry point (Go)
├── internal/                  # Go internal packages
│   ├── config/               # Agent presets
│   ├── cmd/                  # CLI commands
│   ├── polecat/              # Agent session management
│   └── rig/                  # Repository/workspace management
│
├── scripts/ralph/            # ⭐ RALPH INTEGRATION SCRIPTS
│   ├── ralph-master.ps1      # Main control interface
│   ├── ralph-executor.ps1    # Full-featured executor
│   ├── ralph-executor-simple.ps1  # Lightweight executor
│   ├── ralph-governor.ps1    # Policy enforcement
│   ├── ralph-watchdog.ps1    # Always-on monitoring
│   ├── ralph-setup.ps1       # One-command SDLC setup
│   ├── ralph-validate.ps1    # E2E validation
│   ├── ralph-browser.psm1    # Browser testing module
│   ├── ralph-resilience.psm1 # Error handling module
│   └── test/
│       ├── ralph-system-test.ps1  # Comprehensive tests
│       └── ralph-live-test.ps1    # Live material tests
│
├── .beads/
│   ├── formulas/             # Ralph molecules
│   │   ├── molecule-ralph-work.formula.toml
│   │   ├── molecule-ralph-patrol.formula.toml
│   │   └── molecule-ralph-gate.formula.toml
│   └── schemas/
│       └── ralph-bead.schema.json
│
├── examples/ralph-demo/      # Working demo app
│   ├── Calculator.psm1
│   ├── test.ps1
│   └── bead-gt-demo-calc-001.json
│
└── docs/                     # Documentation
```

---

## 🧪 Testing (Agent's Best Friend)

### 1. System Test Suite (Static Tests)

Tests script parsing, compatibility, structure:

```powershell
# All tests
.\scripts\ralph\test\ralph-system-test.ps1 -TestType all

# Just unit tests
.\scripts\ralph\test\ralph-system-test.ps1 -TestType unit

# Just integration tests
.\scripts\ralph\test\ralph-system-test.ps1 -TestType integration
```

**What it tests:**
- All scripts parse correctly
- PowerShell 5.1 compatibility
- Formula files are valid
- Schema is valid JSON
- Demo app files exist

### 2. Live Material Test (Real Operations)

Tests actual execution (creates files, runs commands):

```powershell
.\scripts\ralph\test\ralph-live-test.ps1

# Keep artifacts for inspection
.\scripts\ralph\test\ralph-live-test.ps1 -KeepTestArtifacts -Verbose
```

**What it tests:**
- Core script execution
- Bead creation and validation
- Real verifier execution
- Ralph executor dry-run
- Resilience module functions
- Browser module loading
- Demo application
- Formula validation

### 3. Validation Script

End-to-end validation with detailed reporting:

```powershell
# Console output
.\scripts\ralph\ralph-validate.ps1 -Detailed

# JSON output
.\scripts\ralph\ralph-validate.ps1 -OutputFormat json

# Markdown report
.\scripts\ralph\ralph-validate.ps1 -OutputFormat markdown
```

### 4. Demo Application

```powershell
cd examples/ralph-demo

# Run tests
.\test.ps1

# Use calculator
.\ralph-demo.ps1 -Operation add -A 5 -B 3
```

---

## 🎯 Usage Guide

### Ralph Master Script

Main control interface for Ralph operations:

```powershell
# Get help
.\scripts\ralph\ralph-master.ps1 -Command help

# Check system status
.\scripts\ralph\ralph-master.ps1 -Command status

# Create a new bead
.\scripts\ralph\ralph-master.ps1 -Command create-bead -Intent "Fix login bug"

# Run executor on a bead
.\scripts\ralph\ralph-master.ps1 -Command run -Bead gt-abc123

# Check governance
.\scripts\ralph\ralph-master.ps1 -Command govern

# Start watchdog
.\scripts\ralph\ralph-master.ps1 -Command watchdog
```

### Ralph Executor

Core retry-loop with DoD enforcement:

```powershell
# Full executor
.\scripts\ralph\ralph-executor.ps1 -BeadId "gt-abc123" -MaxIterations 10

# Simple executor
.\scripts\ralph\ralph-executor-simple.ps1 -BeadId "gt-abc123" -DryRun
```

### Ralph Governor

Policy enforcement ("no green, no features"):

```powershell
# Check gate status
.\scripts\ralph\ralph-governor.ps1 -Action check

# Check specific convoy
.\scripts\ralph\ralph-governor.ps1 -Action check -ConvoyId "convoy-abc"

# Show status
.\scripts\ralph\ralph-governor.ps1 -Action status

# Enforce policies
.\scripts\ralph\ralph-governor.ps1 -Action enforce

# Sling with policy check
.\scripts\ralph\ralph-governor.ps1 -Action sling -BeadId "gt-feature" -Rig "myproject"
```

### Ralph Watchdog

Always-on monitoring:

```powershell
# Run once (for testing)
.\scripts\ralph\ralph-watchdog.ps1 -RunOnce -DryRun

# Run continuously
.\scripts\ralph\ralph-watchdog.ps1 -WatchInterval 60
```

### One-Command Setup

Set up a new project with Ralph SDLC:

```powershell
# Basic setup
.\scripts\ralph\ralph-setup.ps1 -ProjectName "myapp" -ProjectType go

# With browser tests
.\scripts\ralph\ralph-setup.ps1 -ProjectName "webapp" -ProjectType node -WithBrowserTests -WithPatrol
```

### Browser Testing Module

Context-efficient browser testing:

```powershell
# Load module
Import-Module .\scripts\ralph\ralph-browser.psm1

# Create test context
$ctx = New-BrowserTestContext -TestName "smoke" -BaseUrl "http://localhost:3000"

# Run performance test
$result = Test-PagePerformance -Context $ctx -Path "/"

# Check results
if ($result.Success) {
    Write-Host "Load time: $($result.performance.metrics.loadTime)ms"
}

# Run accessibility test
$a11y = Test-PageAccessibility -Context $ctx -Path "/login"
```

### Resilience Module

Error handling and retry logic:

```powershell
# Load module
Import-Module .\scripts\ralph\ralph-resilience.psm1

# Retry with backoff
$result = Invoke-WithRetry -ScriptBlock {
    # Your code here
    Invoke-SomeOperation
} -MaxRetries 5 -InitialBackoffSeconds 10

# Circuit breaker
$result = Invoke-WithCircuitBreaker -Name "api" -ScriptBlock {
    Call-ExternalAPI
} -FailureThreshold 3 -TimeoutSeconds 60

# Resilient process
$result = Start-ResilientProcess -FilePath "git" -Arguments "clone ..." -TimeoutSeconds 120
```

---

## 🔧 Ralph Bead Contract

Beads define work with Definition of Done:

```json
{
  "id": "gt-feature-001",
  "title": "Implement user authentication",
  "intent": "Add JWT-based authentication to the API",
  "dod": {
    "verifiers": [
      {
        "name": "Build succeeds",
        "command": "go build ./...",
        "expect": {"exit_code": 0},
        "timeout_seconds": 60
      },
      {
        "name": "Unit tests pass",
        "command": "go test ./auth/...",
        "expect": {"exit_code": 0},
        "timeout_seconds": 120
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

**Required fields:**
- `intent` - What needs to be done
- `dod.verifiers` - List of verification commands

**Verifier structure:**
- `name` - Human-readable name
- `command` - PowerShell command to execute
- `expect.exit_code` - Expected exit code (default: 0)
- `expect.stdout_contains` - Optional string to check in output
- `timeout_seconds` - Timeout (default: 300)

---

## 🏗️ Development Guidelines

### Adding New Scripts

1. **Use proper PowerShell structure:**
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

2. **Maintain PS5.1 compatibility:**
   - No `??` (null coalescing)
   - No `?.` (null conditional)
   - No `??=` (null coalescing assignment)
   - Use ASCII characters only (no box drawing)

3. **Add to test suite:**
   - Add parsing test to `ralph-system-test.ps1`
   - Add functional test to `ralph-live-test.ps1`

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

# 5. Validate
.\scripts\ralph\ralph-validate.ps1
```

---

## 🪟 Windows Compatibility

- **Windows-native PowerShell** - No WSL or bash required
- **PowerShell 5.1+ compatible** - Avoid PS7-only syntax
- **Standard Windows APIs** - Uses .NET Framework

**PS5.1 Compatibility Check:**
```powershell
# Check for problematic operators
$content = Get-Content "your-script.ps1" -Raw
if ($content -match '\$\w+\?\?\s') { Write-Host "Contains ?? operator" }
if ($content -match '\$\w+\?\.') { Write-Host "Contains ?. operator" }
```

---

## 📚 Documentation Files

| File | Purpose |
|------|---------|
| `README.md` | Main user documentation |
| `QUICKSTART.md` | Quick start guide |
| `RALPH_INTEGRATION.md` | Detailed integration guide |
| `RALPH_SYSTEM_VALIDATION.md` | Validation results |
| `RALPH_FINAL_REPORT.md` | Implementation report |
| `AGENTS.md` | This file |

---

## 🆘 Troubleshooting

### Scripts Won't Parse

```powershell
# Check specific line
$content = Get-Content "script.ps1"
$content[89]  # Line 90 (0-indexed)

# Check for special characters (box drawing, etc.)
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
   $PSVersionTable.PSVersion  # Must be 5.1 or higher
   ```

3. **Check execution policy:**
   ```powershell
   Get-ExecutionPolicy  # Should be RemoteSigned or Unrestricted
   ```

4. **Run with verbose:**
   ```powershell
   .\script.ps1 -Verbose
   ```

5. **Review test artifacts:**
   ```powershell
   Get-ChildItem .ralph/live-test-* | Sort-Object LastWriteTime -Descending | Select-Object -First 1
   ```

### Missing Commands

| Command | Install | Priority |
|---------|---------|----------|
| `gt` | `go install github.com/nicklynch10/gastown-cli/cmd/gt@latest` | Optional |
| `bd` | `go install github.com/nicklynch10/beads-cli/cmd/bd@latest` | Optional |
| `kimi` | `pip install kimi-cli` | **Required** |
| `go` | `winget install GoLang.Go` | Optional |

### Common Error Messages

**"The term 'kimi' is not recognized"**
```powershell
# Fix: Install Kimi CLI
pip install kimi-cli
# Restart PowerShell after installation
```

**"Execution of scripts is disabled"**
```powershell
# Fix: Set execution policy
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**"Cannot find path '.beads/formulas/...'"**
```powershell
# Fix: Run from project root
Set-Location C:\Users\Nick Lynch\Desktop\Coding Projects\KimiGasTown
```

---

## 🔗 External Dependencies

**Optional but recommended:**
- Gastown CLI (`gt`) - For full town management
- Beads CLI (`bd`) - For bead operations
- Kimi Code CLI (`kimi`) - For AI execution
- Go - For building Gastown
- Node.js - For browser testing

**Core scripts work without these** - they'll skip features that need them.

---

## 📝 Quick Reference Card

```powershell
# VALIDATE SYSTEM
.\scripts\ralph\test\ralph-system-test.ps1
.\scripts\ralph\test\ralph-live-test.ps1

# BASIC OPERATIONS
.\scripts\ralph\ralph-master.ps1 -Command status
.\scripts\ralph\ralph-master.ps1 -Command create-bead -Intent "task"
.\scripts\ralph\ralph-master.ps1 -Command run -Bead <id>

# SETUP NEW PROJECT
.\scripts\ralph\ralph-setup.ps1 -ProjectName "app" -ProjectType go

# TEST DEMO
cd examples/ralph-demo
.\test.ps1

# VALIDATE
.\scripts\ralph\ralph-validate.ps1 -Detailed
```

---

**Repository:** https://github.com/nicklynch10/gastown-kimi

**Last Updated:** 2026-02-02
