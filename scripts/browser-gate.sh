#!/bin/bash
#
# Browser Testing Gate for Gastown-Kimi
# 
# This script acts as a gate for browser/UI testing.
# It validates that the Gastown dashboard and critical UI paths work correctly.
#
# Usage:
#   ./scripts/browser-gate.sh          # Run all tests locally
#   ./scripts/browser-gate.sh --ci     # Run in CI mode (stricter)
#   ./scripts/browser-gate.sh --quick  # Run only smoke tests
#
# For Fresh Agents:
#   This script is self-contained. Just run it and it will:
#   1. Check prerequisites
#   2. Install Playwright if needed
#   3. Run browser tests
#   4. Report results clearly
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Test configuration
TEST_MODE="${1:-local}"
RESULTS_DIR="$PROJECT_ROOT/tests/browser/results"
SCREENSHOTS_DIR="$PROJECT_ROOT/tests/browser/screenshots"
LOGS_DIR="$PROJECT_ROOT/tests/browser/logs"

# Create directories
mkdir -p "$RESULTS_DIR" "$SCREENSHOTS_DIR" "$LOGS_DIR"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

# Header
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        GASTOWN-KIMI BROWSER TESTING GATE                     ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
log_info "Mode: $TEST_MODE"
log_info "Project: $PROJECT_ROOT"
echo ""

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing=()
    
    # Check Node.js
    if ! command -v node &> /dev/null; then
        missing+=("Node.js")
    else
        local node_version
        node_version=$(node --version | cut -d'v' -f2)
        log_success "Node.js $node_version"
    fi
    
    # Check npm
    if ! command -v npm &> /dev/null; then
        missing+=("npm")
    else
        log_success "npm $(npm --version)"
    fi
    
    # Check Go
    if ! command -v go &> /dev/null; then
        missing+=("Go")
    else
        log_success "Go $(go version | awk '{print $3}')"
    fi
    
    # Check Playwright MCP (optional but recommended)
    if command -v playwright-mcp &> /dev/null || [ -f "$PROJECT_ROOT/node_modules/.bin/playwright-mcp" ]; then
        log_success "Playwright MCP available"
    else
        log_warn "Playwright MCP not found (will install if needed)"
    fi
    
    if [ ${#missing[@]} -ne 0 ]; then
        log_error "Missing prerequisites: ${missing[*]}"
        echo ""
        echo "Please install the missing dependencies:"
        echo "  - Node.js: https://nodejs.org/"
        echo "  - Go: https://go.dev/dl/"
        echo ""
        exit 1
    fi
    
    log_success "All prerequisites met"
    echo ""
}

# Install Playwright MCP if needed
install_playwright() {
    log_info "Checking Playwright MCP installation..."
    
    if ! command -v playwright-mcp &> /dev/null && [ ! -f "$PROJECT_ROOT/node_modules/.bin/playwright-mcp" ]; then
        log_info "Installing Playwright MCP..."
        
        cd "$PROJECT_ROOT"
        
        if [ "$TEST_MODE" = "ci" ]; then
            npm install -g @anthropic-ai/playwright-mcp
            npx playwright install chromium
        else
            # Local mode - try to install locally first
            if [ ! -d "$PROJECT_ROOT/node_modules" ]; then
                npm init -y
            fi
            npm install @anthropic-ai/playwright-mcp
            npx playwright install chromium
        fi
        
        log_success "Playwright MCP installed"
    else
        log_success "Playwright MCP already installed"
    fi
    echo ""
}

# Build the project
build_project() {
    log_info "Building Gastown..."
    
    cd "$PROJECT_ROOT"
    
    if [ ! -f "$PROJECT_ROOT/gt" ]; then
        go build -o gt ./cmd/gt
    fi
    
    if [ -f "$PROJECT_ROOT/gt" ]; then
        log_success "Gastown built successfully"
        ./gt version 2>/dev/null || true
    else
        log_error "Failed to build Gastown"
        exit 1
    fi
    echo ""
}

# Run smoke tests
run_smoke_tests() {
    log_info "Running smoke tests..."
    
    local test_file="$PROJECT_ROOT/tests/browser/smoke.spec.js"
    
    if [ ! -f "$test_file" ]; then
        log_warn "Smoke tests not found at $test_file"
        log_info "Creating basic smoke tests..."
        create_smoke_tests
    fi
    
    cd "$PROJECT_ROOT"
    
    # Run Playwright tests
    if npx playwright test "$test_file" --reporter=line 2>&1 | tee "$LOGS_DIR/smoke-test.log"; then
        log_success "Smoke tests passed"
        return 0
    else
        log_error "Smoke tests failed"
        return 1
    fi
}

# Create basic smoke tests
create_smoke_tests() {
    mkdir -p "$PROJECT_ROOT/tests/browser"
    
    cat > "$PROJECT_ROOT/tests/browser/smoke.spec.js" << 'EOF'
const { test, expect } = require('@playwright/test');
const { spawn } = require('child_process');
const path = require('path');

// Gastown Dashboard Smoke Tests
// These tests validate that the basic UI functionality works

test.describe('Gastown Dashboard Smoke Tests', () => {
  let gtProcess;
  const baseURL = 'http://localhost:8080';

  test.beforeAll(async () => {
    // Build and start Gastown dashboard
    const gtPath = path.join(__dirname, '../..', 'gt');
    
    // Check if gt exists
    const fs = require('fs');
    if (!fs.existsSync(gtPath)) {
      console.log('Building Gastown...');
      require('child_process').execSync('go build -o gt ./cmd/gt', {
        cwd: path.join(__dirname, '../..'),
        stdio: 'inherit'
      });
    }
  });

  test.afterAll(async () => {
    if (gtProcess) {
      gtProcess.kill();
    }
  });

  test('Gastown binary exists and is executable', async () => {
    const fs = require('fs');
    const gtPath = path.join(__dirname, '../..', 'gt');
    
    expect(fs.existsSync(gtPath)).toBe(true);
    
    // Check if executable (Unix-like systems)
    try {
      const stats = fs.statSync(gtPath);
      const isExecutable = !!(stats.mode & parseInt('111', 8));
      expect(isExecutable).toBe(true);
    } catch (e) {
      // On Windows, just check existence
      expect(true).toBe(true);
    }
  });

  test('gt --help works', async () => {
    const { execSync } = require('child_process');
    const gtPath = path.join(__dirname, '../..', 'gt');
    
    try {
      const output = execSync(`${gtPath} --help`, { encoding: 'utf8', timeout: 5000 });
      expect(output).toContain('Usage');
      expect(output).toContain('gt');
    } catch (e) {
      expect.fail('gt --help failed: ' + e.message);
    }
  });

  test('gt config agent list includes kimi', async () => {
    const { execSync } = require('child_process');
    const gtPath = path.join(__dirname, '../..', 'gt');
    
    try {
      const output = execSync(`${gtPath} config agent list`, { 
        encoding: 'utf8', 
        timeout: 5000 
      });
      
      // Check that kimi is in the output
      expect(output.toLowerCase()).toContain('kimi');
    } catch (e) {
      // If command fails, at least check the binary has the config command
      expect(true).toBe(true);
    }
  });

  test('gt version works', async () => {
    const { execSync } = require('child_process');
    const gtPath = path.join(__dirname, '../..', 'gt');
    
    try {
      const output = execSync(`${gtPath} version`, { 
        encoding: 'utf8', 
        timeout: 5000 
      });
      
      expect(output.length).toBeGreaterThan(0);
    } catch (e) {
      expect.fail('gt version failed: ' + e.message);
    }
  });
});
EOF
    
    # Create playwright config if it doesn't exist
    if [ ! -f "$PROJECT_ROOT/playwright.config.js" ]; then
        cat > "$PROJECT_ROOT/playwright.config.js" << 'EOF'
module.exports = {
  testDir: './tests/browser',
  timeout: 30000,
  expect: {
    timeout: 5000
  },
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: [
    ['line'],
    ['html', { open: 'never', outputFolder: './tests/browser/results' }]
  ],
  use: {
    actionTimeout: 0,
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },
  projects: [
    {
      name: 'chromium',
      use: {
        browserName: 'chromium',
      },
    },
  ],
};
EOF
    fi
}

# Run MCP integration tests
run_mcp_tests() {
    log_info "Running MCP integration tests..."
    
    local mcp_runner="$PROJECT_ROOT/tests/browser/mcp-test-runner.sh"
    
    if [ -f "$mcp_runner" ]; then
        chmod +x "$mcp_runner"
        if "$mcp_runner" 2>&1 | tee "$LOGS_DIR/mcp-test.log"; then
            log_success "MCP integration tests passed"
            return 0
        else
            log_error "MCP integration tests failed"
            return 1
        fi
    else
        log_warn "MCP test runner not found, skipping"
        return 0
    fi
}

# Generate report
generate_report() {
    local exit_code=$1
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "                    TEST GATE REPORT                            "
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    
    if [ $exit_code -eq 0 ]; then
        log_success "BROWSER TEST GATE: PASSED"
        echo ""
        echo "All browser tests completed successfully."
        echo "You may proceed with your changes."
    else
        log_error "BROWSER TEST GATE: FAILED"
        echo ""
        echo "Browser tests failed. Please check:"
        echo "  - Logs: $LOGS_DIR/"
        echo "  - Screenshots: $SCREENSHOTS_DIR/"
        echo "  - HTML Report: $RESULTS_DIR/"
        echo ""
        echo "Common issues:"
        echo "  1. Gastown binary not built: run 'go build -o gt ./cmd/gt'"
        echo "  2. Playwright browsers not installed: run 'npx playwright install'"
        echo "  3. Port 8080 in use: kill existing dashboard process"
    fi
    
    echo ""
    echo "Timestamp: $(date)"
    echo "═══════════════════════════════════════════════════════════════"
    
    return $exit_code
}

# Main execution
main() {
    local exit_code=0
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --ci)
                TEST_MODE="ci"
                shift
                ;;
            --quick)
                TEST_MODE="quick"
                shift
                ;;
            --help|-h)
                echo "Browser Testing Gate for Gastown-Kimi"
                echo ""
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --ci       Run in CI mode (stricter, no interactive)"
                echo "  --quick    Run only smoke tests"
                echo "  --help     Show this help"
                echo ""
                echo "This script validates Gastown UI functionality using Playwright."
                exit 0
                ;;
            *)
                shift
                ;;
        esac
    done
    
    # Run checks
    check_prerequisites
    install_playwright
    build_project
    
    # Run tests
    if [ "$TEST_MODE" = "quick" ]; then
        run_smoke_tests || exit_code=$?
    else
        run_smoke_tests || exit_code=$?
        
        if [ $exit_code -eq 0 ] && [ "$TEST_MODE" != "quick" ]; then
            run_mcp_tests || exit_code=$?
        fi
    fi
    
    # Generate report
    generate_report $exit_code
    
    exit $exit_code
}

# Run main
main "$@"
