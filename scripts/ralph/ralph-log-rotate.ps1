#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Log rotation and maintenance script for Ralph production system

.DESCRIPTION
    Manages log files to prevent disk space issues:
    - Rotates logs when they exceed size threshold
    - Compresses rotated logs
    - Deletes old logs after retention period
    - Archives metrics and alerts

.PARAMETER LogPath
    Path to log directory (default: .ralph/logs)

.PARAMETER MaxLogSizeMB
    Maximum size before rotation (default: 10)

.PARAMETER MaxLogDays
    Days to keep logs (default: 30)

.PARAMETER ArchiveDays
    Days to keep archives (default: 90)

.EXAMPLE
    .\ralph-log-rotate.ps1

.EXAMPLE
    .\ralph-log-rotate.ps1 -MaxLogDays 7 -Verbose
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$LogPath = ".ralph/logs",
    
    [Parameter()]
    [int]$MaxLogSizeMB = 10,
    
    [Parameter()]
    [int]$MaxLogDays = 30,
    
    [Parameter()]
    [int]$ArchiveDays = 90
)

$ErrorActionPreference = "Stop"

function Write-LogRotateLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [LOG-ROTATE] [$Level] $Message"
    
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "White" }
    }
    Write-Host $logEntry -ForegroundColor $color
}

function Invoke-LogRotation {
    param([string]$LogDir)
    
    $rotated = 0
    $compressed = 0
    
    # Get all log files (not already compressed)
    $logFiles = Get-ChildItem -Path $LogDir -Filter "*.log" -File
    
    foreach ($logFile in $logFiles) {
        $sizeMB = $logFile.Length / 1MB
        
        if ($sizeMB -gt $MaxLogSizeMB) {
            Write-LogRotateLog -Message "Rotating $($logFile.Name) ($([math]::Round($sizeMB,2)) MB)" -Level "WARN"
            
            # Generate archive name
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $archiveName = "$($logFile.BaseName)-$timestamp.log"
            $archivePath = Join-Path $LogDir "archive" $archiveName
            
            try {
                # Move to archive
                Move-Item -Path $logFile.FullName -Destination $archivePath -Force
                $rotated++
                
                # Compress
                $zipPath = "$archivePath.zip"
                Compress-Archive -Path $archivePath -DestinationPath $zipPath -Force
                Remove-Item -Path $archivePath -Force
                $compressed++
                
                Write-LogRotateLog -Message "Compressed to $([System.IO.Path]::GetFileName($zipPath))" -Level "SUCCESS"
            } catch {
                Write-LogRotateLog -Message "Failed to rotate $($logFile.Name): $_" -Level "ERROR"
            }
        }
    }
    
    return @{ Rotated = $rotated; Compressed = $compressed }
}

function Remove-OldLogs {
    param([string]$LogDir, [int]$Days)
    
    $cutoff = (Get-Date).AddDays(-$Days)
    $removed = 0
    $freedSpace = 0
    
    # Clean old log files
    Get-ChildItem -Path $LogDir -Filter "*.log" -File | 
        Where-Object { $_.LastWriteTime -lt $cutoff } |
        ForEach-Object {
            Write-LogRotateLog -Message "Deleting old log: $($_.Name)" -Level "WARN"
            $freedSpace += $_.Length
            Remove-Item $_.FullName -Force
            $removed++
        }
    
    # Clean old archives
    $archiveDir = Join-Path $LogDir "archive"
    if (Test-Path $archiveDir) {
        Get-ChildItem -Path $archiveDir -Filter "*.zip" -File |
            Where-Object { $_.LastWriteTime -lt $cutoff } |
            ForEach-Object {
                Write-LogRotateLog -Message "Deleting old archive: $($_.Name)" -Level "WARN"
                $freedSpace += $_.Length
                Remove-Item $_.FullName -Force
                $removed++
            }
    }
    
    return @{ Removed = $removed; FreedSpace = [math]::Round($freedSpace / 1MB, 2) }
}

function Archive-Metrics {
    param([int]$Days)
    
    $metricsDir = ".ralph/metrics"
    $alertsDir = ".ralph/alerts"
    $cutoff = (Get-Date).AddDays(-$Days)
    $archived = 0
    
    # Archive old metrics
    if (Test-Path $metricsDir) {
        $archiveDir = Join-Path $metricsDir "archive"
        New-Item -ItemType Directory -Force -Path $archiveDir | Out-Null
        
        Get-ChildItem -Path $metricsDir -Filter "*.json" -File |
            Where-Object { $_.LastWriteTime -lt $cutoff -and $_.Name -ne "watchdog-metrics.json" } |
            ForEach-Object {
                $dest = Join-Path $archiveDir $_.Name
                Move-Item $_.FullName $dest -Force
                $archived++
            }
    }
    
    # Archive old alerts
    if (Test-Path $alertsDir) {
        $archiveDir = Join-Path $alertsDir "archive"
        New-Item -ItemType Directory -Force -Path $archiveDir | Out-Null
        
        Get-ChildItem -Path $alertsDir -Filter "*.json" -File |
            Where-Object { $_.LastWriteTime -lt $cutoff } |
            ForEach-Object {
                $dest = Join-Path $archiveDir $_.Name
                Move-Item $_.FullName $dest -Force
                $archived++
            }
    }
    
    return $archived
}

function Get-DiskUsage {
    param([string]$LogDir)
    
    $totalSize = 0
    $fileCount = 0
    
    if (Test-Path $LogDir) {
        Get-ChildItem -Path $LogDir -Recurse -File | ForEach-Object {
            $totalSize += $_.Length
            $fileCount++
        }
    }
    
    return @{
        TotalSizeMB = [math]::Round($totalSize / 1MB, 2)
        FileCount = $fileCount
    }
}

# Main execution
Write-LogRotateLog -Message "========================================"
Write-LogRotateLog -Message "RALPH LOG ROTATION STARTED"
Write-LogRotateLog -Message "========================================"
Write-LogRotateLog -Message "Log Path: $LogPath"
Write-LogRotateLog -Message "Max Size: $MaxLogSizeMB MB"
Write-LogRotateLog -Message "Max Age: $MaxLogDays days"

# Get initial usage
$beforeUsage = Get-DiskUsage -LogDir $LogPath
Write-LogRotateLog -Message "Current usage: $($beforeUsage.TotalSizeMB) MB ($($beforeUsage.FileCount) files)"

# Ensure directories exist
$archiveDir = Join-Path $LogPath "archive"
New-Item -ItemType Directory -Force -Path $LogPath | Out-Null
New-Item -ItemType Directory -Force -Path $archiveDir | Out-Null

# Rotate large logs
Write-LogRotateLog -Message "Checking for logs to rotate..."
$rotation = Invoke-LogRotation -LogDir $LogPath
Write-LogRotateLog -Message "Rotated $($rotation.Rotated) logs, compressed $($rotation.Compressed)"

# Clean old logs
Write-LogRotateLog -Message "Cleaning logs older than $MaxLogDays days..."
$cleanup = Remove-OldLogs -LogDir $LogPath -Days $MaxLogDays
Write-LogRotateLog -Message "Removed $($cleanup.Removed) files, freed $($cleanup.FreedSpace) MB"

# Archive metrics
Write-LogRotateLog -Message "Archiving metrics..."
$archived = Archive-Metrics -Days $ArchiveDays
Write-LogRotateLog -Message "Archived $archived metrics/alerts"

# Get final usage
$afterUsage = Get-DiskUsage -LogDir $LogPath
$saved = $beforeUsage.TotalSizeMB - $afterUsage.TotalSizeMB
Write-LogRotateLog -Message "Final usage: $($afterUsage.TotalSizeMB) MB ($($afterUsage.FileCount) files)"
Write-LogRotateLog -Message "Space saved: $saved MB" -Level $(if($saved -gt 0){"SUCCESS"}else{"INFO"})

Write-LogRotateLog -Message "========================================"
Write-LogRotateLog -Message "LOG ROTATION COMPLETE"
Write-LogRotateLog -Message "========================================"

# Exit with appropriate code
exit 0
