#requires -Version 5.1
<#
.SYNOPSIS
    Ralph Logging Module - Centralized logging infrastructure

.DESCRIPTION
    Provides consistent logging across all Ralph components with:
    - Structured log output (console and file)
    - Log rotation
    - Multiple log levels
    - Thread-safe file operations

.EXAMPLE
    Import-Module .\ralph-logging.psm1
    Initialize-RalphLogger -LogDir ".ralph/logs"
    Write-RalphLog "Starting operation" -Level INFO
#>

#region Configuration

$script:LoggerConfig = @{
    LogDir = ""
    CurrentLogFile = ""
    ConsoleOutput = $true
    FileOutput = $true
    MinLevel = "DEBUG"
    MaxLogSizeMB = 10
    MaxLogFiles = 5
}

$script:LogLevels = @{
    DEBUG = 0
    INFO = 1
    WARN = 2
    ERROR = 3
    FATAL = 4
}

$script:LogColors = @{
    DEBUG = "Gray"
    INFO = "White"
    WARN = "Yellow"
    ERROR = "Red"
    FATAL = "Magenta"
}

#endregion

#region Public Functions

function Initialize-RalphLogger {
    <#
    .SYNOPSIS
        Initialize the Ralph logging system
    
    .PARAMETER LogDir
        Directory for log files (default: .ralph/logs)
    
    .PARAMETER ConsoleOutput
        Enable console output (default: true)
    
    .PARAMETER FileOutput
        Enable file output (default: true)
    
    .PARAMETER MinLevel
        Minimum log level to record (default: DEBUG)
    #>
    [CmdletBinding()]
    param(
        [string]$LogDir = ".ralph/logs",
        [bool]$ConsoleOutput = $true,
        [bool]$FileOutput = $true,
        [ValidateSet("DEBUG", "INFO", "WARN", "ERROR", "FATAL")]
        [string]$MinLevel = "DEBUG"
    )
    
    $script:LoggerConfig.LogDir = $LogDir
    $script:LoggerConfig.ConsoleOutput = $ConsoleOutput
    $script:LoggerConfig.FileOutput = $FileOutput
    $script:LoggerConfig.MinLevel = $MinLevel
    
    # Create log directory
    if (-not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
    }
    
    # Set current log file
    $date = Get-Date -Format "yyyy-MM-dd"
    $script:LoggerConfig.CurrentLogFile = Join-Path $LogDir "ralph-$date.log"
    
    # Write initialization message
    Write-RalphLog "Ralph logger initialized" -Level DEBUG
    Write-RalphLog "Log file: $($script:LoggerConfig.CurrentLogFile)" -Level DEBUG
}

function Write-RalphLog {
    <#
    .SYNOPSIS
        Write a log message
    
    .PARAMETER Message
        The message to log
    
    .PARAMETER Level
        Log level (DEBUG, INFO, WARN, ERROR, FATAL)
    
    .PARAMETER Component
        Component name (default: calling function)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Message,
        
        [Parameter()]
        [ValidateSet("DEBUG", "INFO", "WARN", "ERROR", "FATAL")]
        [string]$Level = "INFO",
        
        [Parameter()]
        [string]$Component = ""
    )
    
    # Check minimum level
    if ($script:LogLevels[$Level] -lt $script:LogLevels[$script:LoggerConfig.MinLevel]) {
        return
    }
    
    # Get component from call stack if not provided
    if (-not $Component) {
        $callStack = Get-PSCallStack
        if ($callStack.Count -gt 1) {
            $Component = $callStack[1].FunctionName
        } else {
            $Component = "Unknown"
        }
    }
    
    # Format timestamp
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    
    # Build log entry
    $logEntry = "[$timestamp] [$Level] [$Component] $Message"
    
    # Console output
    if ($script:LoggerConfig.ConsoleOutput) {
        $color = $script:LogColors[$Level]
        Write-Host $logEntry -ForegroundColor $color
    }
    
    # File output
    if ($script:LoggerConfig.FileOutput -and $script:LoggerConfig.CurrentLogFile) {
        try {
            # Check log rotation
            Test-LogRotation
            
            # Append to log file (thread-safe using file locking)
            $logFile = $script:LoggerConfig.CurrentLogFile
            $retryCount = 0
            $maxRetries = 3
            $written = $false
            
            while (-not $written -and $retryCount -lt $maxRetries) {
                try {
                    [System.IO.File]::AppendAllText($logFile, $logEntry + "`r`n")
                    $written = $true
                } catch [System.IO.IOException] {
                    # File locked, wait and retry
                    $retryCount++
                    Start-Sleep -Milliseconds 100
                }
            }
        } catch {
            # If file logging fails, at least try console
            if ($script:LoggerConfig.ConsoleOutput) {
                Write-Host "[LOG ERROR] Failed to write to log file: $_" -ForegroundColor Red
            }
        }
    }
}

function Write-RalphProgress {
    <#
    .SYNOPSIS
        Write a progress message for long-running operations
    
    .PARAMETER Activity
        The activity being performed
    
    .PARAMETER Status
        Current status message
    
    .PARAMETER PercentComplete
        Percentage complete (0-100)
    
    .PARAMETER CurrentOperation
        Detailed current operation
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Activity,
        
        [Parameter()]
        [string]$Status = "",
        
        [Parameter()]
        [int]$PercentComplete = -1,
        
        [Parameter()]
        [string]$CurrentOperation = ""
    )
    
    # Log to file
    $msg = "PROGRESS: $Activity"
    if ($Status) { $msg += " - $Status" }
    if ($PercentComplete -ge 0) { $msg += " ($PercentComplete%)" }
    Write-RalphLog $msg -Level DEBUG -Component "Progress"
    
    # Show progress bar
    $progressParams = @{
        Activity = $Activity
    }
    if ($Status) { $progressParams.Status = $Status }
    if ($PercentComplete -ge 0) { $progressParams.PercentComplete = $PercentComplete }
    if ($CurrentOperation) { $progressParams.CurrentOperation = $CurrentOperation }
    
    Write-Progress @progressParams
}

function Get-RalphLogPath {
    <#
    .SYNOPSIS
        Get the current log file path
    #>
    return $script:LoggerConfig.CurrentLogFile
}

function Get-RalphLogs {
    <#
    .SYNOPSIS
        Get recent log entries
    
    .PARAMETER Lines
        Number of lines to return (default: 50)
    
    .PARAMETER Level
        Filter by log level
    #>
    [CmdletBinding()]
    param(
        [int]$Lines = 50,
        [ValidateSet("", "DEBUG", "INFO", "WARN", "ERROR", "FATAL")]
        [string]$Level = ""
    )
    
    $logFile = $script:LoggerConfig.CurrentLogFile
    if (-not (Test-Path $logFile)) {
        return @()
    }
    
    $content = Get-Content $logFile -Tail $Lines
    
    if ($Level) {
        $content = $content | Where-Object { $_ -match "\[$Level\]" }
    }
    
    return $content
}

function Clear-RalphLogs {
    <#
    .SYNOPSIS
        Clear old log files
    
    .PARAMETER KeepDays
        Number of days to keep (default: 7)
    #>
    [CmdletBinding()]
    param(
        [int]$KeepDays = 7
    )
    
    $logDir = $script:LoggerConfig.LogDir
    if (-not (Test-Path $logDir)) {
        return
    }
    
    $cutoffDate = (Get-Date).AddDays(-$KeepDays)
    $logFiles = Get-ChildItem $logDir -Filter "ralph-*.log"
    
    $removed = 0
    foreach ($file in $logFiles) {
        if ($file.LastWriteTime -lt $cutoffDate) {
            Remove-Item $file.FullName -Force
            $removed++
        }
    }
    
    Write-RalphLog "Cleared $removed old log files (kept last $KeepDays days)" -Level INFO
    return $removed
}

#endregion

#region Private Functions

function Test-LogRotation {
    $logFile = $script:LoggerConfig.CurrentLogFile
    
    if (-not (Test-Path $logFile)) {
        return
    }
    
    $fileInfo = Get-Item $logFile
    $sizeMB = $fileInfo.Length / 1MB
    
    if ($sizeMB -gt $script:LoggerConfig.MaxLogSizeMB) {
        # Rotate the log
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $archiveName = "ralph-$(Get-Date -Format 'yyyy-MM-dd')-$timestamp.log"
        $archivePath = Join-Path $script:LoggerConfig.LogDir $archiveName
        
        Move-Item $logFile $archivePath -Force
        
        # Clean up old archives
        $archives = Get-ChildItem $script:LoggerConfig.LogDir -Filter "ralph-*.log" | 
            Where-Object { $_.Name -ne (Split-Path $script:LoggerConfig.CurrentLogFile -Leaf) } |
            Sort-Object LastWriteTime -Descending
        
        if ($archives.Count -gt $script:LoggerConfig.MaxLogFiles) {
            $archives | Select-Object -Skip $script:LoggerConfig.MaxLogFiles | Remove-Item -Force
        }
        
        Write-RalphLog "Log rotated to $archiveName" -Level DEBUG
    }
}

#endregion

#region Export

Export-ModuleMember -Function @(
    "Initialize-RalphLogger",
    "Write-RalphLog",
    "Write-RalphProgress",
    "Get-RalphLogPath",
    "Get-RalphLogs",
    "Clear-RalphLogs"
)

#endregion
