# Ralph-Gastown Integration

> **Windows-Native AI Agent Orchestration with Correctness-Forcing Definition of Done**

This project integrates [Ralph](https://github.com/snarktank/ralph)'s retry-semantics with [Gastown](https://github.com/steveyegge/gastown)'s durable work orchestration to create a correctness-forcing AI agent system that runs natively on Windows.

## Quick Start (5 Minutes)

### Prerequisites

- Windows 10/11
- PowerShell 5.1+
- Git: `winget install Git.Git`
- Kimi CLI: `pip install kimi-cli`

### 1. Verify System Health

```powershell
# Run all validation tests
.\scripts\ralph\ralph-validate.ps1

# Expected: 56/56 tests pass
```

### 2. Install 24/7 Watchdog

```powershell
# Run as Administrator
.\scripts\ralph\setup-watchdog.ps1
```

### 3. Your First Ralph Bead

```powershell
# Create a bead with Definition of Done
.\scripts\ralph\ralph-master.ps1 -Command create-bead `
    -Intent "Implement user authentication feature"

# Run Ralph executor
.\scripts\ralph\ralph-master.ps1 -Command run -Bead gt-abc12
```

## What is This?

**Ralph-Gastown** combines three concepts:

1. **Gastown** - Durable work tracking (Beads, hooks, convoys)
2. **Ralph** - Retry-until-verified execution (DoD enforcement)
3. **Kimi** - AI implementation (Kimi Code CLI)

### Core Principle: "Test Failures Stop Progress"

Unlike typical agent loops that stop when "done", Ralph enforces a **Definition of Done (DoD)**. Work is not complete until all verifiers pass. Gates ensure failing tests block new feature work.

```
+------------------------------------------+
|  RALPH EXECUTION LOOP                     |
+------------------------------------------+
|  1. Parse DoD verifiers from bead        |
|  2. Run verifiers (TDD - expect fails)   |
|  3. Invoke Kimi with intent + verifiers  |
|  4. Kimi implements solution             |
|  5. Run verifiers again (MUST pass)      |
|  6. Done OR Retry with context           |
+------------------------------------------+
```

## Documentation

| Document | Description |
|----------|-------------|
| [docs/guides/QUICKSTART.md](docs/guides/QUICKSTART.md) | Quick start guide |
| [docs/guides/SETUP.md](docs/guides/SETUP.md) | Detailed setup instructions |
| [docs/reference/RALPH_INTEGRATION.md](docs/reference/RALPH_INTEGRATION.md) | Technical integration guide |
| [AGENTS.md](AGENTS.md) | Guide for AI agents |

## Usage Guide

### Ralph Master Commands

```powershell
# System status
.\scripts\ralph\ralph-master.ps1 -Command status

# Create work bead
.\scripts\ralph\ralph-master.ps1 -Command create-bead `
    -Intent "Fix login bug"

# Run executor on bead
.\scripts\ralph\ralph-master.ps1 -Command run -Bead gt-abc12

# Check governance ("no green, no features")
.\scripts\ralph\ralph-master.ps1 -Command govern

# Start watchdog
.\scripts\ralph\ralph-master.ps1 -Command watchdog

# Verify installation
.\scripts\ralph\ralph-master.ps1 -Command verify
```

### Managing the Watchdog

```powershell
# Check watchdog status
.\scripts\ralph\manage-watchdog.ps1 -Action status

# Stop watchdog
.\scripts\ralph\manage-watchdog.ps1 -Action stop

# Restart watchdog
.\scripts\ralph\manage-watchdog.ps1 -Action restart
```

## Architecture

### Three-Loop System

| Loop | Component | Purpose |
|------|-----------|---------|
| Build | `molecule-ralph-work` | Implement bead with DoD enforcement |
| Test | `molecule-ralph-patrol` | Continuous testing, emit bug beads |
| Governor | `ralph-governor.ps1` | "No green, no features" policy |

### Key Components

```
gastown-kimi/
├── scripts/ralph/
│   ├── ralph-master.ps1       # Main control interface
│   ├── ralph-executor.ps1     # Retry loop executor
│   ├── ralph-governor.ps1     # Policy enforcement
│   ├── ralph-watchdog.ps1     # Always-on monitoring
│   ├── ralph-setup.ps1        # One-command setup
│   ├── ralph-validate.ps1     # E2E validation
│   ├── ralph-browser.psm1     # Browser testing module
│   ├── ralph-resilience.psm1  # Error handling module
│   └── test/
│       ├── ralph-system-test.ps1
│       └── ralph-live-test.ps1
│
├── .beads/
│   ├── formulas/
│   │   ├── molecule-ralph-work.formula.toml
│   │   ├── molecule-ralph-patrol.formula.toml
│   │   └── molecule-ralph-gate.formula.toml
│   └── schemas/
│       └── ralph-bead.schema.json
│
├── examples/
│   ├── ralph-demo/            # Calculator demo
│   └── taskmanager-app/       # Full Task Manager app
│
└── docs/
    ├── guides/                # User guides
    ├── reference/             # Technical reference
    └── reports/               # Test reports
```

## Ralph Bead Contract

Beads define work with a Definition of Done:

```json
{
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
  "priority": 2
}
```

## Testing

### System Tests

```powershell
# All validation tests (56 tests)
.\scripts\ralph\ralph-validate.ps1

# System tests only
.\scripts\ralph\test\ralph-system-test.ps1 -TestType all

# Live material tests
.\scripts\ralph\test\ralph-live-test.ps1
```

### Demo Application

```powershell
cd examples/ralph-demo
.\test.ps1

# Or run the calculator
.\ralph-demo.ps1 -Operation add -A 5 -B 3
```

## Troubleshooting

### Common Issues

**Scripts won't run:**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**Missing tools:**
```powershell
# Run prerequisite check
.\scripts\ralph\ralph-prereq-check.ps1
```

**Verifiers timeout:**
```powershell
# Increase timeout in bead
{"timeout_seconds": 300}
```

## Windows Compatibility

- **Windows-native PowerShell** - No WSL required
- **PowerShell 5.1+** - Compatible with Windows PowerShell and PowerShell 7
- **No Bash Dependencies** - Pure PowerShell implementation

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) and [AGENTS.md](AGENTS.md) for detailed information.

## License

MIT License - See [LICENSE](LICENSE) file

## Credits

- [Gastown](https://github.com/steveyegge/gastown) by Steve Yegge
- [Ralph Pattern](https://github.com/snarktank/ralph) by Geoffrey Huntley
- [Kimi Code CLI](https://www.kimi.com/code) by Moonshot AI
