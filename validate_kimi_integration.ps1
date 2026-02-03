# Kimi K2.5 Integration Validation Script
# This script validates the Kimi integration in Gas Town

param(
    [switch]$Detailed,
    [switch]$Fix
)

$ErrorActionPreference = "Stop"
$results = @{
    Passed = 0
    Failed = 0
    Warnings = 0
    Tests = @()
}

function Add-TestResult {
    param($Name, $Status, $Message = "")
    $results.Tests += [PSCustomObject]@{
        Name = $Name
        Status = $Status
        Message = $Message
    }
    if ($Status -eq "PASS") { $results.Passed++ }
    elseif ($Status -eq "FAIL") { $results.Failed++ }
    elseif ($Status -eq "WARN") { $results.Warnings++ }
}

Write-Host '=== Kimi K2.5 Integration Validation ===' -ForegroundColor Cyan
Write-Host ""

# Test 1: Check agents.go has AgentKimi constant
Write-Host "Test 1: Checking AgentKimi constant..." -NoNewline
$content = Get-Content -Path "internal/config/agents.go" -Raw
if ($content -match 'AgentKimi AgentPreset = "kimi"') {
    Add-TestResult "AgentKimi Constant" "PASS"
    Write-Host " PASS" -ForegroundColor Green
} else {
    Add-TestResult "AgentKimi Constant" "FAIL" "AgentKimi constant not found"
    Write-Host " FAIL" -ForegroundColor Red
}

# Test 2: Check Kimi preset configuration
Write-Host "Test 2: Checking Kimi preset configuration..." -NoNewline
$kimiPresetPattern = 'AgentKimi: \\{[^}]+Command:\s*"kimi"[^}]+Args:\s*\[\]string\{\s*"--yolo"\s*\}[^}]+ProcessNames:\s*\[\]string\{\s*"kimi"\s*\}[^}]+SessionIDEnv:\s*"KIMI_SESSION_ID"[^}]+ResumeFlag:\s*"--continue"[^}]+SupportsHooks:\s*true[^}]+\}'
if ($content -match $kimiPresetPattern -or 
    ($content -match 'AgentKimi: \{' -and 
     $content -match 'Command:\s*"kimi"' -and 
     $content -match 'Args:\s*\[\]string\{\s*"--yolo"' -and
     $content -match 'SessionIDEnv:\s*"KIMI_SESSION_ID"')) {
    Add-TestResult "Kimi Preset Config" "PASS"
    Write-Host " PASS" -ForegroundColor Green
} else {
    Add-TestResult "Kimi Preset Config" "FAIL" "Kimi preset configuration incomplete"
    Write-Host " FAIL" -ForegroundColor Red
}

# Test 3: Check types.go has Kimi provider support
Write-Host "Test 3: Checking types.go provider support..." -NoNewline
$typesContent = Get-Content -Path "internal/config/types.go" -Raw
$requiredPatterns = @(
    'case "kimi":\s*return "kimi"',           # defaultRuntimeCommand
    'case "kimi":\s*return \[\]string\{"--yolo"\}',  # defaultRuntimeArgs
    'if provider == "kimi" \{\s*return "KIMI_SESSION_ID"',  # defaultSessionIDEnv
    'if provider == "kimi" \{\s*return "KIMI_CONFIG_DIR"',  # defaultConfigDirEnv
    'case "kimi":\s*return "kimi"',           # defaultHooksProvider
    'case "kimi":\s*return "\.kimi"',         # defaultHooksDir
    'case "kimi":\s*return "settings\.json"', # defaultHooksFile
    'if provider == "kimi" \{\s*return \[\]string\{"kimi"\}',  # defaultProcessNames
    'if provider == "kimi"',  # defaultReadyPromptPrefix and defaultReadyDelayMs
    'if provider == "kimi" \{\s*return "AGENTS\.md"'  # defaultInstructionsFile
)

$missingPatterns = @()
foreach ($pattern in $requiredPatterns) {
    if ($typesContent -notmatch $pattern) {
        $missingPatterns += $pattern
    }
}

if ($missingPatterns.Count -eq 0) {
    Add-TestResult "types.go Provider Support" "PASS"
    Write-Host " PASS" -ForegroundColor Green
} else {
    Add-TestResult "types.go Provider Support" "FAIL" "Missing patterns: $($missingPatterns.Count)"
    Write-Host " FAIL" -ForegroundColor Red
    if ($Detailed) {
        foreach ($pattern in $missingPatterns) {
            Write-Host "  Missing: $pattern" -ForegroundColor Yellow
        }
    }
}

# Test 4: Check test file has Kimi tests
Write-Host "Test 4: Checking test coverage..." -NoNewline
$testContent = Get-Content -Path "internal/config/agents_test.go" -Raw
$requiredTests = @(
    'TestKimiAgentPreset',
    'TestKimiProviderDefaults', 
    'TestKimiRuntimeConfigFromPreset',
    'TestKimiBuildResumeCommand',
    'AgentKimi'  # In preset lists
)

$missingTests = @()
foreach ($test in $requiredTests) {
    if ($testContent -notmatch $test) {
        $missingTests += $test
    }
}

if ($missingTests.Count -eq 0) {
    Add-TestResult "Test Coverage" "PASS"
    Write-Host " PASS" -ForegroundColor Green
} else {
    Add-TestResult "Test Coverage" "FAIL" "Missing tests: $($missingTests.Count)"
    Write-Host " FAIL" -ForegroundColor Red
}

# Test 5: Check cmd/config.go documentation
Write-Host "Test 5: Checking documentation updates..." -NoNewline
$configContent = Get-Content -Path "internal/cmd/config.go" -Raw
if ($configContent -match 'kimi' -and $configContent -match 'opencode') {
    Add-TestResult "Documentation Updates" "PASS"
    Write-Host " PASS" -ForegroundColor Green
} else {
    Add-TestResult "Documentation Updates" "WARN" "Documentation may be incomplete"
    Write-Host " WARN" -ForegroundColor Yellow
}

# Test 6: Check README.md updates
Write-Host "Test 6: Checking README updates..." -NoNewline
$readmeContent = Get-Content -Path "README.md" -Raw
if ($readmeContent -match 'kimi' -and $readmeContent -match 'Kimi') {
    Add-TestResult "README Updates" "PASS"
    Write-Host " PASS" -ForegroundColor Green
} else {
    Add-TestResult "README Updates" "WARN" "README may need updates"
    Write-Host " WARN" -ForegroundColor Yellow
}

# Test 7: Check for syntax errors (basic checks)
Write-Host "Test 7: Checking for syntax issues..." -NoNewline
$syntaxIssues = @()

# Check for unclosed braces in agents.go
$openBraces = ($content -split '\{' ).Count - 1
$closeBraces = ($content -split '\}' ).Count - 1
if ($openBraces -ne $closeBraces) {
    $syntaxIssues += "agents.go: Unmatched braces (open: $openBraces, close: $closeBraces)"
}

# Check for unclosed braces in types.go
$openBraces = ($typesContent -split '\{' ).Count - 1
$closeBraces = ($typesContent -split '\}' ).Count - 1
if ($openBraces -ne $closeBraces) {
    $syntaxIssues += "types.go: Unmatched braces (open: $openBraces, close: $closeBraces)"
}

# Check for unclosed braces in agents_test.go
$openBraces = ($testContent -split '\{' ).Count - 1
$closeBraces = ($testContent -split '\}' ).Count - 1
if ($openBraces -ne $closeBraces) {
    $syntaxIssues += "agents_test.go: Unmatched braces (open: $openBraces, close: $closeBraces)"
}

if ($syntaxIssues.Count -eq 0) {
    Add-TestResult "Syntax Check" "PASS"
    Write-Host " PASS" -ForegroundColor Green
} else {
    Add-TestResult "Syntax Check" "FAIL" ($syntaxIssues -join ", ")
    Write-Host " FAIL" -ForegroundColor Red
}

# Test 8: Verify integration points
Write-Host "Test 8: Checking integration points..." -NoNewline
$integrationIssues = @()

# Check that builtinPresets has AgentKimi
if ($content -notmatch 'AgentKimi: \{') {
    $integrationIssues += "AgentKimi not in builtinPresets"
}

# Check that GetAgentPreset can handle "kimi" string
if ($content -notmatch 'globalRegistry\.Agents\[string\(name\)\]') {
    $integrationIssues += "GetAgentPreset may not handle string conversion"
}

if ($integrationIssues.Count -eq 0) {
    Add-TestResult "Integration Points" "PASS"
    Write-Host " PASS" -ForegroundColor Green
} else {
    Add-TestResult "Integration Points" "FAIL" ($integrationIssues -join ", ")
    Write-Host " FAIL" -ForegroundColor Red
}

# Summary
Write-Host ""
Write-Host '=== Validation Summary ===' -ForegroundColor Cyan
Write-Host "Passed:  $($results.Passed)" -ForegroundColor Green
Write-Host "Failed:  $($results.Failed)" -ForegroundColor Red
Write-Host "Warnings: $($results.Warnings)" -ForegroundColor Yellow
Write-Host ""

if ($results.Failed -eq 0) {
    Write-Host 'All critical tests passed!' -ForegroundColor Green
    exit 0
} else {
    Write-Host 'Some tests failed. Please review.' -ForegroundColor Red
    if ($Detailed) {
        Write-Host ""
        Write-Host '=== Detailed Results ===' -ForegroundColor Cyan
        $results.Tests | Format-Table -AutoSize
    }
    exit 1
}
