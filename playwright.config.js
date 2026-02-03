// Playwright Configuration for Gastown Browser Tests
// Designed for both CI and local development

module.exports = {
  testDir: './tests/browser',
  
  // Timeout settings
  timeout: 30000,
  expect: {
    timeout: 5000
  },
  
  // Parallel execution
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  
  // Reporting
  reporter: [
    ['line'],
    ['html', { 
      open: 'never', 
      outputFolder: './tests/browser/results' 
    }],
    ['junit', { 
      outputFile: './tests/browser/results/junit.xml' 
    }]
  ],
  
  // Test settings
  use: {
    actionTimeout: 0,
    baseURL: process.env.BASE_URL || 'http://localhost:8080',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'on-first-retry',
  },
  
  // Browser projects
  projects: [
    {
      name: 'chromium',
      use: {
        browserName: 'chromium',
        viewport: { width: 1280, height: 720 },
      },
    },
    {
      name: 'firefox',
      use: {
        browserName: 'firefox',
        viewport: { width: 1280, height: 720 },
      },
    },
    // WebKit disabled by default (requires additional dependencies)
    // {
    //   name: 'webkit',
    //   use: {
    //     browserName: 'webkit',
    //     viewport: { width: 1280, height: 720 },
    //   },
    // },
  ],
  
  // Output directories
  outputDir: './tests/browser/test-output',
  
  // Global setup/teardown
  // globalSetup: require.resolve('./tests/browser/global-setup'),
  // globalTeardown: require.resolve('./tests/browser/global-teardown'),
};
