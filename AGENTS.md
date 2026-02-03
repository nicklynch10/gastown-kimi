# Agent Instructions for Gastown-Kimi

> **For AI Agents:** This file contains everything you need to know to set up, build, and work with this Gastown-Kimi repository.

---

## Quick Start for New Agents

### 1. Repository Overview

This is **Gastown** - a GitHub Agentic Manager that orchestrates multiple AI agents (Kimi, Claude, Codex, Gemini, etc.) for software development workflows. It includes **full Kimi K2.5 Code CLI integration**.

**Key Features:**
- Multi-agent orchestration (Mayor, Witness, Refinery, Polecat, Crew roles)
- Session management and resumption
- Hook system for agent automation
- Tmux-based workspace management
- Bead tracking system for work items

### 2. Prerequisites

Before working with this codebase, ensure you have:

```bash
# Required
- Go 1.21+ (for building)
- Git
- Tmux (for session management)

# Optional but recommended
- Kimi CLI (kimi) - for Kimi agent support
- Claude CLI (claude) - for Claude agent support
```

### 3. Project Structure

```
gastown-kimi/
├── cmd/gt/              # Main CLI entry point
├── internal/
│   ├── config/          # Agent presets, runtime config (Kimi integration here)
│   ├── cmd/             # CLI commands
│   ├── polecat/         # Agent session management
│   ├── rig/             # Repository/workspace management
│   └── ...
├── scripts/             # Utility scripts
│   └── browser-gate.sh  # Browser testing gate (run this!)
├── tests/browser/       # Browser/MCP tests
│   ├── smoke.spec.js    # Smoke tests
│   └── mcp-test-runner.sh # MCP integration tests
├── docs/                # Documentation
│   ├── BROWSER_TESTING.md # Browser testing guide
│   └── ...
├── templates/           # Role templates (CLAUDE.md, etc.)
├── KIMI_INTEGRATION.md  # Detailed Kimi integration guide
└── README.md            # User documentation
```

**Key Files for Kimi Integration:**
- `internal/config/agents.go` - Agent presets including Kimi
- `internal/config/types.go` - Runtime configuration defaults
- `internal/config/agents_test.go` - Tests for Kimi integration

### 4. Building the Project

```bash
# Clone the repository
git clone https://github.com/nicklynch10/gastown-kimi.git
cd gastown-kimi

# Build the gt CLI
go build -o gt ./cmd/gt

# Or install to $GOPATH/bin
go install ./cmd/gt
```

### 5. Running Tests

```bash
# Run all tests
go test ./...

# Run only config tests
go test ./internal/config/...

# Run Kimi-specific tests
go test ./internal/config/... -v -run Kimi
```

### 6. Kimi Integration Details

The Kimi integration is **already complete** and tested. Key configurations:

**Agent Preset** (`internal/config/agents.go`):
```go
AgentKimi: {
    Name:                AgentKimi,
    Command:             "kimi",
    Args:                []string{"--yolo"},
    ProcessNames:        []string{"kimi"},
    SessionIDEnv:        "KIMI_SESSION_ID",
    ResumeFlag:          "--continue",
    ResumeStyle:         "flag",
    SupportsHooks:       true,
    SupportsForkSession: false,
}
```

**Provider Defaults** (`internal/config/types.go`):
- Command: `kimi`
- Args: `["--yolo"]`
- Session Env: `KIMI_SESSION_ID`
- Hooks Dir: `.kimi/`
- Instructions: `AGENTS.md`

### 7. Using Kimi with Gastown

```bash
# Set Kimi as default agent
gt config default-agent kimi

# Use Kimi for a specific task
gt sling <bead-id> <project> --agent kimi

# Start a crew member with Kimi
gt crew add <name> --rig <rig> --agent kimi

# Check Kimi is configured
gt config agent list
```

### 8. Development Workflow

When making changes to this codebase:

1. **Test your changes:**
   ```bash
   go test ./internal/config/... -v -run Kimi
   ```

2. **Run the smoke test:**
   ```bash
   go run smoke_test_kimi.go
   ```

3. **Verify Kimi integration:**
   ```bash
   go run kimi_full_check.go
   ```

4. **Build and verify:**
   ```bash
   go build -o gt ./cmd/gt
   ./gt version
   ```

### 9. Common Tasks

**Adding a new agent preset:**
1. Add constant to `internal/config/agents.go`
2. Add preset to `builtinPresets` map
3. Add provider defaults to `internal/config/types.go`
4. Add tests to `internal/config/agents_test.go`
5. Update documentation

**Modifying Kimi configuration:**
- Edit `internal/config/agents.go` - change the AgentKimi preset
- Update provider functions in `internal/config/types.go` if needed
- Run tests to verify

**Testing agent command generation:**
```go
// Example test pattern
rc := config.RuntimeConfigFromPreset(config.AgentKimi)
cmd := rc.BuildCommand()
// cmd should be: "kimi --yolo"
```

### 10. Testing Checklist

Before submitting changes:

- [ ] `go test ./internal/config/...` passes
- [ ] `go run smoke_test_kimi.go` passes (10/10 tests)
- [ ] `go run kimi_full_check.go` passes (29/29 tests)
- [ ] **Browser Testing Gate passes**: `./scripts/browser-gate.sh`
- [ ] Code builds without errors: `go build ./...`
- [ ] No linting errors: `golangci-lint run` (if available)

**About the Browser Testing Gate:**

The browser gate validates UI functionality using Playwright and MCP (Model Context Protocol):

```bash
# Run browser tests (recommended before commits)
./scripts/browser-gate.sh

# Quick mode (faster, smoke tests only)
./scripts/browser-gate.sh --quick

# CI mode (stricter)
./scripts/browser-gate.sh --ci
```

**What it tests:**
- Gastown binary exists and works
- CLI commands execute properly
- Agent configurations are accessible
- UI components render correctly
- Kimi integration is functional

**For fresh agents:** This is a self-contained script. Just run it and it will check/install Playwright automatically. See `docs/BROWSER_TESTING.md` for details.

### 11. Troubleshooting

**Kimi not found:**
```bash
which kimi  # or 'where kimi' on Windows
# If not found, install from https://www.kimi.com/code
```

**Tests failing:**
```bash
# Reset and try again
go clean -testcache
go test ./internal/config/... -v
```

**Build failures on Windows:**
- Some Unix-specific syscalls (syscall.Kill) may fail on Windows
- This is a known limitation - use WSL or Docker for full functionality

### 12. Key Commands Reference

```bash
# Gastown CLI commands
gt init <town-name>                    # Initialize new town
gt rig add <repo-url>                  # Add a rig (repository)
gt sling <bead-id> <project>           # Create work session
gt crew add <name> --rig <rig>         # Add crew member
gt mayor attach                        # Start mayor agent
gt config default-agent kimi           # Set Kimi as default
gt doctor                              # Check setup health

# Kimi CLI commands
kimi --version                         # Check Kimi version
kimi --yolo                            # Start in YOLO mode
kimi --continue <session>              # Resume session
```

### 13. Documentation Files

| File | Purpose |
|------|---------|
| `README.md` | Main user documentation |
| `KIMI_INTEGRATION.md` | Detailed Kimi integration guide |
| `CHANGES_SUMMARY.md` | Summary of Kimi changes |
| `FINAL_TEST_REPORT.md` | Test results and validation |
| `KIMI_SMOKE_TEST_REPORT.md` | Smoke test results |
| `AGENTS.md` | This file - for AI agents |
| `docs/BROWSER_TESTING.md` | Browser testing gate documentation |

### 14. CI/CD Gates

**Automatic gates run on every PR/push:**

1. **Unit Tests** - `go test ./...`
2. **Browser Testing Gate** - Playwright MCP tests (`.github/workflows/browser-gate.yml`)

**To view CI status:**
```bash
gh run list
gh run watch <run-id>
```

**The browser gate ensures:**
- UI functionality works correctly
- Agent configurations are accessible
- No regressions in critical paths
- Cross-platform compatibility

**If CI fails:**
1. Check the logs: `gh run view <run-id>`
2. Download artifacts: screenshots and logs
3. Fix issues locally
4. Push again

---

## Agent Context Recovery

If you lose context during a session:

```bash
# Recover context
gt prime

# Check current status
gt status

# View recent activity
gt log
```

---

## Need Help?

- Check `KIMI_INTEGRATION.md` for detailed Kimi setup
- Run `gt doctor` to diagnose setup issues
- Review `internal/config/agents_test.go` for usage examples

---

*This file is designed to be read by AI agents. It contains practical, actionable information for working with the Gastown-Kimi codebase.*

**Repository:** https://github.com/nicklynch10/gastown-kimi
