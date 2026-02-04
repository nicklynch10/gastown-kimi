#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Build Gas Town CLI (gt) on Windows with proper version info.

.DESCRIPTION
    This script builds the gt.exe binary with proper version flags.
    It uses PowerShell-compatible commands instead of Unix date/git.

.EXAMPLE
    .\scripts\build-gt-windows.ps1

.EXAMPLE
    .\scripts\build-gt-windows.ps1 -OutputPath C:\Tools\gt.exe
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$OutputPath = "gt.exe"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Gas Town CLI (gt) Windows Build      " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check prerequisites
Write-Host "Checking prerequisites..." -ForegroundColor White

$go = Get-Command go -ErrorAction SilentlyContinue
if (-not $go) {
    Write-Host "ERROR: Go is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Install from: https://go.dev/dl/" -ForegroundColor Gray
    exit 1
}
Write-Host "  Go: $($go.Source)" -ForegroundColor Green

$git = Get-Command git -ErrorAction SilentlyContinue
if (-not $git) {
    Write-Host "ERROR: Git is not installed or not in PATH" -ForegroundColor Red
    exit 1
}
Write-Host "  Git: $($git.Source)" -ForegroundColor Green

# Get version info
Write-Host ""
Write-Host "Getting version info..." -ForegroundColor White

$VERSION = git describe --tags --always --dirty 2>$null
if (-not $VERSION) { $VERSION = "dev" }

$COMMIT = git rev-parse --short HEAD 2>$null
if (-not $COMMIT) { $COMMIT = "unknown" }

$BUILD_TIME = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")

Write-Host "  Version: $VERSION" -ForegroundColor Gray
Write-Host "  Commit: $COMMIT" -ForegroundColor Gray
Write-Host "  Build Time: $BUILD_TIME" -ForegroundColor Gray

# Build ldflags
$LDFLAGS = @(
    "-X github.com/steveyegge/gastown/internal/cmd.Version=$VERSION"
    "-X github.com/steveyegge/gastown/internal/cmd.Commit=$COMMIT"
    "-X github.com/steveyegge/gastown/internal/cmd.BuildTime=$BUILD_TIME"
    "-X github.com/steveyegge/gastown/internal/cmd.BuiltProperly=1"
) -join " "

Write-Host ""
Write-Host "Building gt.exe..." -ForegroundColor White

try {
    $buildCmd = "go build -ldflags `"$LDFLAGS`" -o $OutputPath ./cmd/gt"
    Write-Host "  Command: $buildCmd" -ForegroundColor DarkGray
    
    Invoke-Expression $buildCmd
    
    if ($LASTEXITCODE -ne 0) {
        throw "Build failed with exit code $LASTEXITCODE"
    }
    
    Write-Host "  Build successful!" -ForegroundColor Green
}
catch {
    Write-Host "  Build failed: $_" -ForegroundColor Red
    exit 1
}

# Verify the build
Write-Host ""
Write-Host "Verifying build..." -ForegroundColor White

if (-not (Test-Path $OutputPath)) {
    Write-Host "  ERROR: Output file not found: $OutputPath" -ForegroundColor Red
    exit 1
}

$fileInfo = Get-Item $OutputPath
Write-Host "  Output: $($fileInfo.FullName)" -ForegroundColor Gray
Write-Host "  Size: $([math]::Round($fileInfo.Length / 1MB, 2)) MB" -ForegroundColor Gray

# Check version
$versionOutput = & $fileInfo.FullName version 2>&1
Write-Host "  Version: $versionOutput" -ForegroundColor Gray

if ($versionOutput -match "built with 'go build' directly") {
    Write-Host "  WARNING: Version info not properly embedded" -ForegroundColor Yellow
} else {
    Write-Host "  Version info: OK" -ForegroundColor Green
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Build Complete!                      " -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor White
$outputName = Split-Path $OutputPath -Leaf
Write-Host "  1. Test: .\$outputName version" -ForegroundColor Gray
Write-Host "  2. Run: .\$outputName doctor" -ForegroundColor Gray
Write-Host "  3. Copy to PATH if desired" -ForegroundColor Gray
