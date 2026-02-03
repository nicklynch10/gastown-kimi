# Ralph Browser Testing Module
# Context-efficient browser testing for Ralph-Gastown
# 
# Design Principles:
# 1. Browser runs in isolated process/context
# 2. Only test results and artifacts come back to main context
# 3. Supports both Playwright and Chrome DevTools Protocol
# 4. Optimized for long-running automated SDLC

$script:BrowserDefaults = @{
    DefaultTimeout = 30000
    NavigationTimeout = 30000
    ScreenshotDir = ".ralph/evidence/screenshots"
    TraceDir = ".ralph/evidence/traces"
    Headless = $true
}

#region Context-Efficient Browser Operations

function New-BrowserTestContext {
    <#
    .SYNOPSIS
        Creates a new browser test context optimized for Ralph workflows.
    
    .DESCRIPTION
        Returns a configuration object for browser testing. The actual browser
        runs in an isolated process - only the config is in the main context.
    
    .PARAMETER TestName
        Name of the test (used for artifact naming)
    
    .PARAMETER BaseUrl
        Base URL for the application under test
    
    .PARAMETER BrowserType
        Browser to use: chromium, firefox, webkit
    
    .PARAMETER Headless
        Run in headless mode (default: true for SDLC automation)
    
    .PARAMETER Viewport
        Viewport size (default: 1920x1080)
    
    .EXAMPLE
        $ctx = New-BrowserTestContext -TestName "login-flow" -BaseUrl "http://localhost:3000"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TestName,
        
        [Parameter(Mandatory = $true)]
        [string]$BaseUrl,
        
        [Parameter()]
        [ValidateSet("chromium", "firefox", "webkit")]
        [string]$BrowserType = "chromium",
        
        [Parameter()]
        [bool]$Headless = $true,
        
        [Parameter()]
        [hashtable]$Viewport = @{ width = 1920; height = 1080 },
        
        [Parameter()]
        [string]$EvidenceDir = ".ralph/evidence"
    )
    
    # Create evidence directories
    $screenshotDir = Join-Path $EvidenceDir "screenshots"
    $traceDir = Join-Path $EvidenceDir "traces"
    $harDir = Join-Path $EvidenceDir "har"
    
    New-Item -ItemType Directory -Force -Path $screenshotDir | Out-Null
    New-Item -ItemType Directory -Force -Path $traceDir | Out-Null
    New-Item -ItemType Directory -Force -Path $harDir | Out-Null
    
    # Generate unique run ID
    $runId = "$(Get-Date -Format 'yyyyMMdd-HHmmss')-$([Guid]::NewGuid().ToString().Substring(0,8))"
    
    return [PSCustomObject]@{
        TestName = $TestName
        BaseUrl = $BaseUrl
        BrowserType = $BrowserType
        Headless = $Headless
        Viewport = $Viewport
        RunId = $runId
        ScreenshotDir = $screenshotDir
        TraceDir = $traceDir
        HarDir = $harDir
        StartTime = Get-Date
        Artifacts = @()
    }
}

function Invoke-BrowserTest {
    <#
    .SYNOPSIS
        Runs a browser test in an isolated process.
    
    .DESCRIPTION
        Executes browser tests using Playwright in a separate process.
        Only test results and artifact paths return to the main context.
    
    .PARAMETER Context
        Browser test context from New-BrowserTestContext
    
    .PARAMETER TestScript
        Path to the Playwright test script OR script block content
    
    .PARAMETER Timeout
        Maximum test duration in seconds (default: 120)
    
    .EXAMPLE
        $result = Invoke-BrowserTest -Context $ctx -TestScript "./tests/login.spec.js"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Context,
        
        [Parameter(Mandatory = $true)]
        [string]$TestScript,
        
        [Parameter()]
        [int]$Timeout = 120
    )
    
    Write-Host "[BROWSER] Starting test: $($Context.TestName)" -ForegroundColor Cyan
    Write-Host "[BROWSER] Run ID: $($Context.RunId)" -ForegroundColor Gray
    
    # Create result file path
    $resultFile = Join-Path $Context.TraceDir "$($Context.RunId)-result.json"
    
    # Build the test runner script
    $runnerScript = @"
const { chromium, firefox, webkit } = require('playwright');
const fs = require('fs');
const path = require('path');

(async () => {
    const result = {
        success: false,
        duration: 0,
        artifacts: [],
        errors: [],
        logs: []
    };
    
    const startTime = Date.now();
    let browser;
    let context;
    let page;
    
    try {
        // Launch browser
        const browserType = '$($Context.BrowserType)';
        const launchOptions = { 
            headless: $($Context.Headless.ToString().ToLower()),
            args: ['--no-sandbox', '--disable-setuid-sandbox']
        };
        
        browser = await { chromium, firefox, webkit }[browserType].launch(launchOptions);
        
        // Create context with viewport
        context = await browser.newContext({
            viewport: { width: $($Context.Viewport.width), height: $($Context.Viewport.height) },
            recordVideo: { dir: '$($Context.TraceDir -replace '\\', '/')' }
        });
        
        // Create page
        page = await context.newPage();
        page.setDefaultTimeout($script:BrowserDefaults.DefaultTimeout);
        page.setDefaultNavigationTimeout($script:BrowserDefaults.NavigationTimeout);
        
        // Inject test utilities
        await page.addInitScript(() => {
            window.ralphTest = {
                log: (msg) => console.log('[RALPH]', msg),
                timestamp: () => new Date().toISOString()
            };
        });
        
        // Listen for console logs
        page.on('console', msg => {
            result.logs.push({
                type: msg.type(),
                text: msg.text(),
                time: new Date().toISOString()
            });
        });
        
        // Listen for errors
        page.on('pageerror', error => {
            result.errors.push({
                type: 'pageerror',
                message: error.message,
                stack: error.stack,
                time: new Date().toISOString()
            });
        });
        
        // Execute the test
        const testModule = require('$($TestScript -replace '\\', '/')');
        if (typeof testModule.run === 'function') {
            await testModule.run(page, context, result);
        } else {
            // Inline test script evaluation
            const testFn = new Function('page', 'context', 'result', fs.readFileSync('$($TestScript -replace '\\', '/')', 'utf8'));
            await testFn(page, context, result);
        }
        
        result.success = result.errors.length === 0;
        
    } catch (error) {
        result.success = false;
        result.errors.push({
            type: 'fatal',
            message: error.message,
            stack: error.stack,
            time: new Date().toISOString()
        });
        
        // Capture screenshot on error
        if (page) {
            try {
                const screenshotPath = path.join('$($Context.ScreenshotDir -replace '\\', '/')', '$($Context.RunId)-error.png');
                await page.screenshot({ path: screenshotPath, fullPage: true });
                result.artifacts.push({ type: 'screenshot', path: screenshotPath });
            } catch (e) {
                console.error('Failed to capture error screenshot:', e);
            }
        }
    } finally {
        // Close everything
        if (context) await context.close();
        if (browser) await browser.close();
        
        result.duration = Date.now() - startTime;
        
        // Write result
        fs.writeFileSync('$($resultFile -replace '\\', '/')', JSON.stringify(result, null, 2));
        console.log('RESULT_FILE:' + '$($resultFile -replace '\\', '/')');
    }
})();
"@
    
    # Write runner script to temp file
    $runnerFile = Join-Path $env:TEMP "ralph-browser-$($Context.RunId).js"
    $runnerScript | Out-File -FilePath $runnerFile -Encoding utf8
    
    try {
        # Run the test in isolated Node process
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "node"
        $psi.Arguments = "$runnerFile"
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.UseShellExecute = $false
        $psi.WorkingDirectory = (Get-Location)
        
        $process = [System.Diagnostics.Process]::Start($psi)
        $completed = $process.WaitForExit($Timeout * 1000)
        
        if (-not $completed) {
            $process.Kill()
            throw "Browser test timed out after ${Timeout}s"
        }
        
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        $process.Dispose()
        
        # Parse result
        if (Test-Path $resultFile) {
            $result = Get-Content $resultFile -Raw | ConvertFrom-Json
            
            # Add to context artifacts
            foreach ($artifact in $result.artifacts) {
                $Context.Artifacts += $artifact.path
            }
            
            return [PSCustomObject]@{
                Success = $result.success
                Duration = $result.duration
                Artifacts = $result.artifacts
                Errors = $result.errors
                Logs = $result.logs
                ResultFile = $resultFile
                Stdout = $stdout
                Stderr = $stderr
            }
        } else {
            throw "Result file not created. Stderr: $stderr"
        }
    } finally {
        Remove-Item $runnerFile -ErrorAction SilentlyContinue
    }
}

function Test-PageAccessibility {
    <#
    .SYNOPSIS
        Runs accessibility audit on a page.
    
    .DESCRIPTION
        Uses axe-core to check accessibility compliance.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Context,
        
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [Parameter()]
        [string]$Standard = "WCAG2AA"
    )
    
    $testScript = @"
const { injectAxe, checkA11y } = require('axe-playwright');

module.exports = {
    run: async (page, context, result) => {
        await page.goto('$($Context.BaseUrl)$Path');
        await injectAxe(page);
        
        const violations = await checkA11y(page, null, {
            axeOptions: {
                runOnly: {
                    type: 'tag',
                    values: ['$Standard']
                }
            }
        });
        
        result.accessibility = violations;
        result.success = violations.length === 0;
    }
};
"@
    
    $tempFile = Join-Path $env:TEMP "ralph-a11y-$($Context.RunId).js"
    $testScript | Out-File -FilePath $tempFile -Encoding utf8
    
    try {
        return Invoke-BrowserTest -Context $Context -TestScript $tempFile -Timeout 60
    } finally {
        Remove-Item $tempFile -ErrorAction SilentlyContinue
    }
}

function Test-PagePerformance {
    <#
    .SYNOPSIS
        Captures performance metrics for a page.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Context,
        
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    $testScript = @"
module.exports = {
    run: async (page, context, result) => {
        // Navigate and wait for load
        await page.goto('$($Context.BaseUrl)$Path', { waitUntil: 'networkidle' });
        
        // Collect performance metrics
        const metrics = await page.evaluate(() => {
            const perf = JSON.parse(JSON.stringify(performance));
            const nav = performance.getEntriesByType('navigation')[0];
            return {
                loadTime: nav.loadEventEnd - nav.startTime,
                domContentLoaded: nav.domContentLoadedEventEnd - nav.startTime,
                firstPaint: performance.getEntriesByName('first-paint')[0]?.startTime,
                firstContentfulPaint: performance.getEntriesByName('first-contentful-paint')[0]?.startTime
            };
        });
        
        // Collect Core Web Vitals (if available)
        const webVitals = await page.evaluate(() => {
            return new Promise((resolve) => {
                let lcp = null;
                let cls = null;
                let fid = null;
                
                new PerformanceObserver((list) => {
                    const entries = list.getEntries();
                    lcp = entries[entries.length - 1];
                }).observe({ entryTypes: ['largest-contentful-paint'] });
                
                new PerformanceObserver((list) => {
                    for (const entry of list.getEntries()) {
                        if (!entry.hadRecentInput) {
                            cls = (cls || 0) + entry.value;
                        }
                    }
                }).observe({ entryTypes: ['layout-shift'] });
                
                setTimeout(() => {
                    resolve({ lcp, cls, fid });
                }, 100);
            });
        });
        
        result.performance = {
            metrics: metrics,
            webVitals: webVitals
        };
        
        result.success = metrics.loadTime < 3000; // 3 second threshold
    }
};
"@
    
    $tempFile = Join-Path $env:TEMP "ralph-perf-$($Context.RunId).js"
    $testScript | Out-File -FilePath $tempFile -Encoding utf8
    
    try {
        return Invoke-BrowserTest -Context $Context -TestScript $tempFile -Timeout 60
    } finally {
        Remove-Item $tempFile -ErrorAction SilentlyContinue
    }
}

#endregion

#region Ralph Integration

function New-RalphBrowserVerifier {
    <#
    .SYNOPSIS
        Creates a verifier configuration for browser testing in Ralph beads.
    
    .EXAMPLE
        $verifier = New-RalphBrowserVerifier -TestName "smoke" -BaseUrl "http://localhost:3000"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TestName,
        
        [Parameter(Mandatory = $true)]
        [string]$BaseUrl,
        
        [Parameter()]
        [string[]]$Paths = @("/"),
        
        [Parameter()]
        [string]$EvidenceDir = ".ralph/evidence"
    )
    
    # Generate the verifier script that Ralph will use
    $verifierScript = @"
`$ctx = New-BrowserTestContext -TestName "$TestName" -BaseUrl "$BaseUrl" -EvidenceDir "$EvidenceDir"
`$result = Test-PagePerformance -Context `$ctx -Path "$($Paths[0])"
if (-not `$result.Success) { exit 1 }
exit 0
"@
    
    return @{
        name = "Browser Test: $TestName"
        command = $verifierScript
        expect = @{ exit_code = 0 }
        timeout_seconds = 180
        on_failure = "stop"
    }
}

function Invoke-RalphBrowserPatrol {
    <#
    .SYNOPSIS
        Runs a patrol cycle that tests multiple pages and creates bug beads on failure.
    
    .DESCRIPTION
        Designed to be called by molecule-ralph-patrol. Tests critical paths
        and emits structured bug beads with evidence on failure.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseUrl,
        
        [Parameter()]
        [hashtable[]]$TestCases = @(
            @{ Path = "/"; Name = "home" },
            @{ Path = "/login"; Name = "login" }
        ),
        
        [Parameter()]
        [string]$EvidenceDir = ".ralph/evidence"
    )
    
    $failures = @()
    $ctx = New-BrowserTestContext -TestName "patrol-$(Get-Date -Format 'yyyyMMdd-HHmmss')" -BaseUrl $BaseUrl -EvidenceDir $EvidenceDir
    
    foreach ($testCase in $TestCases) {
        Write-Host "[PATROL] Testing: $($testCase.Name) ($($testCase.Path))" -ForegroundColor Cyan
        
        $result = Test-PagePerformance -Context $ctx -Path $testCase.Path
        
        if (-not $result.Success) {
            $failures += @{
                Name = $testCase.Name
                Path = $testCase.Path
                Errors = $result.Errors
                Artifacts = $result.Artifacts
            }
        }
    }
    
    if ($failures.Count -gt 0) {
        # Return structured data for bug bead creation
        return @{
            Success = $false
            Failures = $failures
            EvidenceDir = $EvidenceDir
            TestContext = $ctx
        }
    }
    
    return @{ Success = $true }
}

#endregion

#region Exports

Export-ModuleMember -Function @(
    'New-BrowserTestContext',
    'Invoke-BrowserTest',
    'Test-PageAccessibility',
    'Test-PagePerformance',
    'New-RalphBrowserVerifier',
    'Invoke-RalphBrowserPatrol'
)

#endregion
