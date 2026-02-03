# Calculator Tests

$ErrorActionPreference = "Stop"

# Import module
Import-Module "$PSScriptRoot/Calculator.psm1" -Force

$testsPassed = 0
$testsFailed = 0

function Test-Case {
    param($Name, $ScriptBlock)
    try {
        & $ScriptBlock
        Write-Host "[PASS] $Name" -ForegroundColor Green
        $script:testsPassed++
    } catch {
        Write-Host "[FAIL] $Name - $_" -ForegroundColor Red
        $script:testsFailed++
    }
}

# Run tests
Write-Host "`nRunning Calculator Tests...`n" -ForegroundColor Cyan

Test-Case "Add 2 + 3 = 5" {
    $result = Add-Numbers -a 2 -b 3
    if ($result -ne 5) { throw "Expected 5, got $result" }
}

Test-Case "Subtract 5 - 3 = 2" {
    $result = Subtract-Numbers -a 5 -b 3
    if ($result -ne 2) { throw "Expected 2, got $result" }
}

Test-Case "Multiply 4 * 5 = 20" {
    $result = Multiply-Numbers -a 4 -b 5
    if ($result -ne 20) { throw "Expected 20, got $result" }
}

Test-Case "Divide 10 / 2 = 5" {
    $result = Divide-Numbers -a 10 -b 2
    if ($result -ne 5) { throw "Expected 5, got $result" }
}

Test-Case "Divide by zero throws error" {
    $errorThrown = $false
    try {
        Divide-Numbers -a 10 -b 0
    } catch {
        $errorThrown = $true
    }
    if (-not $errorThrown) { throw "Expected error for divide by zero" }
}

Write-Host "`nResults: $testsPassed passed, $testsFailed failed" -ForegroundColor $(if($testsFailed -eq 0){'Green'}else{'Red'})

exit $testsFailed
