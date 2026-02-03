# Setup Guide for Gastown-Kimi

Complete setup instructions for developers and agents working with Gastown-Kimi.

---

## Table of Contents

1. [System Requirements](#system-requirements)
2. [Quick Setup](#quick-setup)
3. [Full Installation](#full-installation)
4. [Kimi CLI Setup](#kimi-cli-setup)
5. [Verification](#verification)
6. [Development Setup](#development-setup)
7. [Troubleshooting](#troubleshooting)

---

## System Requirements

### Minimum Requirements

- **OS:** Windows 10/11, macOS 12+, or Linux (Ubuntu 20.04+)
- **Go:** Version 1.21 or later
- **Git:** Version 2.30 or later
- **Tmux:** Version 3.0 or later (required for session management)

### Recommended

- **Go:** Version 1.24+ (tested with this version)
- **Tmux:** Version 3.3+
- **Terminal:** Windows Terminal, iTerm2, or modern terminal emulator

---

## Quick Setup

For experienced developers:

```bash
# 1. Clone the repository
git clone https://github.com/nicklynch10/gastown-kimi.git
cd gastown-kimi

# 2. Build
go build -o gt ./cmd/gt

# 3. Verify
./gt version
./gt config agent list

# 4. Run Kimi tests
go test ./internal/config/... -v -run Kimi
```

---

## Full Installation

### Step 1: Install Go

**macOS:**
```bash
brew install go
```

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install golang-go
```

**Windows:**
Download from https://go.dev/dl/ and run the installer.

**Verify:**
```bash
go version
# Should show: go version go1.21+ or later
```

### Step 2: Install Tmux

**macOS:**
```bash
brew install tmux
```

**Ubuntu/Debian:**
```bash
sudo apt install tmux
```

**Windows:**
Use WSL2 or Git Bash (tmux is included).

**Verify:**
```bash
tmux -V
# Should show: tmux 3.0+
```

### Step 3: Install Kimi CLI (Optional but Recommended)

Kimi CLI is required to use Kimi as an agent in Gastown.

**macOS/Linux:**
```bash
curl -fsSL https://www.kimi.com/code/install.sh | bash
```

**Windows:**
Download from https://www.kimi.com/code and follow installation instructions.

**Verify:**
```bash
kimi --version
# Should show: kimi, version 1.x
```

### Step 4: Clone and Build Gastown-Kimi

```bash
# Clone the repository
git clone https://github.com/nicklynch10/gastown-kimi.git
cd gastown-kimi

# Build the CLI
go build -o gt ./cmd/gt

# Optional: Install to PATH
go install ./cmd/gt
# or
sudo cp gt /usr/local/bin/
```

### Step 5: Verify Installation

```bash
# Check Gastown CLI
./gt --help

# Check agent presets
./gt config agent list
# Should include: claude, gemini, codex, cursor, auggie, amp, kimi

# Check Kimi specifically
./gt config agent show kimi
```

---

## Kimi CLI Setup

### Configure Kimi for Gastown

1. **Verify Kimi is accessible:**
   ```bash
   which kimi
   kimi --version
   ```

2. **Test Kimi YOLO mode:**
   ```bash
   kimi --yolo
   # Should start Kimi in autonomous mode
   # Exit with Ctrl+C or type 'exit'
   ```

3. **Set Kimi as default agent (optional):**
   ```bash
   gt config default-agent kimi
   ```

4. **Configure per-role agents:**
   Edit `settings/config.json` in your town:
   ```json
   {
     "type": "town-settings",
     "version": 1,
     "default_agent": "claude",
     "role_agents": {
       "mayor": "kimi",
       "witness": "kimi",
       "polecat": "kimi"
     }
   }
   ```

---

## Verification

Run the verification suite:

```bash
# 1. Unit tests
go test ./internal/config/... -v -run Kimi

# 2. Smoke test (if file exists)
go run smoke_test_kimi.go

# 3. Full integration test (if file exists)
go run kimi_full_check.go

# 4. All tests
go test ./...
```

**Expected Results:**
- Unit tests: 4/4 pass
- Smoke test: 10/10 pass
- Full integration: 29/29 pass

---

## Development Setup

### For Contributors

1. **Fork and clone:**
   ```bash
   git clone https://github.com/YOUR_USERNAME/gastown-kimi.git
   cd gastown-kimi
   ```

2. **Install development tools:**
   ```bash
   # golangci-lint (optional but recommended)
   go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
   ```

3. **Run linting:**
   ```bash
   golangci-lint run
   ```

4. **Run tests before committing:**
   ```bash
   go test ./internal/config/...
   go build ./...
   ```

### Project Structure for Development

```
gastown-kimi/
├── cmd/gt/              # CLI entry point
│   └── main.go
├── internal/
│   ├── config/          # Configuration types and presets
│   │   ├── agents.go    # Agent presets (Kimi defined here)
│   │   ├── types.go     # Runtime configuration
│   │   └── agents_test.go # Tests
│   ├── cmd/             # CLI command implementations
│   ├── polecat/         # Agent management
│   ├── rig/             # Repository management
│   └── ...
├── docs/                # Documentation
└── README.md
```

### Making Changes

1. **Edit code:**
   - Agent presets: `internal/config/agents.go`
   - Provider defaults: `internal/config/types.go`
   - Tests: `internal/config/agents_test.go`

2. **Test changes:**
   ```bash
   go test ./internal/config/... -v -run Kimi
   ```

3. **Build:**
   ```bash
   go build -o gt ./cmd/gt
   ```

4. **Verify:**
   ```bash
   ./gt config agent list
   ```

---

## Troubleshooting

### Common Issues

**Issue: `go: command not found`**
```bash
# Solution: Install Go
# macOS:
brew install go

# Ubuntu:
sudo apt install golang-go

# Verify:
export PATH=$PATH:$(go env GOPATH)/bin
```

**Issue: `kimi: command not found`**
```bash
# Solution: Install Kimi CLI
# Check if installed:
which kimi

# If not found, reinstall from:
# https://www.kimi.com/code

# Add to PATH if needed:
export PATH="$HOME/.local/bin:$PATH"
```

**Issue: Build fails on Windows with syscall errors**
```
undefined: syscall.Kill
```
**Solution:** This is a known limitation. The tmux package uses Unix-specific syscalls. Use one of:
- WSL2 (Windows Subsystem for Linux)
- Docker container with Linux
- Virtual machine with Linux

**Issue: Tests fail**
```bash
# Clear test cache
go clean -testcache

# Run verbose tests
go test ./internal/config/... -v

# Check specific test
go test ./internal/config/... -v -run TestKimiAgentPreset
```

**Issue: `gt: command not found`**
```bash
# Solution: Either use ./gt or install to PATH
./gt --help

# Or install:
go install ./cmd/gt
# or
sudo cp gt /usr/local/bin/
```

### Getting Help

1. **Check the docs:**
   - `README.md` - User documentation
   - `KIMI_INTEGRATION.md` - Kimi-specific guide
   - `AGENTS.md` - Agent/developer guide

2. **Run diagnostics:**
   ```bash
   ./gt doctor
   ```

3. **Check GitHub:**
   - Repository: https://github.com/nicklynch10/gastown-kimi
   - Issues: Check for similar problems

---

## Next Steps

After setup:

1. **Read the README** for usage instructions
2. **Check KIMI_INTEGRATION.md** for Kimi-specific features
3. **Run `gt --help`** to see available commands
4. **Initialize a town** to start using Gastown:
   ```bash
   gt init my-town
   ```

---

## Ralph-Gastown Integration Setup

For Ralph-specific setup instructions, see:
- **QUICKSTART.md** - Quick start guide for Ralph-Gastown
- **README.md** - Main documentation
- **QUICK_REFERENCE.md** - One-page command reference

### Quick Ralph Setup

```powershell
# After Gastown is set up, initialize Ralph:
.\scripts\ralph\ralph-master.ps1 -Command init

# Verify installation:
.\scripts\ralph\ralph-master.ps1 -Command verify

# See QUICKSTART.md for full instructions
```

**Repository:** https://github.com/nicklynch10/gastown-kimi
