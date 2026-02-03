# Ralph Resilience Module
# Provides error handling, retry logic, and graceful degradation

$script:DefaultRetryOptions = @{
    MaxRetries = 3
    InitialBackoffSeconds = 5
    MaxBackoffSeconds = 300
    BackoffMultiplier = 2
    RetryableErrors = @('timeout', 'connection', 'temporarily unavailable')
}

#region Retry Logic

function Invoke-WithRetry {
    <#
    .SYNOPSIS
        Invokes a script block with retry logic and exponential backoff.
    
    .DESCRIPTION
        Executes a script block, retrying on failure with exponential backoff.
        Configurable retry count, backoff strategy, and error classification.
    
    .PARAMETER ScriptBlock
        The code to execute
    
    .PARAMETER MaxRetries
        Maximum number of retry attempts (default: 3)
    
    .PARAMETER InitialBackoffSeconds
        Initial wait time between retries (default: 5)
    
    .PARAMETER MaxBackoffSeconds
        Maximum wait time between retries (default: 300)
    
    .PARAMETER RetryableErrorFilter
        Script block that determines if an error is retryable
    
    .PARAMETER OnRetry
        Script block to execute on each retry (receives attempt number and error)
    
    .EXAMPLE
        Invoke-WithRetry -ScriptBlock { Get-Content "file.txt" } -MaxRetries 5
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,
        
        [Parameter()]
        [int]$MaxRetries = $script:DefaultRetryOptions.MaxRetries,
        
        [Parameter()]
        [int]$InitialBackoffSeconds = $script:DefaultRetryOptions.InitialBackoffSeconds,
        
        [Parameter()]
        [int]$MaxBackoffSeconds = $script:DefaultRetryOptions.MaxBackoffSeconds,
        
        [Parameter()]
        [scriptblock]$RetryableErrorFilter = $null,
        
        [Parameter()]
        [scriptblock]$OnRetry = $null,
        
        [Parameter()]
        [string]$ActivityName = "Operation"
    )
    
    $backoff = $InitialBackoffSeconds
    $lastError = $null
    
    for ($attempt = 1; $attempt -le ($MaxRetries + 1); $attempt++) {
        try {
            if ($attempt -gt 1) {
                Write-ResilienceLog "Attempt $attempt of $($MaxRetries + 1) for $ActivityName..." "WARN"
            }
            
            $result = & $ScriptBlock
            
            if ($attempt -gt 1) {
                Write-ResilienceLog "$ActivityName succeeded on attempt $attempt" "SUCCESS"
            }
            
            return @{
                Success = $true
                Result = $result
                Attempts = $attempt
            }
        }
        catch {
            $lastError = $_
            
            # Check if this is the last attempt
            if ($attempt -gt $MaxRetries) {
                break
            }
            
            # Check if error is retryable
            $isRetryable = $true
            if ($RetryableErrorFilter) {
                $isRetryable = & $RetryableErrorFilter $lastError
            } else {
                $isRetryable = Test-RetryableError -ErrorRecord $lastError
            }
            
            if (-not $isRetryable) {
                Write-ResilienceLog "Non-retryable error for $ActivityName, giving up" "ERROR"
                break
            }
            
            Write-ResilienceLog "$ActivityName failed (attempt $attempt): $($lastError.Exception.Message)" "WARN"
            
            # Invoke retry callback
            if ($OnRetry) {
                & $OnRetry $attempt $lastError
            }
            
            # Wait before retry
            Write-ResilienceLog "Waiting ${backoff}s before retry..." "INFO"
            Start-Sleep -Seconds $backoff
            
            # Exponential backoff
            $backoff = [Math]::Min($backoff * $script:DefaultRetryOptions.BackoffMultiplier, $MaxBackoffSeconds)
        }
    }
    
    # All retries exhausted
    Write-ResilienceLog "$ActivityName failed after $($MaxRetries + 1) attempts" "ERROR"
    
    return @{
        Success = $false
        Error = $lastError
        Attempts = $attempt - 1
    }
}

function Test-RetryableError {
    <#
    .SYNOPSIS
        Determines if an error is likely transient and should be retried.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)] $ErrorRecord)
    
    $errorText = $ErrorRecord.ToString().ToLower()
    
    $retryablePatterns = @(
        'timeout',
        'timed out',
        'connection',
        'network',
        'temporarily',
        'unavailable',
        '503',
        '502',
        '504',
        '408',
        '429',
        'reset by peer',
        'broken pipe',
        'unable to connect',
        'deadline exceeded'
    )
    
    foreach ($pattern in $retryablePatterns) {
        if ($errorText -match $pattern) {
            return $true
        }
    }
    
    return $false
}

#endregion

#region Circuit Breaker

$script:CircuitBreakers = @{}

function Invoke-WithCircuitBreaker {
    <#
    .SYNOPSIS
        Circuit breaker pattern implementation for Ralph operations.
    
    .DESCRIPTION
        Prevents cascading failures by opening the circuit after repeated failures.
        When open, calls fail fast without attempting the operation.
    
    .PARAMETER Name
        Unique name for this circuit breaker
    
    .PARAMETER ScriptBlock
        Operation to execute
    
    .PARAMETER FailureThreshold
        Number of failures before opening circuit (default: 5)
    
    .PARAMETER TimeoutSeconds
        Seconds before attempting to close circuit (default: 60)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,
        
        [Parameter()]
        [int]$FailureThreshold = 5,
        
        [Parameter()]
        [int]$TimeoutSeconds = 60
    )
    
    # Initialize circuit breaker if not exists
    if (-not $script:CircuitBreakers.ContainsKey($Name)) {
        $script:CircuitBreakers[$Name] = @{
            State = 'CLOSED'  # CLOSED, OPEN, HALF_OPEN
            Failures = 0
            LastFailureTime = $null
            LastSuccessTime = $null
        }
    }
    
    $cb = $script:CircuitBreakers[$Name]
    
    # Check if we should transition from OPEN to HALF_OPEN
    if ($cb.State -eq 'OPEN') {
        $elapsed = (Get-Date) - $cb.LastFailureTime
        if ($elapsed.TotalSeconds -ge $TimeoutSeconds) {
            Write-ResilienceLog "Circuit breaker '$Name' entering HALF_OPEN state" "WARN"
            $cb.State = 'HALF_OPEN'
        } else {
            throw "Circuit breaker '$Name' is OPEN. Try again in $($TimeoutSeconds - [int]$elapsed.TotalSeconds) seconds."
        }
    }
    
    try {
        $result = & $ScriptBlock
        
        # Success - close the circuit
        if ($cb.State -ne 'CLOSED') {
            Write-ResilienceLog "Circuit breaker '$Name' closing (success)" "SUCCESS"
            $cb.State = 'CLOSED'
            $cb.Failures = 0
        }
        $cb.LastSuccessTime = Get-Date
        
        return $result
    }
    catch {
        $cb.Failures++
        $cb.LastFailureTime = Get-Date
        
        if ($cb.Failures -ge $FailureThreshold) {
            Write-ResilienceLog "Circuit breaker '$Name' opening after $($cb.Failures) failures" "ERROR"
            $cb.State = 'OPEN'
        }
        
        throw
    }
}

function Get-CircuitBreakerStatus {
    <#
    .SYNOPSIS
        Returns the status of all circuit breakers.
    #>
    return $script:CircuitBreakers.Clone()
}

function Reset-CircuitBreaker {
    <#
    .SYNOPSIS
        Resets a circuit breaker to closed state.
    #>
    param([Parameter(Mandatory = $true)][string]$Name)
    
    if ($script:CircuitBreakers.ContainsKey($Name)) {
        $script:CircuitBreakers[$Name] = @{
            State = 'CLOSED'
            Failures = 0
            LastFailureTime = $null
            LastSuccessTime = $null
        }
        Write-ResilienceLog "Circuit breaker '$Name' reset" "INFO"
    }
}

#endregion

#region Process Management

function Start-ResilientProcess {
    <#
    .SYNOPSIS
        Starts a process with enhanced monitoring and timeout handling.
    
    .DESCRIPTION
        Wraps process execution with:
        - Timeout handling with graceful termination
        - Output capture
        - Exit code checking
        - Resource cleanup
    
    .PARAMETER FilePath
        Path to executable
    
    .PARAMETER Arguments
        Arguments to pass
    
    .PARAMETER TimeoutSeconds
        Maximum execution time (default: 300)
    
    .PARAMETER WorkingDirectory
        Working directory for the process
    
    .PARAMETER EnvironmentVariables
        Additional environment variables
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        
        [Parameter()]
        [string]$Arguments = "",
        
        [Parameter()]
        [int]$TimeoutSeconds = 300,
        
        [Parameter()]
        [string]$WorkingDirectory = ".",
        
        [Parameter()]
        [hashtable]$EnvironmentVariables = @{}
    )
    
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FilePath
    $psi.Arguments = $Arguments
    $psi.WorkingDirectory = $WorkingDirectory
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    
    # Add environment variables
    foreach ($key in $EnvironmentVariables.Keys) {
        $psi.Environment[$key] = $EnvironmentVariables[$key]
    }
    
    $process = $null
    $stdout = $null
    $stderr = $null
    
    try {
        $process = [System.Diagnostics.Process]::Start($psi)
        
        # Read output asynchronously to prevent deadlock
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        
        # Wait with timeout
        $completed = $process.WaitForExit($TimeoutSeconds * 1000)
        
        if (-not $completed) {
            Write-ResilienceLog "Process timed out after ${TimeoutSeconds}s, terminating..." "WARN"
            
            # Try graceful termination first
            $process.CloseMainWindow() | Out-Null
            
            # Give it a moment to close gracefully
            $graceful = $process.WaitForExit(5000)
            
            if (-not $graceful) {
                Write-ResilienceLog "Force killing process..." "WARN"
                $process.Kill()
            }
            
            throw "Process timed out after ${TimeoutSeconds} seconds"
        }
        
        # Get output
        $stdout = $stdoutTask.Result
        $stderr = $stderrTask.Result
        
        return [PSCustomObject]@{
            ExitCode = $process.ExitCode
            Stdout = $stdout
            Stderr = $stderr
            Duration = $null  # Could measure actual duration
            Success = $process.ExitCode -eq 0
        }
    }
    finally {
        if ($process) {
            $process.Dispose()
        }
    }
}

#endregion

#region Logging

function Write-ResilienceLog {
    <#
    .SYNOPSIS
        Writes a log message with resilience-specific formatting.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter()]
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $prefix = "[RESILIENCE]"
    
    $colorMap = @{
        "INFO" = "White"
        "WARN" = "Yellow"
        "ERROR" = "Red"
        "SUCCESS" = "Green"
    }
    
    Write-Host "[$timestamp] $prefix [$Level] $Message" -ForegroundColor $colorMap[$Level]
}

#endregion

#region Graceful Degradation

function Invoke-WithFallback {
    <#
    .SYNOPSIS
        Executes a primary operation with fallback options.
    
    .DESCRIPTION
        Tries the primary operation first. If it fails, tries each fallback
        in order until one succeeds or all fail.
    
    .PARAMETER Primary
        Primary operation to try
    
    .PARAMETER Fallbacks
        Array of fallback script blocks
    
    .PARAMETER OnFallback
        Callback when falling back (receives fallback index and error)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$Primary,
        
        [Parameter()]
        [scriptblock[]]$Fallbacks = @(),
        
        [Parameter()]
        [scriptblock]$OnFallback = $null
    )
    
    try {
        return & $Primary
    }
    catch {
        $primaryError = $_
        Write-ResilienceLog "Primary operation failed: $($primaryError.Exception.Message)" "WARN"
        
        for ($i = 0; $i -lt $Fallbacks.Count; $i++) {
            if ($OnFallback) {
                & $OnFallback $i $primaryError
            }
            
            Write-ResilienceLog "Trying fallback $($i + 1) of $($Fallbacks.Count)..." "INFO"
            
            try {
                $result = & $Fallbacks[$i]
                Write-ResilienceLog "Fallback $($i + 1) succeeded" "SUCCESS"
                return $result
            }
            catch {
                Write-ResilienceLog "Fallback $($i + 1) failed: $($_.Exception.Message)" "WARN"
            }
        }
        
        throw "All operations failed. Primary error: $($primaryError.Exception.Message)"
    }
}

#endregion

#region Exports

Export-ModuleMember -Function @(
    'Invoke-WithRetry',
    'Test-RetryableError',
    'Invoke-WithCircuitBreaker',
    'Get-CircuitBreakerStatus',
    'Reset-CircuitBreaker',
    'Start-ResilientProcess',
    'Write-ResilienceLog',
    'Invoke-WithFallback'
)

#endregion
