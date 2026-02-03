# Task Manager Application

A sample application built using the Ralph-Gastown SDLC process.

## Overview

This is a PowerShell-based Task Manager CLI that demonstrates:
- Ralph bead-driven development
- Definition of Done enforcement
- Gate-based quality control
- 24/7 watchdog monitoring

## Architecture

```
taskmanager-app/
├── README.md                 # This file
├── TaskManager.psd1          # Module manifest
├── TaskManager.psm1          # Main module
├── TaskStore.psm1            # Storage module
├── tests/
│   ├── TaskManager.Tests.ps1
│   └── TaskStore.Tests.ps1
├── beads/
│   ├── bead-feature-add.json
│   ├── bead-feature-list.json
│   ├── bead-feature-complete.json
│   └── bead-gate-smoke.json
└── verifiers/
    └── verify-all.ps1
```

## Quick Start

```powershell
# Import the module
Import-Module .\TaskManager.psm1

# Add a task
Add-Task -Title "Buy groceries" -Priority high

# List tasks
Get-Tasks

# Complete a task
Complete-Task -Id 1
```

## Development

This project was built using Ralph-Gastown beads:
- Each feature has a corresponding bead in `beads/`
- All beads have verifiers that must pass
- Gates enforce quality before features are merged

## Testing

```powershell
# Run all tests
.\tests\Run-AllTests.ps1

# Or run specific test file
Invoke-Pester -Path .\tests\TaskManager.Tests.ps1
```
