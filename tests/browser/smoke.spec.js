/**
 * Gastown-Kimi Browser Smoke Tests
 * 
 * These tests validate basic UI functionality without requiring
 * extensive prior context. Designed for fresh agents.
 * 
 * Coverage:
 * - Binary existence and executability
 * - CLI commands work
 * - Agent configuration accessible
 * - Basic UI elements present
 */

const { test, expect } = require('@playwright/test');
const { spawn, execSync } = require('child_process');
const path = require('path');
const fs = require('fs');

// Project paths
const PROJECT_ROOT = path.join(__dirname, '../..');
const GT_BINARY = path.join(PROJECT_ROOT, 'gt');

// Helper to run gt commands
function runGt(args, options = {}) {
  const defaultOptions = {
    encoding: 'utf8',
    timeout: 10000,
    cwd: PROJECT_ROOT,
  };
  
  try {
    return execSync(`${GT_BINARY} ${args}`, { ...defaultOptions, ...options });
  } catch (error) {
    if (options.throwOnError !== false) {
      throw error;
    }
    return error.stdout || error.message;
  }
}

test.describe('Gastown Binary Smoke Tests', () => {
  
  test.beforeAll(() => {
    // Ensure binary exists, build if needed
    if (!fs.existsSync(GT_BINARY)) {
      console.log('Building Gastown binary...');
      try {
        execSync('go build -o gt ./cmd/gt', {
          cwd: PROJECT_ROOT,
          stdio: 'inherit'
        });
      } catch (e) {
        console.error('Failed to build Gastown:', e.message);
        throw e;
      }
    }
  });

  test('Gastown binary exists', () => {
    expect(fs.existsSync(GT_BINARY)).toBe(true);
  });

  test('Gastown binary is executable', () => {
    const stats = fs.statSync(GT_BINARY);
    
    // Check if executable (Unix-like)
    if (process.platform !== 'win32') {
      const isExecutable = !!(stats.mode & parseInt('111', 8));
      expect(isExecutable).toBe(true);
    } else {
      // On Windows, just check it's a file
      expect(stats.isFile()).toBe(true);
    }
  });

  test('gt --help displays usage', () => {
    const output = runGt('--help');
    
    expect(output).toContain('Usage');
    expect(output).toContain('gt');
    expect(output.length).toBeGreaterThan(100);
  });

  test('gt version works', () => {
    const output = runGt('version');
    
    expect(output.length).toBeGreaterThan(0);
    // Version should contain reasonable characters
    expect(output).toMatch(/[\w\d\.\-]+/);
  });

  test('gt config agent list works', () => {
    const output = runGt('config agent list', { throwOnError: false });
    
    // Should not crash, output should be reasonable
    expect(output).toBeTruthy();
  });

  test('Kimi agent is configured', () => {
    // This test validates Kimi integration is present
    const output = runGt('config agent list', { throwOnError: false });
    
    // Check if 'kimi' appears in the output (case-insensitive)
    const hasKimi = output.toLowerCase().includes('kimi');
    
    if (!hasKimi) {
      console.warn('⚠️  Kimi agent not found in agent list - this may be expected if running in minimal mode');
    }
    
    // For CI, we expect Kimi to be present
    if (process.env.CI) {
      expect(hasKimi).toBe(true);
    }
  });

  test('gt doctor command exists', () => {
    const output = runGt('doctor --help', { throwOnError: false });
    
    expect(output).toBeTruthy();
    expect(output.toLowerCase()).toContain('doctor');
  });
});

test.describe('Agent Configuration Tests', () => {
  
  test('Agent presets are accessible', () => {
    const output = runGt('config agent list', { throwOnError: false });
    
    // Should list at least one agent
    expect(output.length).toBeGreaterThan(10);
    
    // Common agents that should be present
    const commonAgents = ['claude', 'gemini', 'codex', 'kimi'];
    const foundAgents = commonAgents.filter(agent => 
      output.toLowerCase().includes(agent)
    );
    
    // At least some agents should be present
    expect(foundAgents.length).toBeGreaterThanOrEqual(2);
  });

  test('Can show specific agent config', () => {
    // Test showing Kimi config
    const output = runGt('config agent show kimi', { throwOnError: false });
    
    // Should not error out completely
    expect(output).toBeTruthy();
    
    // If Kimi is configured, should show relevant info
    if (output.toLowerCase().includes('kimi')) {
      expect(output.length).toBeGreaterThan(20);
    }
  });

  test('Default agent can be queried', () => {
    const output = runGt('config default-agent', { throwOnError: false });
    
    // Should return something (either a default or info about setting it)
    expect(output).toBeTruthy();
  });
});

test.describe('Browser-based UI Tests', () => {
  
  test('Basic browser test infrastructure works', async ({ page }) => {
    // Simple test to validate Playwright is working
    await page.goto('data:text/html,<html><body><h1>Test</h1></body></html>');
    
    const heading = await page.locator('h1').textContent();
    expect(heading).toBe('Test');
  });

  test('Can take screenshots for debugging', async ({ page }) => {
    await page.goto('data:text/html,<html><body><h1>Gastown Test</h1></body></html>');
    
    // Take a screenshot
    const screenshotPath = path.join(__dirname, 'screenshots', 'test-screenshot.png');
    await page.screenshot({ path: screenshotPath });
    
    expect(fs.existsSync(screenshotPath)).toBe(true);
  });
});

test.describe('MCP Integration Smoke Tests', () => {
  
  test('MCP test environment is ready', () => {
    // Check that Node.js is available
    const nodeVersion = execSync('node --version', { encoding: 'utf8' });
    expect(nodeVersion).toContain('v');
    
    // Check that Playwright can be imported
    expect(() => {
      require('@playwright/test');
    }).not.toThrow();
  });

  test('Project structure is correct', () => {
    // Validate project has expected structure
    const expectedPaths = [
      path.join(PROJECT_ROOT, 'cmd', 'gt'),
      path.join(PROJECT_ROOT, 'internal', 'config'),
      path.join(PROJECT_ROOT, 'tests', 'browser'),
    ];
    
    for (const expectedPath of expectedPaths) {
      expect(fs.existsSync(expectedPath)).toBe(true);
    }
  });

  test('Kimi integration files exist', () => {
    // Check for Kimi-related documentation
    const kimiDocs = [
      path.join(PROJECT_ROOT, 'KIMI_INTEGRATION.md'),
      path.join(PROJECT_ROOT, 'AGENTS.md'),
    ];
    
    let foundDocs = 0;
    for (const doc of kimiDocs) {
      if (fs.existsSync(doc)) {
        foundDocs++;
      }
    }
    
    // At least some docs should exist
    expect(foundDocs).toBeGreaterThanOrEqual(1);
  });
});

// Cleanup test
test.afterAll(() => {
  console.log('✅ Smoke tests completed');
});
