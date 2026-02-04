# Ralph-Gastown Integration

> **Windows-Native AI Agent Orchestration with Definition of Done Enforcement**

This project integrates [Ralph](https://github.com/snarktank/ralph)'s retry-semantics with [Gastown](https://github.com/steveyegge/gastown)'s durable work orchestration to create a correctness-forcing AI agent system that runs natively on Windows.

## Quick Start

### Prerequisites

- Windows 10/11
- PowerShell 5.1+
- Git: `winget install Git.Git`
- Go: `winget install GoLang.Go` (for building gt CLI)
- Kimi CLI (optional): `pip install kimi-cli`

#### Building Gastown CLI (gt)

The gt binary must be built with proper version flags:

```powershell
# Use the provided build script
.\scripts\build-gt.ps1

# Or build manually with ldflags
$env:VERSION="dev"
$env:COMMIT=$(git rev-parse --short HEAD)
$env:BUILD_TIME=$(Get-Date -Format "o")
go build -ldflags "-X github.com/steveyegge/gastown/internal/cmd.Version=$env:VERSION -X github.com/steveyegge/gastown/internal/cmd.Commit=$env:COMMIT -X github.com/steveyegge/gastown/internal/cmd.BuildTime=$env:BUILD_TIME -X github.com/steveyegge/gastown/internal/cmd.BuiltProperly=1" -o gt.exe ./cmd/gt
```

**Note:** The `bd` (Beads) CLI is not required. Ralph works in standalone mode without it.

### 1. Validate System (1 minute)

```powershell
# Run all validation tests
.\scripts\ralph\test\ralph-system-test.ps1 -TestType all

# Expected: 60+ tests pass
```

### 2. Run Demo Application (1 minute)

```powershell
cd examples/ralph-demo
.\test.ps1

# Expected: 5/5 tests pass
```

### 3. Try Ralph Commands

```powershell
# Check status
.\scripts\ralph\ralph-master.ps1 -Command status

# Create a bead
.\scripts\ralph\ralph-master.ps1 -Command create-bead -Intent "Implement feature X"

# Run validation
.\scripts\ralph\ralph-validate.ps1
```

## What is This?

**Ralph-Gastown** combines three concepts:

1. **Gastown** - Durable work tracking (Beads, hooks, convoys)
2. **Ralph** - Retry-until-verified execution (DoD enforcement)
3. **Kimi** - AI implementation (Kimi Code CLI)

### Core Principle: "Test Failures Stop Progress"

Unlike typical agent loops that stop when "done", Ralph enforces a **Definition of Done (DoD)**. Work is not complete until all verifiers pass.

```
+------------------------------------------+
|  RALPH EXECUTION LOOP                     |
+------------------------------------------+
|  1. Parse DoD verifiers from bead        |
|  2. Run verifiers (expect fails first)   |
|  3. Invoke Kimi with intent + verifiers  |
|  4. Kimi implements solution             |
|  5. Run verifiers again (MUST pass)      |
|  6. Done OR Retry with context           |
+------------------------------------------+
```

## Documentation

| Document | Description |
|----------|-------------|
| [docs/guides/QUICKSTART.md](docs/guides/QUICKSTART.md) | Step-by-step quick start guide |
| [docs/guides/QUICK_REFERENCE.md](docs/guides/QUICK_REFERENCE.md) | One-page command reference |
| [docs/guides/TROUBLESHOOTING.md](docs/guides/TROUBLESHOOTING.md) | Common issues and fixes |
| [docs/guides/BROWSER_TESTING.md](docs/guides/BROWSER_TESTING.md) | Browser testing guide |
| [docs/reference/RALPH_INTEGRATION.md](docs/reference/RALPH_INTEGRATION.md) | Technical integration guide |
| [docs/reference/BEAD_SCHEMA.md](docs/reference/BEAD_SCHEMA.md) | Bead JSON schema reference |
| [AGENTS.md](AGENTS.md) | Complete guide for AI agents |

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

## Key Commands

### Ralph Master

```powershell
# System status
.\scripts\ralph\ralph-master.ps1 -Command status

# Create work bead
.\scripts\ralph\ralph-master.ps1 -Command create-bead -Intent "Fix login bug"

# Run executor on bead
.\scripts\ralph\ralph-master.ps1 -Command run -Bead gt-abc12

# Check governance
.\scripts\ralph\ralph-master.ps1 -Command govern

# Verify installation
.\scripts\ralph\ralph-master.ps1 -Command verify
```

### Watchdog Management

```powershell
# Check watchdog status
.\scripts\ralph\manage-watchdog.ps1 -Action status

# Start/stop/restart
.\scripts\ralph\manage-watchdog.ps1 -Action stop
.\scripts\ralph\manage-watchdog.ps1 -Action start
.\scripts\ralph\manage-watchdog.ps1 -Action restart
```

## Project Structure

```
gastown-kimi/
├── scripts/ralph/              # Core Ralph scripts
│   ├── ralph-master.ps1       # Main control interface
│   ├── ralph-executor.ps1     # Retry loop executor
│   ├── ralph-governor.ps1     # Policy enforcement
│   ├── ralph-watchdog.ps1     # Always-on monitoring
│   ├── ralph-validate.ps1     # E2E validation
│   ├── ralph-browser.psm1     # Browser testing module
│   ├── ralph-resilience.psm1  # Error handling module
│   └── test/
│       ├── ralph-system-test.ps1
│       └── ralph-live-test.ps1
│
├── .beads/
│   ├── formulas/               # Ralph molecules
│   │   ├── molecule-ralph-work.formula.toml
│   │   ├── molecule-ralph-patrol.formula.toml
│   │   └── molecule-ralph-gate.formula.toml
│   └── schemas/
│       └── ralph-bead.schema.json
│
├── examples/
│   ├── ralph-demo/            # Calculator demo
│   └── taskmanager-app/       # Full Task Manager example
│
├── cmd/gt/                    # Gastown CLI (Go)
├── internal/                  # Go internal packages
├── docs/                      # Documentation
└── tests/                     # Additional tests
```

## Testing

### System Tests

```powershell
# All validation tests
.\scripts\ralph\test\ralph-system-test.ps1 -TestType all

# Live operations test
.\scripts\ralph\test\ralph-live-test.ps1

# End-to-end validation
.\scripts\ralph\ralph-validate.ps1
```

### Demo Applications

```powershell
# Calculator demo
cd examples/ralph-demo
.\test.ps1

# Task Manager demo
cd examples/taskmanager-app
.\tests\Simple.Tests.ps1
```

## Windows Compatibility

- **Windows-native PowerShell** - No WSL required
- **PowerShell 5.1+** - Compatible with Windows PowerShell and PowerShell 7
- **No Bash Dependencies** - Pure PowerShell implementation

## Troubleshooting

### Scripts Won't Run

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Missing Tools

```powershell
# Run prerequisite check
.\scripts\ralph\ralph-prereq-check.ps1
```

See [docs/guides/TROUBLESHOOTING.md](docs/guides/TROUBLESHOOTING.md) for more help.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) and [AGENTS.md](AGENTS.md) for detailed information.

## License

MIT License - See [LICENSE](LICENSE) file

## Credits

- [Gastown](https://github.com/steveyegge/gastown) by Steve Yegge
- [Ralph Pattern](https://github.com/snarktank/ralph) by Geoffrey Huntley
- [Kimi Code CLI](https://www.kimi.com/code) by Moonshot AI
