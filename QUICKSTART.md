# Gastown-Kimi Quickstart

**One-page reference for getting started quickly.**

---

## Install

```bash
# 1. Clone
git clone https://github.com/nicklynch10/gastown-kimi.git
cd gastown-kimi

# 2. Build
go build -o gt ./cmd/gt

# 3. Verify
./gt config agent list
```

---

## Verify Kimi Integration

```bash
# Run Kimi tests
go test ./internal/config/... -v -run Kimi

# Should output:
# === RUN   TestKimiAgentPreset
# --- PASS: TestKimiAgentPreset
# === RUN   TestKimiProviderDefaults
# --- PASS: TestKimiProviderDefaults
# ... (4 tests total)
```

---

## Use Kimi with Gastown

```bash
# Set Kimi as default agent
./gt config default-agent kimi

# Use for specific task
./gt sling <bead-id> <project> --agent kimi

# Start crew member with Kimi
./gt crew add <name> --rig <rig> --agent kimi
```

---

## Key Files

| File | What It Contains |
|------|------------------|
| `internal/config/agents.go` | AgentKimi preset definition |
| `internal/config/types.go` | Kimi provider defaults |
| `internal/config/agents_test.go` | Kimi tests |
| `KIMI_INTEGRATION.md` | Detailed Kimi guide |
| `AGENTS.md` | Agent/developer guide |
| `SETUP.md` | Full installation guide |

---

## Common Commands

```bash
# Build
go build -o gt ./cmd/gt

# Test
go test ./internal/config/... -v -run Kimi

# Check agents
./gt config agent list

# Set default agent
./gt config default-agent kimi
```

---

## Kimi Configuration

**Preset:**
- Command: `kimi`
- Args: `--yolo`
- Session Env: `KIMI_SESSION_ID`
- Resume: `--continue`
- Hooks: `.kimi/settings.json`

**Test:**
```bash
kimi --version  # Should be v1.3+
```

---

## Need Help?

1. Read `AGENTS.md` - Complete agent guide
2. Read `SETUP.md` - Full setup instructions
3. Read `KIMI_INTEGRATION.md` - Kimi details
4. Run `./gt doctor` - Diagnose issues

---

**Repository:** https://github.com/nicklynch10/gastown-kimi
