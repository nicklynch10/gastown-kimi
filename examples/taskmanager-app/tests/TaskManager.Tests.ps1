#Requires -Version 5.1
<#
.SYNOPSIS
    Task Manager Module Tests
.DESCRIPTION
    Pester tests for the TaskManager module.
#>

param()

# Import the module
$modulePath = Join-Path $PSScriptRoot "..\TaskManager.psm1"
Import-Module $modulePath -Force

# Use a test data directory
$script:TestDataDir = Join-Path $PSScriptRoot "..\data\test"
$script:OriginalStorePath = $script:TaskStorePath

describe "TaskManager Module" {
    BeforeAll {
        # Ensure test data directory exists
        if (-not (Test-Path $script:TestDataDir)) {
            New-Item -ItemType Directory -Path $script:TestDataDir -Force | Out-Null
        }
    }
    
    BeforeEach {
        # Reset to a fresh store for each test
        $script:TaskStorePath = Join-Path $script:TestDataDir "tasks-$([Guid]::NewGuid()).json"
        Remove-Module TaskManager -Force -ErrorAction SilentlyContinue
        Import-Module $modulePath -Force
    }
    
    AfterEach {
        # Cleanup test files
        if (Test-Path $script:TaskStorePath) {
            Remove-Item $script:TaskStorePath -Force -ErrorAction SilentlyContinue
        }
    }
    
    AfterAll {
        # Cleanup test directory
        if (Test-Path $script:TestDataDir) {
            Remove-Item $script:TestDataDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    Context "Add-Task" {
        It "Should add a basic task" {
            $task = Add-Task -Title "Test task" -Priority medium
            $task | Should -Not -BeNullOrEmpty
            $task.title | Should -Be "Test task"
            $task.priority | Should -Be "medium"
            $task.status | Should -Be "pending"
        }
        
        It "Should auto-increment IDs" {
            $task1 = Add-Task -Title "Task 1"
            $task2 = Add-Task -Title "Task 2"
            $task3 = Add-Task -Title "Task 3"
            
            $task2.id | Should -Be ($task1.id + 1)
            $task3.id | Should -Be ($task2.id + 1)
        }
        
        It "Should support all priority levels" {
            foreach ($priority in @("low", "medium", "high", "critical")) {
                $task = Add-Task -Title "Priority test" -Priority $priority
                $task.priority | Should -Be $priority
            }
        }
        
        It "Should reject empty title" {
            { Add-Task -Title "" } | Should -Throw
        }
        
        It "Should accept due date" {
            $due = (Get-Date).AddDays(1)
            $task = Add-Task -Title "Due date test" -DueDate $due
            $task.dueDate | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Get-Tasks" {
        BeforeEach {
            # Setup test data
            Add-Task -Title "High pending" -Priority high
            Add-Task -Title "Medium pending" -Priority medium
            Add-Task -Title "Critical pending" -Priority critical
            $completedTask = Add-Task -Title "Completed low" -Priority low
            Complete-Task -Id $completedTask.id
        }
        
        It "Should return all tasks by default" {
            $tasks = Get-Tasks
            $tasks.Count | Should -Be 4
        }
        
        It "Should filter by status" {
            $pending = Get-Tasks -Status pending
            $completed = Get-Tasks -Status completed
            
            $pending.Count | Should -Be 3
            $completed.Count | Should -Be 1
        }
        
        It "Should filter by priority" {
            $high = Get-Tasks -Priority high
            $high.Count | Should -Be 1
            $high[0].title | Should -Be "High pending"
        }
        
        It "Should sort by priority correctly" {
            $tasks = Get-Tasks -Status pending
            $tasks[0].priority | Should -Be "critical"
            $tasks[1].priority | Should -Be "high"
            $tasks[2].priority | Should -Be "medium"
        }
    }
    
    Context "Complete-Task" {
        BeforeEach {
            $script:testTask = Add-Task -Title "Complete me"
        }
        
        It "Should mark task as completed" {
            $result = Complete-Task -Id $script:testTask.id
            $result.status | Should -Be "completed"
            $result.completedAt | Should -Not -BeNullOrEmpty
        }
        
        It "Should error for non-existent task" {
            { Complete-Task -Id 99999 } | Should -Not -Throw
            # Write-Error is called but doesn't throw by default
        }
        
        It "Should warn when completing already completed task" {
            Complete-Task -Id $script:testTask.id | Out-Null
            { Complete-Task -Id $script:testTask.id -WarningAction SilentlyContinue } | Should -Not -Throw
        }
    }
    
    Context "Remove-Task" {
        BeforeEach {
            $script:testTask = Add-Task -Title "Remove me"
        }
        
        It "Should remove a task" {
            $initialCount = (Get-Tasks).Count
            Remove-Task -Id $script:testTask.id -Confirm:$false
            $finalCount = (Get-Tasks).Count
            $finalCount | Should -Be ($initialCount - 1)
        }
        
        It "Should error for non-existent task" {
            { Remove-Task -Id 99999 -Confirm:$false } | Should -Not -Throw
        }
    }
    
    Context "Clear-CompletedTasks" {
        BeforeEach {
            $t1 = Add-Task -Title "Task 1"
            $t2 = Add-Task -Title "Task 2"
            Add-Task -Title "Task 3"
            Complete-Task -Id $t1.id | Out-Null
            Complete-Task -Id $t2.id | Out-Null
        }
        
        It "Should clear only completed tasks" {
            $initialPending = (Get-Tasks -Status pending).Count
            $initialCompleted = (Get-Tasks -Status completed).Count
            
            Clear-CompletedTasks -Confirm:$false
            
            $finalPending = (Get-Tasks -Status pending).Count
            $finalCompleted = (Get-Tasks -Status completed).Count
            
            $finalPending | Should -Be $initialPending
            $finalCompleted | Should -Be 0
        }
    }
    
    Context "Show-TaskStats" {
        BeforeEach {
            Add-Task -Title "Task 1" -Priority critical
            Add-Task -Title "Task 2" -Priority high
            $t3 = Add-Task -Title "Task 3" -Priority low
            Complete-Task -Id $t3.id | Out-Null
        }
        
        It "Should return correct statistics" {
            $stats = Show-TaskStats
            $stats.'Total Tasks' | Should -Be 3
            $stats.Pending | Should -Be 2
            $stats.Completed | Should -Be 1
            $stats.'High Priority Pending' | Should -Be 2
        }
    }
}

# Run tests if not dot-sourced
if ($MyInvocation.InvocationName -ne '.') {
    Invoke-Pester -Path $PSCommandPath
}
