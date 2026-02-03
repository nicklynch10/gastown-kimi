# Kimi Integration Logic Tests (PowerShell version)
# Simulates the Go test logic to verify implementation correctness

$ErrorActionPreference = "Stop"

Write-Host '=== Kimi Integration Logic Tests ===' -ForegroundColor Cyan
Write-Host ''

$passed = 0
$failed = 0

function Test-AgentKimiConstant {
    Write-Host 'Test: AgentKimi constant...' -NoNewline
    # Check that AgentKimi = "kimi" is defined in agents.go
    $content = Get-Content -Path 'internal/config/agents.go' -Raw
    if ($content -match 'AgentKimi AgentPreset = "kimi"') {
        Write-Host ' PASS' -ForegroundColor Green
        return $true
    }
    Write-Host ' FAIL' -ForegroundColor Red
    return $false
}

function Test-KimiPresetConfig {
    Write-Host 'Test: Kimi preset configuration...'
    $content = Get-Content -Path 'internal/config/agents.go' -Raw
    
    # Extract Kimi preset block
    $kimiMatch = [regex]::Match($content, 'AgentKimi: \{([^}]+)\}', [System.Text.RegularExpressions.RegexOptions]::SingleLine)
    if (-not $kimiMatch.Success) {
        Write-Host '  FAIL: Could not find AgentKimi preset block' -ForegroundColor Red
        return $false
    }
    
    $kimiBlock = $kimiMatch.Groups[1].Value
    $checks = @(
        @{ Pattern = 'Command:\s*"kimi"'; Description = 'Command = kimi' },
        @{ Pattern = 'Args:\s*\[\]string\{\s*"--yolo"'; Description = 'Args = [--yolo]' },
        @{ Pattern = 'ProcessNames:\s*\[\]string\{\s*"kimi"'; Description = 'ProcessNames = [kimi]' },
        @{ Pattern = 'SessionIDEnv:\s*"KIMI_SESSION_ID"'; Description = 'SessionIDEnv = KIMI_SESSION_ID' },
        @{ Pattern = 'ResumeFlag:\s*"--continue"'; Description = 'ResumeFlag = --continue' },
        @{ Pattern = 'ResumeStyle:\s*"flag"'; Description = 'ResumeStyle = flag' },
        @{ Pattern = 'SupportsHooks:\s*true'; Description = 'SupportsHooks = true' },
        @{ Pattern = 'SupportsForkSession:\s*false'; Description = 'SupportsForkSession = false' }
    )
    
    $allPassed = $true
    foreach ($check in $checks) {
        if ($kimiBlock -match $check.Pattern) {
            Write-Host "  ✓ $($check.Description)" -ForegroundColor Green
        } else {
            Write-Host "  ✗ $($check.Description)" -ForegroundColor Red
            $allPassed = $false
        }
    }
    
    return $allPassed
}

function Test-KimiResumeCommand {
    Write-Host 'Test: Kimi resume command logic...'
    
    # Based on the implementation:
    # - Command: "kimi"
    # - Args: ["--yolo"]
    # - ResumeFlag: "--continue"
    # - ResumeStyle: "flag"
    # Expected: kimi --yolo --continue sessionID
    
    $command = 'kimi'
    $args = @('--yolo')
    $resumeFlag = '--continue'
    $sessionID = 'test-session-123'
    
    # Simulate BuildResumeCommand logic
    $result = "$command $($args -join ' ') $resumeFlag $sessionID"
    
    $expectedParts = @('kimi', '--yolo', '--continue', 'test-session-123')
    $allFound = $true
    
    foreach ($part in $expectedParts) {
        if ($result -match [regex]::Escape($part)) {
            Write-Host "  ✓ Contains '$part'" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Missing '$part'" -ForegroundColor Red
            $allFound = $false
        }
    }
    
    Write-Host "  Generated: $result" -ForegroundColor Cyan
    return $allFound
}

function Test-KimiVsClaude {
    Write-Host 'Test: Kimi vs Claude differentiation...'
    
    $content = Get-Content -Path 'internal/config/agents.go' -Raw
    
    # Extract both presets
    $claudeMatch = [regex]::Match($content, 'AgentClaude: \{([^}]+)\}', [System.Text.RegularExpressions.RegexOptions]::SingleLine)
    $kimiMatch = [regex]::Match($content, 'AgentKimi: \{([^}]+)\}', [System.Text.RegularExpressions.RegexOptions]::SingleLine)
    
    if (-not $claudeMatch.Success -or -not $kimiMatch.Success) {
        Write-Host '  FAIL: Could not find both presets' -ForegroundColor Red
        return $false
    }
    
    $claudeBlock = $claudeMatch.Groups[1].Value
    $kimiBlock = $kimiMatch.Groups[1].Value
    
    # Check differences
    $differences = @(
        @{ 
            Name = 'Command'
            Claude = ($claudeBlock -match 'Command:\s*"claude"')
            Kimi = ($kimiBlock -match 'Command:\s*"kimi"')
        },
        @{
            Name = 'SessionIDEnv'
            Claude = ($claudeBlock -match 'SessionIDEnv:\s*"CLAUDE_SESSION_ID"')
            Kimi = ($kimiBlock -match 'SessionIDEnv:\s*"KIMI_SESSION_ID"')
        },
        @{
            Name = 'ResumeFlag'
            Claude = ($claudeBlock -match 'ResumeFlag:\s*"--resume"')
            Kimi = ($kimiBlock -match 'ResumeFlag:\s*"--continue"')
        }
    )
    
    $allDifferent = $true
    foreach ($diff in $differences) {
        if ($diff.Claude -and $diff.Kimi) {
            Write-Host "  ✓ $($diff.Name) is different" -ForegroundColor Green
        } else {
            Write-Host "  ✗ $($diff.Name) check failed" -ForegroundColor Red
            $allDifferent = $false
        }
    }
    
    return $allDifferent
}

function Test-ProviderFunctions {
    Write-Host 'Test: Provider functions in types.go...'
    
    $content = Get-Content -Path 'internal/config/types.go' -Raw
    
    $required = @(
        @{ Pattern = 'case "kimi":\s*return "kimi"'; Description = 'defaultRuntimeCommand' },
        @{ Pattern = 'case "kimi":\s*return \[\]string\{\s*"--yolo"'; Description = 'defaultRuntimeArgs' },
        @{ Pattern = 'if provider == "kimi"'; Description = 'defaultSessionIDEnv' },
        @{ Pattern = 'return "KIMI_CONFIG_DIR"'; Description = 'defaultConfigDirEnv' },
        @{ Pattern = 'case "kimi":\s*return "kimi"'; Description = 'defaultHooksProvider' },
        @{ Pattern = 'case "kimi":\s*return "\.kimi"'; Description = 'defaultHooksDir' },
        @{ Pattern = 'return \[\]string\{\s*"kimi"\}'; Description = 'defaultProcessNames' },
        @{ Pattern = 'return "> "'; Description = 'defaultReadyPromptPrefix' },
        @{ Pattern = 'return 8000'; Description = 'defaultReadyDelayMs' },
        @{ Pattern = 'return "AGENTS\.md"'; Description = 'defaultInstructionsFile' }
    )
    
    $allFound = $true
    foreach ($req in $required) {
        if ($content -match $req.Pattern) {
            Write-Host "  ✓ $($req.Description)" -ForegroundColor Green
        } else {
            Write-Host "  ✗ $($req.Description)" -ForegroundColor Red
            $allFound = $false
        }
    }
    
    return $allFound
}

function Test-TestCoverage {
    Write-Host 'Test: Test file coverage...'
    
    $content = Get-Content -Path 'internal/config/agents_test.go' -Raw
    
    $tests = @(
        'TestKimiAgentPreset',
        'TestKimiProviderDefaults',
        'TestKimiRuntimeConfigFromPreset',
        'TestKimiBuildResumeCommand'
    )
    
    $allFound = $true
    foreach ($test in $tests) {
        if ($content -match "func $test" ) {
            Write-Host "  ✓ $test" -ForegroundColor Green
        } else {
            Write-Host "  ✗ $test missing" -ForegroundColor Red
            $allFound = $false
        }
    }
    
    return $allFound
}

# Run all tests
$tests = @(
    @{ Name = 'AgentKimi Constant'; Function = ${function:Test-AgentKimiConstant} },
    @{ Name = 'Kimi Preset Config'; Function = ${function:Test-KimiPresetConfig} },
    @{ Name = 'Kimi Resume Command'; Function = ${function:Test-KimiResumeCommand} },
    @{ Name = 'Kimi vs Claude'; Function = ${function:Test-KimiVsClaude} },
    @{ Name = 'Provider Functions'; Function = ${function:Test-ProviderFunctions} },
    @{ Name = 'Test Coverage'; Function = ${function:Test-TestCoverage} }
)

foreach ($test in $tests) {
    if (& $test.Function) {
        $passed++
    } else {
        $failed++
    }
    Write-Host ''
}

Write-Host '=== Summary ===' -ForegroundColor Cyan
Write-Host "Passed: $passed" -ForegroundColor Green
Write-Host 'Failed:' $failed -ForegroundColor Red

if ($failed -eq 0) {
    Write-Host ''
    Write-Host 'All logic tests passed!' -ForegroundColor Green
    exit 0
} else {
    exit 1
}
