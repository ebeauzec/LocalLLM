# ============================================================================
# LocalLLM — Graceful Shutdown
# Copyright (c) 2025-2026 Eugene Beauzec. All Rights Reserved.
#
# Stops all LocalLLM containers while preserving data (models, chat history,
# settings). Run .\start.ps1 to bring everything back up.
# ============================================================================

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║          LocalLLM — Shutting Down                   ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Find the compose file
$composePath = Join-Path $ProjectRoot "config\docker-compose.yml"

if (-not (Test-Path $composePath)) {
    Write-Host "  ⚠  No active deployment found." -ForegroundColor Yellow
    Write-Host "     (config\docker-compose.yml not found)" -ForegroundColor DarkGray
    Write-Host ""
    
    # Check if any containers are still running from a previous deployment
    $running = docker ps --filter "name=localllm" --format "{{.Names}}" 2>$null
    if ($running) {
        Write-Host "  Found orphaned containers. Stopping..." -ForegroundColor Yellow
        docker stop $running.Split("`n") 2>&1 | Out-Null
        docker rm $running.Split("`n") 2>&1 | Out-Null
        Write-Host "  ✅ Cleaned up orphaned containers." -ForegroundColor Green
    }
    Write-Host ""
    exit 0
}

# Show what's running
Write-Host "  Stopping services..." -ForegroundColor White
$containers = docker ps --filter "name=localllm" --format "{{.Names}}" 2>$null
if ($containers) {
    foreach ($c in $containers.Split("`n")) {
        if ($c.Trim()) {
            Write-Host "    • $($c.Trim())" -ForegroundColor DarkGray
        }
    }
} else {
    Write-Host "  No running containers found." -ForegroundColor DarkGray
}
Write-Host ""

# Graceful shutdown — preserves all volumes
Push-Location $ProjectRoot
& docker compose -f "$composePath" --project-directory "$ProjectRoot" down 2>&1 | ForEach-Object {
    if ($_ -match "Stopped|Removed|Removing|Stopping") {
        Write-Host "    $_" -ForegroundColor DarkGray
    }
}
Pop-Location

# Verify everything is stopped
$remaining = docker ps --filter "name=localllm" --format "{{.Names}}" 2>$null
if ($remaining) {
    Write-Host "  ⚠  Some containers still running. Force stopping..." -ForegroundColor Yellow
    docker stop $remaining.Split("`n") 2>&1 | Out-Null
}

# Show preserved volumes
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "  ║          LocalLLM Stopped Successfully              ║" -ForegroundColor Green
Write-Host "  ╚══════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "  Your data is preserved:" -ForegroundColor White
Write-Host "    • Models      — ready, no re-download needed" -ForegroundColor DarkGray
Write-Host "    • Chat history — saved" -ForegroundColor DarkGray
Write-Host "    • Settings     — saved" -ForegroundColor DarkGray
Write-Host "    • API keys     — saved" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  To start again:" -ForegroundColor White
Write-Host "    .\start.ps1" -ForegroundColor Cyan
Write-Host ""
