#Requires -Version 5.1
# ============================================================================
# Copyright (c) 2025-2026 Eugene Beauzec. All Rights Reserved.
# Project: LocalLLM - Self-Contained Local AI Platform
# File:    start.ps1 - One-Click Launcher
# ============================================================================

<#
.SYNOPSIS
    The simplest way to use LocalLLM. Just run this.

.DESCRIPTION
    Smart launcher that auto-detects your environment:
    - First run?  → Runs the full installer (install.ps1)
    - Already installed?  → Starts services and opens your browser
    - Services already running?  → Just opens your browser

    All conversations, uploads, settings, and model weights persist
    between sessions in the data/ directory. When you stop and restart,
    everything picks up exactly where you left off.

.EXAMPLE
    .\start.ps1              # Start LocalLLM (install if needed)
    .\start.ps1 -Stop        # Graceful shutdown, return all resources
    .\start.ps1 -Status      # Check if services are running
    .\start.ps1 -Analytics   # View cost savings dashboard

.NOTES
    Author:  Eugene Beauzec
    License: Proprietary - All Rights Reserved
#>

param(
    [switch]$Stop,
    [switch]$Status,
    [switch]$Analytics,
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Detect project root (where this script lives)
# ---------------------------------------------------------------------------
$ProjectRoot = $PSScriptRoot
$ConfigDir = Join-Path $ProjectRoot 'config'
$DataDir = Join-Path $ProjectRoot 'data'
$ComposeFile = Join-Path $ConfigDir 'docker-compose.yml'
$VersionFile = Join-Path $ProjectRoot 'VERSION'
$Version = if (Test-Path $VersionFile) { (Get-Content $VersionFile -Raw).Trim() } else { 'unknown' }

# ---------------------------------------------------------------------------
# Quick actions: --Stop, --Status, --Analytics, --Uninstall
# ---------------------------------------------------------------------------
if ($Stop) {
    & "$ProjectRoot\localllm.ps1" stop
    exit 0
}
if ($Status) {
    & "$ProjectRoot\localllm.ps1" status
    exit 0
}
if ($Analytics) {
    & "$ProjectRoot\localllm.ps1" analytics
    exit 0
}
if ($Uninstall) {
    & "$ProjectRoot\localllm.ps1" uninstall
    exit 0
}

# ---------------------------------------------------------------------------
# Banner
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║              LocalLLM v$Version                       ║" -ForegroundColor Cyan
Write-Host "  ║       Your Private AI — Running 100% Locally        ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ---------------------------------------------------------------------------
# Decision: Install or Start?
# ---------------------------------------------------------------------------
$isInstalled = (Test-Path $ComposeFile) -and (Test-Path $DataDir)

if (-not $isInstalled) {
    # ── FIRST RUN: Full installation ──
    Write-Host "  🔧 First time? Let's set everything up!" -ForegroundColor Yellow
    Write-Host "     This will install Docker, download AI models," -ForegroundColor Gray
    Write-Host "     and configure your private AI assistant." -ForegroundColor Gray
    Write-Host ""
    Write-Host "     Estimated time: 10-30 minutes (depends on internet speed)" -ForegroundColor Gray
    Write-Host ""
    
    $confirm = Read-Host "  Press ENTER to start installation (or 'q' to quit)"
    if ($confirm -eq 'q') {
        Write-Host "  Cancelled." -ForegroundColor Yellow
        exit 0
    }
    
    & "$ProjectRoot\install.ps1"
    exit $LASTEXITCODE
}

# ── ALREADY INSTALLED: Start services ──
Write-Host "  ✅ LocalLLM is installed. Starting services..." -ForegroundColor Green
Write-Host ""

# Check if services are already running
$alreadyRunning = $false
try {
    $containers = docker compose -f $ComposeFile --project-directory $ProjectRoot ps -q 2>$null
    if ($containers -and $containers.Count -gt 0) {
        # Check if WebUI is healthy
        try {
            $null = Invoke-WebRequest -Uri "http://localhost:3000/health" -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
            $alreadyRunning = $true
        } catch { }
    }
} catch { }

if ($alreadyRunning) {
    Write-Host "  🟢 Services are already running!" -ForegroundColor Green
    Write-Host ""
    Start-Process "http://localhost:3000"
    Write-Host "  🌐 Opened: http://localhost:3000" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Your conversations, uploads, and settings are all here." -ForegroundColor Gray
    Write-Host "  To stop:       .\start.ps1 -Stop" -ForegroundColor DarkGray
    Write-Host "  To analytics:  .\start.ps1 -Analytics" -ForegroundColor DarkGray
    Write-Host ""
    exit 0
}

# Start services
& "$ProjectRoot\localllm.ps1" start

Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "  ║              LocalLLM is Ready!                     ║" -ForegroundColor Green
Write-Host "  ╚══════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "  📝 All your conversations persist between sessions." -ForegroundColor White
Write-Host "  📁 Uploaded documents stay in your knowledge base." -ForegroundColor White
Write-Host "  🧠 AI picks up exactly where you left off." -ForegroundColor White
Write-Host ""
Write-Host "  Quick Commands:" -ForegroundColor Cyan
Write-Host "    .\start.ps1              Start & open browser" -ForegroundColor Gray
Write-Host "    .\start.ps1 -Stop        Graceful shutdown" -ForegroundColor Gray
Write-Host "    .\start.ps1 -Status      Check service status" -ForegroundColor Gray
Write-Host "    .\start.ps1 -Analytics   View cost savings" -ForegroundColor Gray
Write-Host ""
