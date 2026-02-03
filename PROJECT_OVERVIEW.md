# Ralph-Gastown Project Overview

**A Windows-native AI agent orchestration system with correctness-forcing DoD**

---

## What This Project Is

This repository integrates **Ralph's** retry-semantics with **Gastown's** durable work orchestration to create a correctness-forcing AI agent system that:

- ✅ Runs natively on Windows PowerShell (no WSL)
- ✅ Enforces Definition of Done (DoD) before marking work complete
- ✅ Blocks features when tests fail (gates)
- ✅ Automatically retries with context until verifiers pass
- ✅ Monitors work to prevent stalls

### Core Principle

> **"Test Failures Stop Progress"**

Work is not done until ALL verifiers pass. No exceptions.

---

## Repository Structure

```
gastown-kimi/
│
├── 📖 Documentation
│   ├── README.md                    ⭐ START HERE
│   ├── QUICKSTART.md                Step-by-step setup
│   ├── QUICK_REFERENCE.md           One-page cheat sheet
│   ├── RALPH_INTEGRATION.md         Technical architecture
│   ├── AGENTS.md                    For developers/agents
│   ├── RALPH_TEST_REPORT.md         Test validation
│   └── RALPH_LIVE_DEMO_REPORT.md    Live demo results
│
├── 🔧 Ralph Integration
│   ├── scripts/ralph/
│   │   ├── ralph-master.ps1         ⭐ Main control script
│   │   ├── ralph-executor-simple.ps1 ⭐ Retry loop executor
│   │   ├── ralph-governor.ps1       Policy enforcement
│   │   └── ralph-watchdog.ps1       Monitoring
│   │
│   └── .beads/
│       ├── formulas/
│       │   ├── molecule-ralph-work.formula.toml
│       │   ├── molecule-ralph-patrol.formula.toml
│       │   └── molecule-ralph-gate.formula.toml
│       └── schemas/
│           └── ralph-bead.schema.json
│
├── 💡 Example Application
│   └── examples/ralph-demo/
│       ├── Calculator.psm1
│       ├── ralph-demo.ps1
│       ├── test.ps1
│       └── bead-*.json
│
├── 🧪 Tests
│   └── tests/ralph/
│       ├── integration.tests.ps1
│       ├── ralph-executor.tests.ps1
│       └── ralph-governor.tests.ps1
│
└── 🔩 Gastown Core (internal/)
    ├── config/                      Agent presets
    ├── cmd/                         CLI commands
    └── ...
```

---

## Quick Start (5 Minutes)

### 1. Install Prerequisites

```powershell
# Gastown CLI
go install github.com/steveyegge/gastown/cmd/gt@latest

# Beads CLI
go install github.com/steveyegge/beads/cmd/bd@latest

# Kimi CLI (from https://www.kimi.com/code)
```

### 2. Clone and Initialize

```powershell
git clone https://github.com/nicklynch10/gastown-kimi.git
cd gastown-kimi
.\scripts\ralph\ralph-master.ps1 -Command init
```

### 3. Create Your First Bead

```powershell
.\scripts\ralph\ralph-master.ps1 -Command create-bead `
    -Intent "Fix login bug" `
    -Rig myproject
```

### 4. Run Ralph

```powershell
.\scripts\ralph\ralph-master.ps1 -Command run -Bead gt-abc12
```

---

## Key Components

| Component | Purpose | File |
|-----------|---------|------|
| **ralph-master.ps1** | Main interface | `scripts/ralph/ralph-master.ps1` |
| **ralph-executor-simple.ps1** | Retry loop | `scripts/ralph/ralph-executor-simple.ps1` |
| **ralph-governor.ps1** | Policy enforcement | `scripts/ralph/ralph-governor.ps1` |
| **ralph-watchdog.ps1** | Monitoring | `scripts/ralph/ralph-watchdog.ps1` |
| **molecule-ralph-work** | Build loop formula | `.beads/formulas/molecule-ralph-work.formula.toml` |
| **molecule-ralph-patrol** | Test loop formula | `.beads/formulas/molecule-ralph-patrol.formula.toml` |
| **molecule-ralph-gate** | Gate formula | `.beads/formulas/molecule-ralph-gate.formula.toml` |

---

## How It Works

### The Ralph Loop

```
1. Parse bead → Load DoD verifiers
      ↓
2. Run verifiers (TDD - expect failures)
      ↓
3. Invoke Kimi with intent + constraints + verifiers
      ↓
4. Kimi implements solution
      ↓
5. Run verifiers again
      ↓
   ┌──────────┐
   │ All Pass?│──YES──→ DONE ✓
   └────┬─────┘
        │ NO
        ↓
   Retry with context
   (up to max_iterations)
```

### Three-Loop System

| Loop | Component | Purpose |
|------|-----------|---------|
| **Build** | molecule-ralph-work | Implement with DoD |
| **Test** | molecule-ralph-patrol | Continuous testing |
| **Govern** | ralph-governor.ps1 | Policy enforcement |

---

## Example: Ralph Bead

```json
{
  "id": "gt-feature-001",
  "intent": "Implement user authentication",
  "dod": {
    "verifiers": [
      {"name": "Build", "command": "go build ./...", "expect": {"exit_code": 0}},
      {"name": "Tests", "command": "go test ./auth/...", "expect": {"exit_code": 0}}
    ]
  },
  "constraints": {
    "max_iterations": 10,
    "time_budget_minutes": 60
  }
}
```

---

## Testing

All components are tested and working:

| Test | Status |
|------|--------|
| File structure | ✅ All present |
| JSON schema | ✅ Valid |
| TOML formulas | ✅ Valid |
| PowerShell syntax | ✅ All parse |
| Script execution | ✅ All run |
| Demo application | ✅ Tests pass |
| Ralph verifiers | ✅ All pass |

See `RALPH_TEST_REPORT.md` and `RALPH_LIVE_DEMO_REPORT.md` for details.

---

## Documentation Guide

| If you want to... | Read this... |
|-------------------|--------------|
| **Get started quickly** | `README.md` ⭐ |
| **Set up from scratch** | `QUICKSTART.md` |
| **Find a command** | `QUICK_REFERENCE.md` |
| **Understand architecture** | `RALPH_INTEGRATION.md` |
| **Develop/contribute** | `AGENTS.md` |
| **See test results** | `RALPH_TEST_REPORT.md` |
| **See live demo** | `RALPH_LIVE_DEMO_REPORT.md` |

---

## Windows-Native Design

✅ **PowerShell 5.1+** - Compatible with both Windows PowerShell and PowerShell 7  
✅ **No WSL** - Native Windows execution  
✅ **No Bash** - Pure PowerShell implementation  
✅ **Standard APIs** - Uses Windows process and file APIs  

---

## Live Demo

A working calculator application demonstrates the full system:

```powershell
cd examples/ralph-demo

# Run the app
.\ralph-demo.ps1 -Operation add -A 5 -B 3

# Run tests
.\test.ps1

# Check the Ralph bead
cat bead-gt-demo-calc-001.json
```

All 5 unit tests pass. All 5 Ralph verifiers pass. Gate is GREEN.

---

## Next Steps

1. Read `README.md` for overview
2. Follow `QUICKSTART.md` for setup
3. Try the demo in `examples/ralph-demo/`
4. Create your first bead
5. Run `ralph-master.ps1 -Command help` for all commands

---

**Status:** ✅ Production Ready  
**Tested On:** Windows PowerShell 5.1+  
**License:** MIT  
**Repository:** https://github.com/nicklynch10/gastown-kimi
