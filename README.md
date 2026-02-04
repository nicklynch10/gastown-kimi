# Ralph-Gastown Integration

> **Windows-Native AI Agent Orchestration with Definition of Done Enforcement**

Ralph-Gastown combines [Ralph](https://github.com/snarktank/ralph)'s retry-semantics with [Gastown](https://github.com/steveyegge/gastown)'s durable work orchestration to create a correctness-forcing AI agent system that runs natively on Windows.

**The Rule:** *Test failures stop progress.* Work isn't complete until all verifiers pass.

---

## 🚀 Quick Start (5 Minutes)

### 1. Install Prerequisites

You'll need Windows 10/11, PowerShell 5.1+, Git, Go, and the Gastown CLI.

**[📋 Complete Setup Guide →](docs/guides/SETUP.md)**

Quick install:
```powershell
# Install Git and Go
winget install Git.Git GoLang.Go

# Clone this repository
git clone <repository-url>
cd gastown-kimi

# Build Gastown CLI (Windows)
.\scripts\build-gt-windows.ps1

# Allow PowerShell scripts
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### 2. Clone and Test

```powershell
git clone https://github.com/steveyegge/gastown.git
cd gastown

# Run system tests
.\scripts\ralph\test\ralph-system-test.ps1 -TestType all

# Expected: 60 tests pass, 0 fail
```

### 3. Try It Out

```powershell
# Check status
.\scripts\ralph\ralph-master.ps1 -Command status

# Create your first bead
.\scripts\ralph\ralph-master.ps1 -Command create-bead -Intent "Hello world feature"

# Run demo
cd examples/ralph-demo
.\test.ps1
```

✅ **Done!** See [QUICKSTART.md](docs/guides/QUICKSTART.md) for more.

---

## What is Ralph-Gastown?

**Three Concepts Combined:**

1. **Gastown** - Durable work tracking (Beads, hooks, convoys)
2. **Ralph** - Retry-until-verified execution (DoD enforcement)
3. **Kimi** - AI implementation (Kimi Code CLI)

### How It Works

```
┌─────────────────────────────────────────────────────┐
│  RALPH EXECUTION LOOP                               │
├─────────────────────────────────────────────────────┤
│  1. Parse DoD verifiers from bead                   │
│  2. Run verifiers (expect failures first - TDD)     │
│  3. Invoke Kimi with intent + verifiers             │
│  4. Kimi implements solution                        │
│  5. Run verifiers again (MUST all pass)             │
│  6. Done OR Retry with failure context              │
└─────────────────────────────────────────────────────┘
```

Unlike typical agent loops that stop when "done", Ralph enforces a **Definition of Done**. The AI cannot mark work complete until all verifiers pass.

---

## Documentation

| Document | What You'll Find |
|----------|------------------|
| **[SETUP.md](docs/guides/SETUP.md)** | Complete prerequisite installation guide |
| **[QUICKSTART.md](docs/guides/QUICKSTART.md)** | 5-minute getting started guide |
| **[TROUBLESHOOTING.md](docs/guides/TROUBLESHOOTING.md)** | Common issues and solutions |
| **[AGENTS.md](AGENTS.md)** | Complete guide for AI agents |
| **[RALPH_INTEGRATION.md](docs/reference/RALPH_INTEGRATION.md)** | Technical architecture details |

---

## Ralph Bead Contract

Beads define work with a Definition of Done:

```json
{
  "intent": "Implement user authentication",
  "dod": {
    "verifiers": [
      {
        "name": "Build succeeds",
        "command": "go build ./...",
        "expect": {"exit_code": 0},
        "timeout_seconds": 60
      },
      {
        "name": "Tests pass",
        "command": "go test ./...",
        "expect": {"exit_code": 0},
        "timeout_seconds": 120
      }
    ],
    "evidence_required": true
  },
  "constraints": {
    "max_iterations": 10,
    "time_budget_minutes": 60
  }
}
```

---

## Common Commands

```powershell
# System status
.\scripts\ralph\ralph-master.ps1 -Command status

# Create work bead
.\scripts\ralph\ralph-master.ps1 -Command create-bead -Intent "Fix login bug"

# Run executor on bead
.\scripts\ralph\ralph-master.ps1 -Command run -Bead gt-abc12

# Check gates/governance
.\scripts\ralph\ralph-master.ps1 -Command govern

# Run all tests
.\scripts\ralph\test\ralph-system-test.ps1 -TestType all
.\scripts\ralph\test\ralph-live-test.ps1
```

---

## Project Structure

```
gastown-kimi/
├── scripts/ralph/              # Core Ralph scripts
│   ├── ralph-master.ps1       # Main control interface
│   ├── ralph-executor.ps1     # Retry loop executor
│   ├── ralph-governor.ps1     # Policy enforcement
│   ├── ralph-watchdog.ps1     # Always-on monitoring
│   ├── ralph-browser.psm1     # Browser testing module
│   └── test/                  # Test suite
│
├── .beads/formulas/           # Ralph molecule formulas
├── examples/ralph-demo/       # Calculator demo app
├── docs/                      # Documentation
└── cmd/gt/                    # Gastown CLI source (Go)
```

---

## Testing

```powershell
# System tests (validates scripts, no side effects)
.\scripts\ralph\test\ralph-system-test.ps1 -TestType all

# Live tests (creates files, runs commands)
.\scripts\ralph\test\ralph-live-test.ps1

# Demo app
cd examples/ralph-demo
.\test.ps1
```

---

## Windows Compatibility

- ✅ **Windows-native PowerShell** - No WSL required
- ✅ **PowerShell 5.1+** - Works on Windows PowerShell and PowerShell 7
- ✅ **No Bash Dependencies** - Pure PowerShell implementation

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) and [AGENTS.md](AGENTS.md) for detailed information.

---

## License

MIT License - See [LICENSE](LICENSE) file

## Credits

- [Gastown](https://github.com/steveyegge/gastown) by Steve Yegge
- [Ralph Pattern](https://github.com/snarktank/ralph) by Geoffrey Huntley
- [Kimi Code CLI](https://www.kimi.com/code) by Moonshot AI
