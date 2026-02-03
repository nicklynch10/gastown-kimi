#Requires -Version 5.1
<#
.SYNOPSIS
    Task Manager PowerShell Module
.DESCRIPTION
    A simple task management system demonstrating Ralph-Gastown SDLC.
    Supports adding, listing, completing, and removing tasks.
.EXAMPLE
    Import-Module .\TaskManager.psm1
    Add-Task -Title "Buy milk" -Priority medium
    Get-Tasks
#>

# Module-level variables
$script:TaskStorePath = Join-Path $PSScriptRoot "data\tasks.json"
$script:TaskStore = $null

#region Private Functions

function Initialize-TaskStore {
    <#
    .SYNOPSIS
        Initializes the task storage system.
    #>
    [CmdletBinding()]
    param()
    
    $dataDir = Split-Path $script:TaskStorePath -Parent
    if (-not (Test-Path $dataDir)) {
        New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
    }
    
    if (-not (Test-Path $script:TaskStorePath)) {
        $initialStore = @{
            version = "1.0"
            tasks = @()
            lastId = 0
        }
        $initialStore | ConvertTo-Json -Depth 10 | Out-File $script:TaskStorePath -Encoding UTF8
    }
    
    # Load store
    $content = Get-Content $script:TaskStorePath -Raw -Encoding UTF8
    $script:TaskStore = $content | ConvertFrom-Json
    
    # Ensure tasks is an array (PS 5.1 compatibility)
    if (-not $script:TaskStore.tasks) {
        $script:TaskStore | Add-Member -NotePropertyName 'tasks' -NotePropertyValue @() -Force
    }
    if (-not $script:TaskStore.lastId) {
        $script:TaskStore | Add-Member -NotePropertyName 'lastId' -NotePropertyValue 0 -Force
    }
}

function Save-TaskStore {
    <#
    .SYNOPSIS
        Saves the task store to disk.
    #>
    [CmdletBinding()]
    param()
    
    if ($null -eq $script:TaskStore) {
        throw "Task store not initialized"
    }
    
    # Ensure we have a proper object to serialize
    $storeObj = @{
        version = $script:TaskStore.version
        tasks = @($script:TaskStore.tasks)
        lastId = $script:TaskStore.lastId
    }
    
    $storeObj | ConvertTo-Json -Depth 10 | Out-File $script:TaskStorePath -Encoding UTF8
}

function Get-NextTaskId {
    <#
    .SYNOPSIS
        Gets the next available task ID.
    #>
    [CmdletBinding()]
    param()
    
    if ($null -eq $script:TaskStore) {
        Initialize-TaskStore
    }
    
    [int]$script:TaskStore.lastId + 1
}

#endregion

#region Public Functions

function Add-Task {
    <#
    .SYNOPSIS
        Adds a new task to the system.
    .PARAMETER Title
        The title/description of the task.
    .PARAMETER Priority
        Task priority: low, medium, high, critical.
    .PARAMETER DueDate
        Optional due date for the task.
    .EXAMPLE
        Add-Task -Title "Buy groceries" -Priority high -DueDate (Get-Date).AddDays(1)
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Title,
        
        [Parameter()]
        [ValidateSet("low", "medium", "high", "critical")]
        [string]$Priority = "medium",
        
        [Parameter()]
        [DateTime]$DueDate
    )
    
    if ($null -eq $script:TaskStore) {
        Initialize-TaskStore
    }
    
    $id = Get-NextTaskId
    
    $task = New-Object PSObject -Property @{
        id = $id
        title = $Title
        priority = $Priority
        status = "pending"
        createdAt = (Get-Date -Format "o")
        completedAt = $null
    }
    
    if ($DueDate) {
        $task | Add-Member -NotePropertyName 'dueDate' -NotePropertyValue ($DueDate.ToString("o")) -Force
    }
    
    if ($PSCmdlet.ShouldProcess("Task: $Title", "Add")) {
        # Add to store - ensure tasks is an array
        $currentTasks = @($script:TaskStore.tasks)
        $currentTasks += $task
        $script:TaskStore.tasks = $currentTasks
        $script:TaskStore.lastId = $id
        Save-TaskStore
        
        # Output the created task
        $task
    }
}

function Get-Tasks {
    <#
    .SYNOPSIS
        Gets tasks from the system.
    .PARAMETER Status
        Filter by status: pending, completed, all.
    .PARAMETER Priority
        Filter by priority: low, medium, high, critical.
    .EXAMPLE
        Get-Tasks -Status pending -Priority high
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet("pending", "completed", "all")]
        [string]$Status = "all",
        
        [Parameter()]
        [ValidateSet("low", "medium", "high", "critical")]
        [string]$Priority
    )
    
    if ($null -eq $script:TaskStore) {
        Initialize-TaskStore
    }
    
    $tasks = @($script:TaskStore.tasks)
    
    # Filter by status
    if ($Status -ne "all") {
        $tasks = $tasks | Where-Object { $_.status -eq $Status }
    }
    
    # Filter by priority
    if ($Priority) {
        $tasks = $tasks | Where-Object { $_.priority -eq $Priority }
    }
    
    # Sort by priority (critical > high > medium > low) then by ID
    $priorityOrder = @{"critical" = 0; "high" = 1; "medium" = 2; "low" = 3}
    $tasks | Sort-Object { $priorityOrder[$_.priority] }, id
}

function Complete-Task {
    <#
    .SYNOPSIS
        Marks a task as completed.
    .PARAMETER Id
        The ID of the task to complete.
    .EXAMPLE
        Complete-Task -Id 1
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [int]$Id
    )
    
    if ($null -eq $script:TaskStore) {
        Initialize-TaskStore
    }
    
    $task = $script:TaskStore.tasks | Where-Object { $_.id -eq $Id } | Select-Object -First 1
    
    if (-not $task) {
        Write-Error "Task with ID $Id not found"
        return
    }
    
    if ($task.status -eq "completed") {
        Write-Warning "Task $Id is already completed"
        return
    }
    
    if ($PSCmdlet.ShouldProcess("Task $Id", "Complete")) {
        # Find and update the task
        foreach ($t in $script:TaskStore.tasks) {
            if ($t.id -eq $Id) {
                $t.status = "completed"
                $t.completedAt = (Get-Date -Format "o")
                break
            }
        }
        Save-TaskStore
        
        # Return updated task
        $script:TaskStore.tasks | Where-Object { $_.id -eq $Id } | Select-Object -First 1
    }
}

function Remove-Task {
    <#
    .SYNOPSIS
        Removes a task from the system.
    .PARAMETER Id
        The ID of the task to remove.
    .EXAMPLE
        Remove-Task -Id 1
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [int]$Id
    )
    
    if ($null -eq $script:TaskStore) {
        Initialize-TaskStore
    }
    
    $task = $script:TaskStore.tasks | Where-Object { $_.id -eq $Id } | Select-Object -First 1
    
    if (-not $task) {
        Write-Error "Task with ID $Id not found"
        return
    }
    
    if ($PSCmdlet.ShouldProcess("Task: $($task.title)", "Remove")) {
        $script:TaskStore.tasks = @($script:TaskStore.tasks | Where-Object { $_.id -ne $Id })
        Save-TaskStore
        
        Write-Verbose "Removed task $Id"
    }
}

function Clear-CompletedTasks {
    <#
    .SYNOPSIS
        Removes all completed tasks.
    .EXAMPLE
        Clear-CompletedTasks
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()
    
    if ($null -eq $script:TaskStore) {
        Initialize-TaskStore
    }
    
    $completedCount = ($script:TaskStore.tasks | Where-Object { $_.status -eq "completed" }).Count
    
    if ($completedCount -eq 0) {
        Write-Host "No completed tasks to clear"
        return
    }
    
    if ($PSCmdlet.ShouldProcess("$completedCount completed tasks", "Clear")) {
        $script:TaskStore.tasks = @($script:TaskStore.tasks | Where-Object { $_.status -ne "completed" })
        Save-TaskStore
        
        Write-Host "Cleared $completedCount completed task(s)"
    }
}

function Show-TaskStats {
    <#
    .SYNOPSIS
        Shows task statistics.
    .EXAMPLE
        Show-TaskStats
    #>
    [CmdletBinding()]
    param()
    
    if ($null -eq $script:TaskStore) {
        Initialize-TaskStore
    }
    
    $allTasks = @($script:TaskStore.tasks)
    $pending = $allTasks | Where-Object { $_.status -eq "pending" }
    $completed = $allTasks | Where-Object { $_.status -eq "completed" }
    
    $stats = New-Object PSObject -Property @{
        "Total Tasks" = $allTasks.Count
        "Pending" = $pending.Count
        "Completed" = $completed.Count
        "High Priority Pending" = ($pending | Where-Object { $_.priority -in @("high", "critical") }).Count
    }
    
    $stats
}

#endregion

# Initialize on module load
Initialize-TaskStore

# Export functions
Export-ModuleMember -Function Add-Task, Get-Tasks, Complete-Task, Remove-Task, Clear-CompletedTasks, Show-TaskStats
