# Ralph-Gastown Integration

> **Windows-Native AI Agent Orchestration with Correctness-Forcing DoD**

This project integrates [Ralph](https://github.com/snarktank/ralph)'s retry-semantics with [Gastown](https://github.com/steveyegge/gastown)'s durable work orchestration to create a correctness-forcing AI agent system that runs natively on Windows.

## What is This?

**Ralph-Gastown** combines three concepts:

1. **Gastown** - Durable work tracking (Beads, hooks, convoys)
2. **Ralph** - Retry-until-verified execution (DoD enforcement)
3. **Kimi** - AI implementation (Kimi Code CLI)

### Core Principle: "Test Failures Stop Progress"

Unlike typical agent loops that stop when "done", Ralph enforces a **Definition of Done (DoD)**. Work is not complete until all verifiers pass. Gates ensure failing tests block new feature work.

```
┌─────────────────────────────────────────────────────────────┐
│  RALPH EXECUTION LOOP                                        │
├─────────────────────────────────────────────────────────────┤
│  1. Parse DoD verifiers from bead                           │
│  2. Run verifiers (TDD - expect failures first)             │
│  3. Invoke Kimi with intent + constraints + verifiers       │
│  4. Kimi implements solution                                │
│  5. Run verifiers again (MUST all pass)                     │
│  6. ✓ Done  OR  ✗ Retry with failure context               │
└─────────────────────────────────────────────────────────────┘
```

## Quick Start (5 Minutes)

### Prerequisites

- Windows 10/11
- PowerShell 5.1+ (or PowerShell 7)
- [Gastown CLI](https://github.com/steveyegge/gastown) (`gt`)
- [Beads CLI](https://github.com/steveyegge/beads) (`bd`)
- [Kimi Code CLI](https://www.kimi.com/code) (`kimi`)

### Installation

```powershell
# 1. Clone this repository
git clone https://github.com/nicklynch10/gastown-kimi.git
cd gastown-kimi

# 2. Initialize Ralph in your Gastown town
.\scripts\ralph\ralph-master.ps1 -Command init

# 3. Verify installation
.\scripts\ralph\ralph-master.ps1 -Command verify
```

### Your First Ralph Bead

```powershell
# Create a bead with DoD
.\scripts\ralph\ralph-master.ps1 -Command create-bead `
    -Intent "Fix login bug" `
    -Rig myproject

# The bead is now created with:
# - Intent: what needs to be done
# - DoD: verifiers that must pass
# - Constraints: max iterations, time budget

# Run Ralph executor on the bead
.\scripts\ralph\ralph-master.ps1 -Command run -Bead gt-abc12
```

## Usage Guide

### Creating Ralph Beads

Ralph beads extend standard Gastown beads with structured DoD:

```powershell
# Quick create
.\scripts\ralph\ralph-master.ps1 -Command create-bead `
    -Intent "Implement user authentication" `
    -Rig myproject

# Or manually with full control
$beadId = bd create `
    --title "Implement auth" `
    --type task `
    --description @"
Intent: Implement JWT-based authentication

## Definition of Done
{
  "verifiers": [
    {"name": "Build", "command": "go build ./...", "expect": {"exit_code": 0}},
    {"name": "Tests", "command": "go test ./auth/...", "expect": {"exit_code": 0}}
  ]
}

## Constraints
max_iterations: 10
time_budget_minutes: 60
"@
```

### Running Ralph Work

```powershell
# Run executor on a bead
.\scripts\ralph\ralph-master.ps1 -Command run -Bead gt-abc12

# Or directly
.\scripts\ralph\ralph-executor-simple.ps1 -BeadId gt-abc12 -Verbose
```

### Managing Gates

Gates enforce "no green, no features":

```powershell
# Create a gate
.\scripts\ralph\ralph-master.ps1 -Command create-gate `
    -Type smoke `
    -Convoy convoy-xyz

# Check gate status
.\scripts\ralph\ralph-master.ps1 -Command govern

# Gate types: smoke, lint, build, test, security, custom
```

### Monitoring

```powershell
# Start watchdog (runs continuously)
.\scripts\ralph\ralph-master.ps1 -Command watchdog

# Check status
.\scripts\ralph\ralph-master.ps1 -Command status
```

## Architecture

### Three-Loop System

| Ralph Loop | Gastown Component | Purpose |
|------------|------------------|---------|
| Build Loop | `molecule-ralph-work` | Implement bead with DoD enforcement |
| Test Loop | `molecule-ralph-patrol` | Continuous testing, emit bug beads |
| Governor Loop | `ralph-governor.ps1` | "No green, no features" policy |

### Components

| Component | File | Purpose |
|-----------|------|---------|
| **ralph-master.ps1** | `scripts/ralph/ralph-master.ps1` | Main control interface |
| **ralph-executor-simple.ps1** | `scripts/ralph/ralph-executor-simple.ps1` | Retry loop executor |
| **ralph-governor.ps1** | `scripts/ralph/ralph-governor.ps1` | Policy enforcement |
| **ralph-watchdog.ps1** | `scripts/ralph/ralph-watchdog.ps1` | Always-on monitoring |
| **molecule-ralph-work** | `.beads/formulas/molecule-ralph-work.formula.toml` | Work molecule |
| **molecule-ralph-patrol** | `.beads/formulas/molecule-ralph-patrol.formula.toml` | Patrol molecule |
| **molecule-ralph-gate** | `.beads/formulas/molecule-ralph-gate.formula.toml` | Gate molecule |

## Ralph Bead Contract

```json
{
  "intent": "Behavior-level change description",
  "dod": {
    "verifiers": [
      {
        "name": "Build succeeds",
        "command": "go build ./...",
        "expect": {"exit_code": 0},
        "timeout_seconds": 60,
        "on_failure": "stop"
      }
    ],
    "evidence_required": true
  },
  "constraints": {
    "max_iterations": 10,
    "time_budget_minutes": 60
  },
  "lane": "feature",
  "priority": 2
}
```

## Example: Calculator App

See `examples/ralph-demo/` for a complete working example:

```powershell
# Run the demo application
cd examples/ralph-demo
.\ralph-demo.ps1 -Operation add -A 5 -B 3

# Run tests
.\test.ps1

# Check the Ralph bead
cat bead-gt-demo-calc-001.json
```

## Command Reference

### ralph-master.ps1

```powershell
# Commands
.\scripts\ralph\ralph-master.ps1 -Command init                    # Initialize Ralph
.\scripts\ralph\ralph-master.ps1 -Command status                  # Show status
.\scripts\ralph\ralph-master.ps1 -Command verify                  # Verify setup
.\scripts\ralph\ralph-master.ps1 -Command run -Bead <id>         # Run executor
.\scripts\ralph\ralph-master.ps1 -Command patrol -Rig <rig>       # Start patrol
.\scripts\ralph\ralph-master.ps1 -Command govern                  # Check gates
.\scripts\ralph\ralph-master.ps1 -Command watchdog               # Start watchdog
.\scripts\ralph\ralph-master.ps1 -Command create-bead            # Create bead
.\scripts\ralph\ralph-master.ps1 -Command create-gate            # Create gate
.\scripts\ralph\ralph-master.ps1 -Command help                   # Show help
```

### ralph-governor.ps1

```powershell
.\scripts\ralph\ralph-governor.ps1 -Action check                 # Check gates
.\scripts\ralph\ralph-governor.ps1 -Action status                # Show status
.\scripts\ralph\ralph-governor.ps1 -Action enforce               # Enforce policy
.\scripts\ralph\ralph-governor.ps1 -Action sling -Bead <id> -Rig <rig>
```

### ralph-watchdog.ps1

```powershell
.\scripts\ralph\ralph-watchdog.ps1                              # Run continuously
.\scripts\ralph\ralph-watchdog.ps1 -RunOnce                      # Single scan
.\scripts\ralph\ralph-watchdog.ps1 -WatchInterval 30             # Custom interval
```

## Troubleshooting

### "gt/bd/kimi not found"

Install the prerequisites:
```powershell
# Gastown
go install github.com/steveyegge/gastown/cmd/gt@latest

# Beads
go install github.com/steveyegge/beads/cmd/bd@latest

# Kimi (see https://www.kimi.com/code)
```

### "Scripts won't run"

Check PowerShell execution policy:
```powershell
Get-ExecutionPolicy
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### "Verifiers timeout"

Increase timeout in bead:
```json
{"timeout_seconds": 300}
```

## Documentation

| Document | Description |
|----------|-------------|
| `README.md` | This file - quick start and usage |
| `RALPH_INTEGRATION.md` | Detailed integration guide |
| `RALPH_TEST_REPORT.md` | Test results and validation |
| `AGENTS.md` | For AI agents working on this codebase |
| `examples/ralph-demo/` | Working example application |

## Windows Compatibility

✅ **Windows-Native**: All PowerShell scripts run natively on Windows without WSL
✅ **PowerShell 5.1+**: Compatible with both Windows PowerShell and PowerShell 7
✅ **No Bash Dependencies**: Pure PowerShell implementation
✅ **Standard Windows APIs**: Uses Windows process and file APIs

## Contributing

See `AGENTS.md` for detailed information about the codebase structure and development workflow.

## License

MIT License - See LICENSE file

## Credits

- [Gastown](https://github.com/steveyegge/gastown) by Steve Yegge
- [Ralph Pattern](https://github.com/snarktank/ralph) by Geoffrey Huntley
- [Ralph-Kimi](https://github.com/nicklynch10/ralph-kimi) by Nick Lynch
- [Kimi Code CLI](https://www.kimi.com/code) by Moonshot AI
