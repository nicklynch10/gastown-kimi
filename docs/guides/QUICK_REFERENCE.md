# Ralph-Gastown Quick Reference

One-page reference for common tasks.

## Setup (One-Time)

```powershell
# Install prerequisites
go install github.com/nicklynch10/gastown-cli/cmd/gt@latest
# Beads CLI (bd) is OPTIONAL - Ralph works without it

# Install Kimi from https://www.kimi.com/code

# Clone and initialize
git clone https://github.com/nicklynch10/gastown-kimi.git
cd gastown-kimi
.\scripts\ralph\ralph-master.ps1 -Command init
```

## Daily Commands

### Create Work

```powershell
# Create a Ralph bead
.\scripts\ralph\ralph-master.ps1 -Command create-bead `
    -Intent "Fix login bug" -Rig myproject

# Create a gate
.\scripts\ralph\ralph-master.ps1 -Command create-gate `
    -Type test -Convoy convoy-123
```

### Execute Work

```powershell
# Run Ralph executor
.\scripts\ralph\ralph-master.ps1 -Command run -Bead gt-abc12

# Or direct
.\scripts\ralph\ralph-executor-simple.ps1 -BeadId gt-abc12
```

### Monitor

```powershell
# Check status
.\scripts\ralph\ralph-master.ps1 -Command status

# Check gates
.\scripts\ralph\ralph-master.ps1 -Command govern

# Start watchdog (in separate window)
.\scripts\ralph\ralph-master.ps1 -Command watchdog
```

## Bead Structure

```json
{
  "intent": "What to implement",
  "dod": {
    "verifiers": [
      {"name": "Tests", "command": "go test ./...", "expect": {"exit_code": 0}}
    ]
  },
  "constraints": {"max_iterations": 10}
}
```

## File Locations

| Component | Location |
|-----------|----------|
| Main script | `scripts/ralph/ralph-master.ps1` |
| Executor | `scripts/ralph/ralph-executor-simple.ps1` |
| Governor | `scripts/ralph/ralph-governor.ps1` |
| Watchdog | `scripts/ralph/ralph-watchdog.ps1` |
| Formulas | `.beads/formulas/molecule-ralph-*.toml` |
| Demo app | `examples/ralph-demo/` |

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "gt not found" | `go install github.com/nicklynch10/gastown-cli/cmd/gt@latest` |
| "bd not found" | OPTIONAL - Ralph works in standalone mode without bd |
| "cannot run scripts" | `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser` |
| "kimi not found" | Install from https://www.kimi.com/code |

## Documentation

- **README.md** - Start here
- **QUICKSTART.md** - Detailed setup
- **RALPH_INTEGRATION.md** - Architecture details
- **AGENTS.md** - Development guide

## Example Workflow

```powershell
# 1. Create bead
.\scripts\ralph\ralph-master.ps1 -Command create-bead `
    -Intent "Add user auth" -Rig myapp

# 2. Work is automatically slung to Kimi
# Kimi implements with Ralph retry loop

# 3. Check result
bd show gt-abc12
.\scripts\ralph\ralph-master.ps1 -Command govern
```
