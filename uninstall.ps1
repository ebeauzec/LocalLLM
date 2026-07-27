#Requires -Version 5.1
# ============================================================================
# Copyright (c) 2025-2026 Eugene Beauzec. All Rights Reserved.
# Project: LocalLLM - Self-Contained Local AI Platform
# File:    uninstall.ps1 - Standalone Uninstaller
# ============================================================================

<#
.SYNOPSIS
    Standalone uninstaller for LocalLLM.

.DESCRIPTION
    Provides a standalone entry point for uninstalling LocalLLM.
    This script delegates to the management CLI's uninstall command,
    but can also perform cleanup independently if the CLI is unavailable.

.EXAMPLE
    .\uninstall.ps1

.NOTES
    Requires: Administrator privileges
    Author:   Eugene Beauzec
    License:  Proprietary - All Rights Reserved
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Administrator Elevation
# ---------------------------------------------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

if (-not $isAdmin) {
    Write-Host ""
    Write-Host "  Uninstaller requires Administrator privileges." -ForegroundColor Yellow
    Write-Host "  Restarting with elevated permissions..." -ForegroundColor Yellow
    $pwshPath = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
    if (-not $pwshPath) { $pwshPath = (Get-Command powershell -ErrorAction SilentlyContinue).Source }
    Start-Process $pwshPath -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs -WorkingDirectory $PSScriptRoot
    exit 0
}

# ---------------------------------------------------------------------------
# Main Uninstall Logic
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
Write-Host "  ║          LocalLLM Uninstaller                           ║" -ForegroundColor Yellow
Write-Host "  ╚══════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
Write-Host ""

$cliPath = Join-Path $PSScriptRoot "localllm.ps1"

if (Test-Path $cliPath) {
    # Delegate to the management CLI
    & $cliPath uninstall
} else {
    # Fallback: manual cleanup if CLI is missing
    Write-Host "  [WARNING] Management CLI not found. Performing manual cleanup..." -ForegroundColor Yellow
    Write-Host ""

    # Try to find and stop Docker containers
    Write-Host "  ⚠️  This will attempt to remove all LocalLLM Docker resources." -ForegroundColor Red
    Write-Host ""
    Write-Host "  Type 'UNINSTALL' to confirm:" -ForegroundColor Red
    $confirm = Read-Host "  "

    if ($confirm -ne 'UNINSTALL') {
        Write-Host "  Cancelled." -ForegroundColor Green
        exit 0
    }

    # Try Docker Compose down
    $composePath = Join-Path $PSScriptRoot "config" "docker-compose.yml"
    if (Test-Path $composePath) {
        try {
            Write-Host "  Stopping containers..." -ForegroundColor Gray
            docker compose -f $composePath down -v --remove-orphans 2>&1 | Out-Null
            Write-Host "  ✅ Containers removed." -ForegroundColor Green
        } catch {
            Write-Host "  ⚠️  Could not stop containers (Docker may not be running)." -ForegroundColor Yellow
        }
    }

    # Remove generated directories
    $dirsToRemove = @('config', 'data', 'logs')
    foreach ($dir in $dirsToRemove) {
        $path = Join-Path $PSScriptRoot $dir
        if (Test-Path $path) {
            Write-Host "  Removing $dir/..." -ForegroundColor Gray
            Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # Remove state file
    $stateFile = Join-Path $PSScriptRoot ".localllm-install-state.json"
    if (Test-Path $stateFile) {
        Remove-Item -Path $stateFile -Force -ErrorAction SilentlyContinue
    }

    Write-Host ""
    Write-Host "  ✅ Manual cleanup complete." -ForegroundColor Green
    Write-Host "  You may now delete this project folder if desired." -ForegroundColor Gray
    Write-Host ""
}
