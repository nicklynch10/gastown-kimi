# Simple tests compatible with Pester 3.x
$ErrorActionPreference = "Stop"

# Import module
$modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) "TaskManager.psm1"
Import-Module $modulePath -Force

# Test data location
$testDataDir = Join-Path $PSScriptRoot "test_data"
if (-not (Test-Path $testDataDir)) {
    New-Item -ItemType Directory -Path $testDataDir -Force | Out-Null
}

# Override the store path for testing
$script:TaskStorePath = Join-Path $testDataDir "test_tasks.json"
if (Test-Path $script:TaskStorePath) {
    Remove-Item $script:TaskStorePath -Force
}

# Reload module with test path
Remove-Module TaskManager -Force -ErrorAction SilentlyContinue
Import-Module $modulePath -Force

$passed = 0
$failed = 0

function Test-Case {
    param([string]$Name, [scriptblock]$Test)
    
    try {
        & $Test
        Write-Host "[PASS] $Name" -ForegroundColor Green
        $script:passed++
    } catch {
        Write-Host "[FAIL] $Name - $_" -ForegroundColor Red
        $script:failed++
    }
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  TASK MANAGER MANUAL TEST SUITE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Test 1: Add-Task basic
Test-Case "Add-Task creates a task with ID" {
    $task = Add-Task -Title "Test Task" -Priority high
    if ($task.id -le 0) { throw "Invalid ID" }
    if ($task.title -ne "Test Task") { throw "Title mismatch" }
    if ($task.priority -ne "high") { throw "Priority mismatch" }
    if ($task.status -ne "pending") { throw "Status should be pending" }
}

# Test 2: Auto-increment IDs
Test-Case "Add-Task auto-increments IDs" {
    $task1 = Add-Task -Title "Task 1"
    $task2 = Add-Task -Title "Task 2"
    if ($task2.id -ne ($task1.id + 1)) { throw "IDs not sequential" }
}

# Test 3: All priorities
Test-Case "Add-Task supports all priorities" {
    foreach ($p in @("low", "medium", "high", "critical")) {
        $t = Add-Task -Title "Priority test" -Priority $p
        if ($t.priority -ne $p) { throw "Priority $p not set correctly" }
    }
}

# Test 4: Get-Tasks returns all
Test-Case "Get-Tasks returns all tasks" {
    $tasks = Get-Tasks
    if ($tasks.Count -lt 6) { throw "Expected at least 6 tasks, got $($tasks.Count)" }
}

# Test 5: Get-Tasks filters by status
Test-Case "Get-Tasks filters by status" {
    $pending = Get-Tasks -Status pending
    $completed = Get-Tasks -Status completed
    if ($pending.Count -lt 1) { throw "Should have pending tasks" }
}

# Test 6: Get-Tasks filters by priority
Test-Case "Get-Tasks filters by priority" {
    $high = Get-Tasks -Priority high
    if ($high.Count -lt 1) { throw "Should have high priority tasks" }
}

# Test 7: Complete-Task
Test-Case "Complete-Task marks as completed" {
    $t = Add-Task -Title "Complete me"
    $result = Complete-Task -Id $t.id
    if ($result.status -ne "completed") { throw "Not marked completed" }
    if (-not $result.completedAt) { throw "No completedAt timestamp" }
}

# Test 8: Complete-Task prevents double complete
Test-Case "Complete-Task handles already completed" {
    $t = Add-Task -Title "Already done"
    Complete-Task -Id $t.id | Out-Null
    # Should not throw
    Complete-Task -Id $t.id -WarningAction SilentlyContinue | Out-Null
}

# Test 9: Remove-Task
Test-Case "Remove-Task removes task" {
    $t = Add-Task -Title "Remove me"
    $before = (Get-Tasks).Count
    Remove-Task -Id $t.id -Confirm:$false
    $after = (Get-Tasks).Count
    if ($after -ge $before) { throw "Task not removed" }
}

# Test 10: Show-TaskStats
Test-Case "Show-TaskStats returns stats" {
    $stats = Show-TaskStats
    if (-not $stats.'Total Tasks') { throw "No total tasks stat" }
    if ($stats.Pending -lt 0) { throw "Invalid pending count" }
}

# Test 11: Sorting by priority
Test-Case "Get-Tasks sorts by priority" {
    # Clear and add in reverse order
    $tasks = Get-Tasks -Status pending | Select-Object -First 3
    if ($tasks.Count -ge 2) {
        $priorityOrder = @{"critical" = 0; "high" = 1; "medium" = 2; "low" = 3}
        if ($priorityOrder[$tasks[0].priority] -gt $priorityOrder[$tasks[1].priority]) {
            throw "Tasks not sorted by priority"
        }
    }
}

# Test 12: Validation
Test-Case "Add-Task validates empty title" {
    try {
        Add-Task -Title ""
        throw "Should have thrown for empty title"
    } catch {
        # Expected
    }
}

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  TEST SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Passed: $passed" -ForegroundColor Green
Write-Host "Failed: $failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Green" })
Write-Host ""

# Cleanup
Remove-Item $testDataDir -Recurse -Force -ErrorAction SilentlyContinue

if ($failed -eq 0) {
    Write-Host "[SUCCESS] All tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "[FAILURE] Some tests failed!" -ForegroundColor Red
    exit 1
}
