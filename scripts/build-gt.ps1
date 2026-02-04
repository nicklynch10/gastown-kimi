#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Build Gastown CLI (gt) with proper version information

.DESCRIPTION
    This script builds the gt binary with proper ldflags to inject
    version, commit, build time, and the BuiltProperly flag.

    Without these flags, gt will fail with:
    "This binary was built with 'go build' directly"

.PARAMETER Version
    Version string (default: "dev")

.PARAMETER Output
    Output binary path (default: "gt.exe")

.EXAMPLE
    .\build-gt.ps1
    # Builds gt.exe with default version

.EXAMPLE
    .\build-gt.ps1 -Version "1.2.3" -Output "C:\tools\gt.exe"
    # Builds with specific version and output path
#>

[CmdletBinding()]
param(
    [string]$Version = "dev",
    [string]$Output = "gt.exe"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Building Gastown CLI (gt)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check prerequisites
$go = Get-Command go -ErrorAction SilentlyContinue
if (-not $go) {
    Write-Error "Go is not installed. Install from https://go.dev/dl/"
    exit 1
}

# Get git commit hash
$commit = "unknown"
try {
    $commit = git rev-parse --short HEAD 2>$null
} catch {
    Write-Warning "Could not get git commit hash"
}

# Get build time
$buildTime = Get-Date -Format "o"

# Build ldflags
$ldflags = @(
    "-X github.com/steveyegge/gastown/internal/cmd.Version=$Version"
    "-X github.com/steveyegge/gastown/internal/cmd.Commit=$commit"
    "-X github.com/steveyegge/gastown/internal/cmd.BuildTime=$buildTime"
    "-X github.com/steveyegge/gastown/internal/cmd.BuiltProperly=1"
) -join " "

Write-Host "Version:    $Version" -ForegroundColor Gray
Write-Host "Commit:     $commit" -ForegroundColor Gray
Write-Host "Build Time: $buildTime" -ForegroundColor Gray
Write-Host "Output:     $Output" -ForegroundColor Gray
Write-Host ""

# Build
Write-Host "Building..." -ForegroundColor Yellow
$buildCmd = "go build -ldflags `"$ldflags`" -o $Output ./cmd/gt"
Write-Host "> $buildCmd" -ForegroundColor DarkGray

Invoke-Expression $buildCmd

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ Build successful!" -ForegroundColor Green
    Write-Host "   Binary: $Output" -ForegroundColor Green
    
    # Test the binary
    Write-Host ""
    Write-Host "Testing binary..." -ForegroundColor Yellow
    $testOutput = & ./$Output version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Binary works correctly" -ForegroundColor Green
        Write-Host "   $testOutput" -ForegroundColor Gray
    } else {
        Write-Warning "Binary built but version check failed: $testOutput"
    }
} else {
    Write-Error "Build failed!"
    exit 1
}
