# Browser Testing Gate Documentation

> **For AI Agents:** This guide explains the browser testing gate system and how to use it.

---

## Overview

The browser testing gate validates Gastown's UI functionality using Playwright and MCP (Model Context Protocol). It ensures that:

1. The Gastown binary works correctly
2. CLI commands execute properly
3. Agent configurations are accessible
4. UI components render correctly

**Why this matters:** This gate prevents broken changes from reaching production by catching UI/regression issues early.

---

## Quick Start for Fresh Agents

### Prerequisites
```bash
# Ensure you have Node.js 18+ installed
node --version  # Should show v18 or higher

# Install Playwright browsers
npx playwright install chromium
```

### Run the Gate Locally
```bash
# From project root
./scripts/browser-gate.sh
```

### Run in CI Mode (Stricter)
```bash
./scripts/browser-gate.sh --ci
```

### Run Quick Smoke Tests Only
```bash
./scripts/browser-gate.sh --quick
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    BROWSER TEST GATE                         │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────┐      ┌──────────────┐                     │
│  │   GitHub     │      │   Local      │                     │
│  │   Actions    │      │   Script     │                     │
│  │   (CI Gate)  │      │   (Dev Gate) │                     │
│  └──────┬───────┘      └──────┬───────┘                     │
│         │                     │                             │
│         └──────────┬──────────┘                             │
│                    │                                         │
│         ┌──────────▼──────────┐                             │
│         │  browser-gate.sh    │                             │
│         │  (Orchestrator)     │                             │
│         └──────────┬──────────┘                             │
│                    │                                         │
│     ┌──────────────┼──────────────┐                        │
│     │              │              │                        │
│ ┌───▼───┐    ┌────▼────┐   ┌────▼────┐                   │
│ │ Smoke │    │  MCP    │   │ Agent   │                   │
│ │ Tests │    │  Tests  │   │ Config  │                   │
│ └───┬───┘    └────┬────┘   └────┬────┘                   │
│     │             │             │                        │
│     └─────────────┴─────────────┘                        │
│                   │                                        │
│          ┌────────▼────────┐                              │
│          │  Test Results   │                              │
│          │  (Pass/Fail)    │                              │
│          └─────────────────┘                              │
│                                                          │
└─────────────────────────────────────────────────────────────┘
```

---

## Gate Components

### 1. CI Gate (`.github/workflows/browser-gate.yml`)

**When it runs:**
- On every push to `main` or `develop`
- On every pull request to `main`
- Can be triggered manually (`workflow_dispatch`)

**What it does:**
1. Sets up Go, Node.js, and dependencies
2. Builds Gastown binary
3. Installs Playwright and browsers
4. Runs browser tests
5. Uploads test artifacts (screenshots, logs)
6. Comments results on PRs

**Pass criteria:**
- All smoke tests pass
- MCP integration tests pass
- No critical failures

### 2. Local Gate (`scripts/browser-gate.sh`)

**When to run:**
- Before committing changes
- When modifying UI-related code
- When adding new agent presets
- When updating dependencies

**Features:**
- Self-contained (installs Playwright if needed)
- Clear pass/fail reporting
- Helpful error messages for common issues
- Three modes: `local`, `ci`, `quick`

### 3. Test Files (`tests/browser/`)

| File | Purpose |
|------|---------|
| `smoke.spec.js` | Basic functionality tests |
| `mcp-test-runner.sh` | MCP integration tests |
| `screenshots/` | Failure screenshots |
| `results/` | Test reports |
| `logs/` | Execution logs |

---

## Test Categories

### Smoke Tests

Fast tests that validate basic functionality:

```javascript
// Examples from smoke.spec.js
test('Gastown binary exists', () => { ... });
test('gt --help displays usage', () => { ... });
test('Kimi agent is configured', () => { ... });
```

**Runtime:** ~10-15 seconds  
**When to run:** Always, before any commit

### MCP Integration Tests

Tests that use AI-driven browser automation:

```bash
# Run MCP tests
./tests/browser/mcp-test-runner.sh
```

**Runtime:** ~20-30 seconds  
**When to run:** When modifying agent configuration or UI

### Full Browser Tests

Comprehensive UI testing (when dashboard is available):

```bash
# Start dashboard first
./gt dashboard --port 8080 &

# Run tests
npx playwright test tests/browser/
```

**Runtime:** ~30-60 seconds  
**When to run:** Before major releases, full regression testing

---

## For Fresh Agents: Understanding the Gate

### What is a "Gate"?

A gate is a checkpoint that **blocks progression** if conditions aren't met. Think of it like:
- A security checkpoint at an airport
- A code review before merging
- A test suite that must pass

**In this project:**
- The browser gate prevents broken UI changes from being merged
- It runs automatically on PRs
- You can (and should) run it locally before pushing

### Why MCP (Model Context Protocol)?

MCP allows AI agents to control browsers programmatically. This means:
- Tests can be written in natural language
- AI can explore the UI dynamically
- Less brittle than traditional selectors

**Example MCP test flow:**
1. AI opens browser
2. Navigates to Gastown dashboard
3. Clicks "Agents" menu
4. Verifies Kimi is in the list
5. Takes screenshot for proof

### Minimal Context Required

Fresh agents only need to know:

1. **How to run the gate:**
   ```bash
   ./scripts/browser-gate.sh
   ```

2. **What success looks like:**
   ```
   ✅ BROWSER TEST GATE: PASSED
   ```

3. **What failure looks like:**
   ```
   ❌ BROWSER TEST GATE: FAILED
   Logs: tests/browser/logs/
   ```

4. **Where to get help:**
   - Check `tests/browser/logs/` for details
   - Read this document
   - Run with `--help` for options

---

## Common Issues & Solutions

### Issue: "Playwright not found"
```
[WARN] Playwright MCP not found (will install if needed)
```

**Solution:** The script will auto-install. If it fails:
```bash
npm install -g @anthropic-ai/playwright-mcp
npx playwright install chromium
```

### Issue: "Gastown binary not found"
```
❌ FAIL: Gastown binary not found
```

**Solution:** Build it first
```bash
go build -o gt ./cmd/gt
```

### Issue: Tests fail in CI but pass locally

**Possible causes:**
1. Environment differences (Linux vs macOS/Windows)
2. Missing environment variables
3. Different Node.js versions

**Solution:**
- Check CI logs for specific errors
- Ensure all env vars are set in workflow
- Use `nvm` or similar to match Node versions

### Issue: Screenshot tests fail

**Solution:**
- Screenshots are saved to `tests/browser/screenshots/`
- Compare with baseline images
- Update baselines if UI intentionally changed

---

## Integration with Development Workflow

### Recommended Workflow

```bash
# 1. Make your changes
# ... edit code ...

# 2. Run unit tests
go test ./internal/config/...

# 3. Run browser gate
./scripts/browser-gate.sh

# 4. If all pass, commit
git add .
git commit -m "feat: your changes"

# 5. Push (CI gate will run automatically)
git push origin main
```

### Git Hook Integration (Optional)

Add to `.git/hooks/pre-commit`:
```bash
#!/bin/bash
./scripts/browser-gate.sh --quick
exit $?
```

This runs quick tests before every commit.

---

## CI/CD Integration

### GitHub Actions

Already configured in `.github/workflows/browser-gate.yml`:

```yaml
on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]
```

### Other CI Systems

**GitLab CI:**
```yaml
browser-tests:
  script:
    - apt-get install -y nodejs npm tmux
    - npm install -g @anthropic-ai/playwright-mcp
    - npx playwright install chromium
    - go build -o gt ./cmd/gt
    - ./scripts/browser-gate.sh --ci
```

**CircleCI:**
```yaml
jobs:
  browser-tests:
    steps:
      - run:
          command: |
            ./scripts/browser-gate.sh --ci
```

---

## Extending the Tests

### Adding New Smoke Tests

Edit `tests/browser/smoke.spec.js`:

```javascript
test('your new test', () => {
  // Your test code
  const output = runGt('your command');
  expect(output).toContain('expected text');
});
```

### Adding MCP Tests

Edit `tests/browser/mcp-test-runner.sh`:

```bash
echo "[TEST] Your new MCP test"
node << 'NODE_SCRIPT'
// Your MCP test code
NODE_SCRIPT
```

### Adding Browser Tests

Create new file in `tests/browser/`:

```javascript
const { test, expect } = require('@playwright/test');

test('your browser test', async ({ page }) => {
  await page.goto('http://localhost:8080');
  // ... test code ...
});
```

---

## Artifacts & Debugging

### Test Artifacts Location

```
tests/browser/
├── results/        # HTML test reports
├── screenshots/    # Failure screenshots
├── logs/          # Execution logs
└── mcp-results/   # MCP test outputs
```

### Reading Test Reports

**HTML Report:**
```bash
npx playwright show-report tests/browser/results
```

**Logs:**
```bash
cat tests/browser/logs/smoke-test.log
```

### Getting Help

1. Check the logs: `tests/browser/logs/`
2. Run with verbose output: `./scripts/browser-gate.sh 2>&1 | tee debug.log`
3. Review screenshots: `tests/browser/screenshots/`

---

## Summary for Fresh Agents

**To use the browser testing gate:**

1. **Build the project:**
   ```bash
   go build -o gt ./cmd/gt
   ```

2. **Run the gate:**
   ```bash
   ./scripts/browser-gate.sh
   ```

3. **Check results:**
   - ✅ PASSED = Continue with your work
   - ❌ FAILED = Fix issues, check logs

4. **When to run:**
   - Before committing UI changes
   - When modifying agent configurations
   - Before creating pull requests

**Remember:** The gate is your friend—it catches issues before they reach production!

---

## Related Documentation

- `SETUP.md` - Full setup instructions
- `AGENTS.md` - Agent/developer guide
- `KIMI_INTEGRATION.md` - Kimi-specific details
- `playwright.config.js` - Test configuration
- `.github/workflows/browser-gate.yml` - CI configuration
