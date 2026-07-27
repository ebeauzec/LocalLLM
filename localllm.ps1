#Requires -Version 5.1
# ============================================================================
# Copyright (c) 2025-2026 Eugene Beauzec. All Rights Reserved.
# Project: LocalLLM - Self-Contained Local AI Platform
# File:    localllm.ps1 - Management CLI
# ============================================================================

<#
.SYNOPSIS
    Management CLI for LocalLLM services.

.DESCRIPTION
    Provides commands to start, stop, monitor, update, and manage
    the LocalLLM platform and its services.

.PARAMETER Command
    The management command to execute.

.PARAMETER Options
    Additional options for the command.

.EXAMPLE
    .\localllm.ps1 start
    .\localllm.ps1 status
    .\localllm.ps1 doctor
    .\localllm.ps1 add-model qwen3:8b
    .\localllm.ps1 logs ollama
    .\localllm.ps1 uninstall

.NOTES
    Author:  Eugene Beauzec
    License: Proprietary - All Rights Reserved
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0, Mandatory = $false)]
    [ValidateSet('start', 'stop', 'restart', 'status', 'update', 'models',
                 'add-model', 'remove-model', 'logs', 'config', 'doctor',
                 'backup', 'privacy', 'uninstall', 'help', '')]
    [string]$Command = 'help',

    [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
    [string[]]$Options
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Load library modules
# ---------------------------------------------------------------------------
$script:LibPath = Join-Path $PSScriptRoot "lib"
$script:EnvFile = Join-Path $PSScriptRoot "config" ".env"

# Load utils if available
$utilsPath = Join-Path $script:LibPath "utils.ps1"
if (Test-Path $utilsPath) { . $utilsPath }

# Load health check if available
$healthPath = Join-Path $script:LibPath "health-check.ps1"
if (Test-Path $healthPath) { . $healthPath }

# Load wizard if available
$wizardPath = Join-Path $script:LibPath "wizard.ps1"
if (Test-Path $wizardPath) { . $wizardPath }

# Load system-detect if available
$sysDetectPath = Join-Path $script:LibPath "system-detect.ps1"
if (Test-Path $sysDetectPath) { . $sysDetectPath }

# Load privacy guard if available
$privacyPath = Join-Path $script:LibPath "privacy-guard.ps1"
if (Test-Path $privacyPath) { . $privacyPath }

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Get-ComposeFile {
    $composePath = Join-Path $PSScriptRoot "config" "docker-compose.yml"
    if (-not (Test-Path $composePath)) {
        Write-Host "  [ERROR] docker-compose.yml not found at: $composePath" -ForegroundColor Red
        Write-Host "  Run install.ps1 first to set up LocalLLM." -ForegroundColor Yellow
        exit 1
    }
    return $composePath
}

function Get-InstallConfig {
    $configPath = Join-Path $PSScriptRoot "config" ".env"
    if (Test-Path $configPath) {
        $config = @{}
        Get-Content $configPath | ForEach-Object {
            if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
                $config[$Matches[1].Trim()] = $Matches[2].Trim()
            }
        }
        return $config
    }
    return @{ WEBUI_PORT = '3000'; OLLAMA_PORT = '11434'; LITELLM_PORT = '4000' }
}

function Show-Header {
    Write-Host ""
    Write-Host "  LocalLLM" -ForegroundColor Cyan -NoNewline
    Write-Host " — Management CLI" -ForegroundColor DarkGray
    Write-Host ""
}

# ---------------------------------------------------------------------------
# Command: help
# ---------------------------------------------------------------------------
function Show-Help {
    Show-Header
    $help = @"
  Usage: .\localllm.ps1 <command> [options]

  Service Management:
    start                 Start all LocalLLM services
    stop                  Stop all LocalLLM services
    restart               Restart all LocalLLM services
    status                Show service status, health, and resource usage

  Model Management:
    models                List all installed models
    add-model <name>      Download and install a new model
    remove-model <name>   Remove an installed model

  Maintenance:
    update                Pull latest Docker images and update models
    doctor                Run diagnostics with auto-healing
    backup                Backup chat history and configuration
    logs [service]        View service logs (ollama|litellm|open-webui|searxng)

  Privacy & Security:
    privacy [mode]        Set privacy mode (strict|balanced|permissive)
    privacy report        View privacy audit report (local vs cloud usage)
    privacy status        Show current privacy settings
    privacy blocklist     Manage custom sensitive data patterns

  Configuration:
    config                Re-run the configuration wizard

  Removal:
    uninstall             Completely remove LocalLLM and all data

  Information:
    help                  Show this help message

  Examples:
    .\localllm.ps1 start
    .\localllm.ps1 add-model llama3.3:8b
    .\localllm.ps1 logs ollama
    .\localllm.ps1 doctor
"@
    Write-Host $help
}

# ---------------------------------------------------------------------------
# Command: start
# ---------------------------------------------------------------------------
function Invoke-Start {
    Show-Header
    $composePath = Get-ComposeFile
    $config = Get-InstallConfig

    Write-Host "  Starting LocalLLM services..." -ForegroundColor Cyan

    # Check Docker is running
    try {
        $null = docker info 2>&1
    } catch {
        Write-Host "  Docker is not running. Attempting to start Docker Desktop..." -ForegroundColor Yellow
        Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe" -ErrorAction SilentlyContinue
        Write-Host "  Waiting for Docker daemon (up to 60s)..." -ForegroundColor Gray
        $timeout = 60
        $elapsed = 0
        while ($elapsed -lt $timeout) {
            Start-Sleep -Seconds 2
            $elapsed += 2
            try { $null = docker info 2>&1; break } catch { }
        }
        if ($elapsed -ge $timeout) {
            Write-Host "  [ERROR] Docker did not start in time. Start Docker Desktop manually." -ForegroundColor Red
            exit 1
        }
    }

    docker compose -f $composePath up -d
    Write-Host ""
    Write-Host "  ✅ Services started!" -ForegroundColor Green
    Write-Host "  🌐 Open: http://localhost:$($config.WEBUI_PORT ?? '3000')" -ForegroundColor Cyan
    Write-Host ""
}

# ---------------------------------------------------------------------------
# Command: stop
# ---------------------------------------------------------------------------
function Invoke-Stop {
    Show-Header
    $composePath = Get-ComposeFile

    Write-Host "  Stopping LocalLLM services..." -ForegroundColor Yellow
    docker compose -f $composePath down
    Write-Host ""
    Write-Host "  ✅ All services stopped." -ForegroundColor Green
    Write-Host ""
}

# ---------------------------------------------------------------------------
# Command: restart
# ---------------------------------------------------------------------------
function Invoke-Restart {
    Show-Header
    $composePath = Get-ComposeFile

    Write-Host "  Restarting LocalLLM services..." -ForegroundColor Cyan
    docker compose -f $composePath restart
    Write-Host ""
    Write-Host "  ✅ Services restarted." -ForegroundColor Green
    Write-Host ""
}

# ---------------------------------------------------------------------------
# Command: status
# ---------------------------------------------------------------------------
function Invoke-Status {
    Show-Header
    $composePath = Get-ComposeFile
    $config = Get-InstallConfig

    Write-Host "  ┌─────────────────────────────────────────────────────┐" -ForegroundColor Cyan
    Write-Host "  │  Service Status                                      │" -ForegroundColor Cyan
    Write-Host "  └─────────────────────────────────────────────────────┘" -ForegroundColor Cyan
    Write-Host ""

    # Container status
    docker compose -f $composePath ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

    Write-Host ""

    # Quick endpoint checks
    $endpoints = @(
        @{ Name = "Open WebUI"; Url = "http://localhost:$($config.WEBUI_PORT ?? '3000')" },
        @{ Name = "Ollama";     Url = "http://localhost:$($config.OLLAMA_PORT ?? '11434')" },
        @{ Name = "LiteLLM";   Url = "http://localhost:$($config.LITELLM_PORT ?? '4000')/health" }
    )

    foreach ($ep in $endpoints) {
        try {
            $response = Invoke-WebRequest -Uri $ep.Url -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
            $status = "✅ Responding"
            $color = "Green"
        } catch {
            $status = "❌ Not responding"
            $color = "Red"
        }
        Write-Host "  $($ep.Name.PadRight(15)) $status" -ForegroundColor $color
    }

    # Model count
    Write-Host ""
    try {
        $models = (Invoke-RestMethod -Uri "http://localhost:$($config.OLLAMA_PORT ?? '11434')/api/tags" -TimeoutSec 5).models
        Write-Host "  Models loaded: $($models.Count)" -ForegroundColor Cyan
        foreach ($m in $models) {
            $sizeGB = [math]::Round($m.size / 1GB, 1)
            Write-Host "    • $($m.name) ($($sizeGB) GB)" -ForegroundColor Gray
        }
    } catch {
        Write-Host "  Models: Unable to query (Ollama may be starting)" -ForegroundColor Yellow
    }
    Write-Host ""
}

# ---------------------------------------------------------------------------
# Command: models
# ---------------------------------------------------------------------------
function Invoke-Models {
    Show-Header
    Write-Host "  Installed Models:" -ForegroundColor Cyan
    Write-Host ""

    $config = Get-InstallConfig
    try {
        $models = (Invoke-RestMethod -Uri "http://localhost:$($config.OLLAMA_PORT ?? '11434')/api/tags" -TimeoutSec 10).models
        if ($models.Count -eq 0) {
            Write-Host "  No models installed." -ForegroundColor Yellow
            Write-Host "  Use: .\localllm.ps1 add-model <name>" -ForegroundColor Gray
        } else {
            Write-Host "  $('-' * 70)" -ForegroundColor DarkGray
            Write-Host "  $('Name'.PadRight(35)) $('Size'.PadRight(12)) Modified" -ForegroundColor White
            Write-Host "  $('-' * 70)" -ForegroundColor DarkGray
            foreach ($m in $models) {
                $sizeGB = [math]::Round($m.size / 1GB, 1)
                $modified = if ($m.modified_at) { ([DateTime]$m.modified_at).ToString('yyyy-MM-dd') } else { 'N/A' }
                Write-Host "  $($m.name.PadRight(35)) $("$($sizeGB) GB".PadRight(12)) $modified" -ForegroundColor Gray
            }
            Write-Host "  $('-' * 70)" -ForegroundColor DarkGray
            Write-Host ""
            Write-Host "  Total: $($models.Count) model(s)" -ForegroundColor Cyan
        }
    } catch {
        Write-Host "  [ERROR] Cannot connect to Ollama. Is it running?" -ForegroundColor Red
        Write-Host "  Try: .\localllm.ps1 start" -ForegroundColor Gray
    }
    Write-Host ""
}

# ---------------------------------------------------------------------------
# Command: add-model
# ---------------------------------------------------------------------------
function Invoke-AddModel {
    Show-Header
    if (-not $Options -or $Options.Count -eq 0) {
        Write-Host "  Usage: .\localllm.ps1 add-model <model-name>" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Examples:" -ForegroundColor Gray
        Write-Host "    .\localllm.ps1 add-model llama3.3:8b" -ForegroundColor Gray
        Write-Host "    .\localllm.ps1 add-model qwen3:14b" -ForegroundColor Gray
        Write-Host "    .\localllm.ps1 add-model deepseek-r1:8b" -ForegroundColor Gray
        Write-Host ""
        return
    }

    $modelName = $Options[0]
    Write-Host "  Downloading model: $modelName" -ForegroundColor Cyan
    Write-Host "  This may take several minutes depending on model size and connection..." -ForegroundColor Gray
    Write-Host ""

    docker exec ollama ollama pull $modelName
    Write-Host ""
    Write-Host "  ✅ Model '$modelName' installed successfully." -ForegroundColor Green
    Write-Host ""
}

# ---------------------------------------------------------------------------
# Command: remove-model
# ---------------------------------------------------------------------------
function Invoke-RemoveModel {
    Show-Header
    if (-not $Options -or $Options.Count -eq 0) {
        Write-Host "  Usage: .\localllm.ps1 remove-model <model-name>" -ForegroundColor Yellow
        return
    }

    $modelName = $Options[0]
    $confirm = Read-Host "  Remove model '$modelName'? This cannot be undone. [y/N]"
    if ($confirm -eq 'y' -or $confirm -eq 'Y') {
        docker exec ollama ollama rm $modelName
        Write-Host "  ✅ Model '$modelName' removed." -ForegroundColor Green
    } else {
        Write-Host "  Cancelled." -ForegroundColor Gray
    }
    Write-Host ""
}

# ---------------------------------------------------------------------------
# Command: update
# ---------------------------------------------------------------------------
function Invoke-Update {
    Show-Header
    $composePath = Get-ComposeFile

    Write-Host "  Updating LocalLLM..." -ForegroundColor Cyan
    Write-Host ""

    # Pull latest images
    Write-Host "  📦 Pulling latest Docker images..." -ForegroundColor Gray
    docker compose -f $composePath pull

    # Recreate containers with new images
    Write-Host ""
    Write-Host "  🔄 Restarting services with updated images..." -ForegroundColor Gray
    docker compose -f $composePath up -d

    # Update models
    Write-Host ""
    Write-Host "  🧠 Updating installed models..." -ForegroundColor Gray
    $config = Get-InstallConfig
    try {
        $models = (Invoke-RestMethod -Uri "http://localhost:$($config.OLLAMA_PORT ?? '11434')/api/tags" -TimeoutSec 10).models
        foreach ($m in $models) {
            Write-Host "    Updating $($m.name)..." -ForegroundColor Gray
            docker exec ollama ollama pull $m.name 2>&1 | Out-Null
        }
    } catch {
        Write-Host "    ⚠️  Could not update models (Ollama may still be starting)" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "  ✅ Update complete." -ForegroundColor Green
    Write-Host ""
}

# ---------------------------------------------------------------------------
# Command: logs
# ---------------------------------------------------------------------------
function Invoke-Logs {
    Show-Header
    $composePath = Get-ComposeFile

    $service = if ($Options -and $Options.Count -gt 0) { $Options[0] } else { $null }
    $validServices = @('ollama', 'litellm', 'open-webui', 'searxng')

    if ($service -and $service -notin $validServices) {
        Write-Host "  Invalid service: $service" -ForegroundColor Red
        Write-Host "  Valid services: $($validServices -join ', ')" -ForegroundColor Gray
        return
    }

    Write-Host "  Showing logs (Ctrl+C to exit)..." -ForegroundColor Gray
    Write-Host ""

    if ($service) {
        docker compose -f $composePath logs --tail 100 -f $service
    } else {
        docker compose -f $composePath logs --tail 50 -f
    }
}

# ---------------------------------------------------------------------------
# Command: doctor
# ---------------------------------------------------------------------------
function Invoke-Doctor {
    Show-Header
    Write-Host "  🩺 Running diagnostics..." -ForegroundColor Cyan
    Write-Host ""

    $results = Invoke-HealthCheck
    Show-HealthReport -Results $results

    $failures = ($results | Where-Object { $_.Status -eq 'Fail' })
    if ($failures.Count -gt 0) {
        Write-Host ""
        $autoFix = Read-Host "  Attempt automatic repair for $($failures.Count) issue(s)? [Y/n]"
        if ($autoFix -ne 'n' -and $autoFix -ne 'N') {
            foreach ($fail in $failures) {
                if ($fail.AutoFixAvailable) {
                    Write-Host "  🔧 Repairing: $($fail.Name)..." -ForegroundColor Yellow
                    Repair-Service -CheckResult $fail
                }
            }
            Write-Host ""
            Write-Host "  Re-running checks..." -ForegroundColor Gray
            $results = Invoke-HealthCheck
            Show-HealthReport -Results $results
        }
    } else {
        Write-Host "  ✅ All checks passed! Your LocalLLM installation is healthy." -ForegroundColor Green
    }
    Write-Host ""
}

# ---------------------------------------------------------------------------
# Command: backup
# ---------------------------------------------------------------------------
function Invoke-Backup {
    Show-Header
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backupDir = Join-Path $PSScriptRoot "backups" "backup-$timestamp"

    Write-Host "  Creating backup at: $backupDir" -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

    # Backup config
    $configDir = Join-Path $PSScriptRoot "config"
    if (Test-Path $configDir) {
        Copy-Item -Path $configDir -Destination (Join-Path $backupDir "config") -Recurse
        Write-Host "  ✅ Configuration backed up." -ForegroundColor Green
    }

    # Backup Open WebUI data (chat history)
    $webuiData = Join-Path $PSScriptRoot "data" "open-webui"
    if (Test-Path $webuiData) {
        Write-Host "  Backing up chat history (this may take a moment)..." -ForegroundColor Gray
        Copy-Item -Path $webuiData -Destination (Join-Path $backupDir "open-webui-data") -Recurse
        Write-Host "  ✅ Chat history backed up." -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "  ✅ Backup complete: $backupDir" -ForegroundColor Green
    Write-Host ""
}

# ---------------------------------------------------------------------------
# Command: privacy
# ---------------------------------------------------------------------------
function Invoke-Privacy {
    Show-Header
    $subcommand = if ($Options -and $Options.Count -gt 0) { $Options[0].ToLower() } else { 'status' }

    switch ($subcommand) {
        'strict' {
            Set-PrivacyMode -Mode 'STRICT'
            Write-Host "  🔒 Privacy mode set to STRICT." -ForegroundColor Green
            Write-Host "     All processing will stay local. Cloud APIs are disabled." -ForegroundColor Gray
            Write-Host "     Restart services to apply: .\localllm.ps1 restart" -ForegroundColor Cyan
        }
        'balanced' {
            Set-PrivacyMode -Mode 'BALANCED'
            Write-Host "  🛡️  Privacy mode set to BALANCED." -ForegroundColor Yellow
            Write-Host "     Local-first with guarded cloud fallback." -ForegroundColor Gray
            Write-Host "     Restart services to apply: .\localllm.ps1 restart" -ForegroundColor Cyan
        }
        'permissive' {
            Set-PrivacyMode -Mode 'PERMISSIVE'
            Write-Host "  ⚠️  Privacy mode set to PERMISSIVE." -ForegroundColor Red
            Write-Host "     Cloud access allowed. Sensitive data will be auto-redacted." -ForegroundColor Gray
            Write-Host "     Restart services to apply: .\localllm.ps1 restart" -ForegroundColor Cyan
        }
        'report' {
            $report = Get-PrivacyReport
            Write-Host "  📊 Privacy Audit Report" -ForegroundColor Cyan
            Write-Host "  $('-' * 50)" -ForegroundColor DarkGray
            Write-Host "  Total Requests:      $($report.TotalRequests)" -ForegroundColor White
            Write-Host "  Kept Local:          $($report.LocalRequests) ($($report.LocalPercentage)%)" -ForegroundColor Green
            Write-Host "  Sent to Cloud:       $($report.CloudRequests) ($($report.CloudPercentage)%)" -ForegroundColor Yellow
            Write-Host "  Blocked (sensitive): $($report.BlockedRequests)" -ForegroundColor Red
            Write-Host "  Est. Cost Saved:     `$$($report.EstimatedSavings)" -ForegroundColor Green
            Write-Host "  $('-' * 50)" -ForegroundColor DarkGray

            if ($report.DetectionsByType -and $report.DetectionsByType.Count -gt 0) {
                Write-Host ""
                Write-Host "  Sensitive Data Detections:" -ForegroundColor Cyan
                foreach ($detection in $report.DetectionsByType.GetEnumerator()) {
                    Write-Host "    • $($detection.Key): $($detection.Value) occurrence(s)" -ForegroundColor Gray
                }
            }
        }
        'status' {
            Show-PrivacyStatus
        }
        'blocklist' {
            if ($Options.Count -gt 1 -and $Options[1] -eq 'add') {
                $pattern = if ($Options.Count -gt 2) { $Options[2..($Options.Count-1)] -join ' ' } else { Read-Host "  Enter pattern to block" }
                Update-PrivacyBlocklist -Pattern $pattern -Action 'Add'
                Write-Host "  ✅ Pattern added to blocklist." -ForegroundColor Green
            } elseif ($Options.Count -gt 1 -and $Options[1] -eq 'show') {
                $blocklistPath = Join-Path $PSScriptRoot "config" "privacy-blocklist.txt"
                if (Test-Path $blocklistPath) {
                    Write-Host "  Current blocklist patterns:" -ForegroundColor Cyan
                    Get-Content $blocklistPath | ForEach-Object { Write-Host "    • $_" -ForegroundColor Gray }
                } else {
                    Write-Host "  No custom blocklist configured." -ForegroundColor Yellow
                    Write-Host "  Use: .\localllm.ps1 privacy blocklist add <pattern>" -ForegroundColor Gray
                }
            } else {
                Write-Host "  Usage:" -ForegroundColor Cyan
                Write-Host "    .\localllm.ps1 privacy blocklist add <pattern>  — Add a pattern" -ForegroundColor Gray
                Write-Host "    .\localllm.ps1 privacy blocklist show           — Show all patterns" -ForegroundColor Gray
            }
        }
        default {
            Write-Host "  Usage:" -ForegroundColor Cyan
            Write-Host "    .\localllm.ps1 privacy strict       — Maximum privacy (no cloud)" -ForegroundColor Gray
            Write-Host "    .\localllm.ps1 privacy balanced     — Smart privacy (default)" -ForegroundColor Gray
            Write-Host "    .\localllm.ps1 privacy permissive   — Allow cloud (auto-redact)" -ForegroundColor Gray
            Write-Host "    .\localllm.ps1 privacy report       — View audit report" -ForegroundColor Gray
            Write-Host "    .\localllm.ps1 privacy status       — Show current settings" -ForegroundColor Gray
            Write-Host "    .\localllm.ps1 privacy blocklist    — Manage data blocklist" -ForegroundColor Gray
        }
    }
    Write-Host ""
}

# ---------------------------------------------------------------------------
# Command: config
# ---------------------------------------------------------------------------
function Invoke-Config {
    Show-Header
    Write-Host "  Re-running configuration wizard..." -ForegroundColor Cyan
    Write-Host "  Note: This will regenerate your configuration files." -ForegroundColor Yellow
    Write-Host ""

    $confirm = Read-Host "  Continue? [y/N]"
    if ($confirm -eq 'y' -or $confirm -eq 'Y') {
        $systemProfile = Get-SystemProfile
        $config = Start-ConfigurationWizard -SystemProfile $systemProfile
        Write-Host ""
        Write-Host "  ✅ Configuration updated. Restart services to apply changes:" -ForegroundColor Green
        Write-Host "     .\localllm.ps1 restart" -ForegroundColor Cyan
    } else {
        Write-Host "  Cancelled." -ForegroundColor Gray
    }
    Write-Host ""
}

# ---------------------------------------------------------------------------
# Command: uninstall
# ---------------------------------------------------------------------------
function Invoke-Uninstall {
    Show-Header
    Write-Host "  ⚠️  This will completely remove LocalLLM from your system." -ForegroundColor Red
    Write-Host ""
    Write-Host "  The following will be removed:" -ForegroundColor Yellow
    Write-Host "    • All Docker containers and networks" -ForegroundColor Gray
    Write-Host "    • Configuration files" -ForegroundColor Gray
    Write-Host "    • Installer state files" -ForegroundColor Gray
    Write-Host ""

    # Ask about data
    $removeModels = Read-Host "  Also remove downloaded AI models? (saves disk space) [y/N]"
    $removeData = Read-Host "  Also remove chat history and uploaded files? [y/N]"
    Write-Host ""

    Write-Host "  Type 'UNINSTALL' to confirm complete removal:" -ForegroundColor Red
    $confirm = Read-Host "  "

    if ($confirm -ne 'UNINSTALL') {
        Write-Host ""
        Write-Host "  Uninstall cancelled." -ForegroundColor Green
        return
    }

    Write-Host ""
    Write-Host "  Removing LocalLLM..." -ForegroundColor Yellow

    $composePath = Join-Path $PSScriptRoot "config" "docker-compose.yml"

    # Stop and remove containers
    if (Test-Path $composePath) {
        Write-Host "  Stopping containers..." -ForegroundColor Gray
        docker compose -f $composePath down --remove-orphans 2>&1 | Out-Null

        if ($removeModels -eq 'y' -or $removeModels -eq 'Y') {
            Write-Host "  Removing Docker volumes (models + data)..." -ForegroundColor Gray
            docker compose -f $composePath down -v 2>&1 | Out-Null
        }
    }

    # Remove config directory
    $configDir = Join-Path $PSScriptRoot "config"
    if (Test-Path $configDir) {
        Write-Host "  Removing configuration files..." -ForegroundColor Gray
        Remove-Item -Path $configDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Remove data if requested
    if ($removeData -eq 'y' -or $removeData -eq 'Y') {
        $dataDir = Join-Path $PSScriptRoot "data"
        if (Test-Path $dataDir) {
            Write-Host "  Removing data files..." -ForegroundColor Gray
            Remove-Item -Path $dataDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # Remove models if requested
    if ($removeModels -eq 'y' -or $removeModels -eq 'Y') {
        $ollamaData = Join-Path $PSScriptRoot "data" "ollama"
        if (Test-Path $ollamaData) {
            Write-Host "  Removing model files..." -ForegroundColor Gray
            Remove-Item -Path $ollamaData -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # Remove state file
    $stateFile = Join-Path $PSScriptRoot ".localllm-install-state.json"
    if (Test-Path $stateFile) {
        Remove-Item -Path $stateFile -Force -ErrorAction SilentlyContinue
    }

    # Remove logs
    $logDir = Join-Path $PSScriptRoot "logs"
    if (Test-Path $logDir) {
        Remove-Item -Path $logDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "  ║   ✅ LocalLLM has been successfully uninstalled.        ║" -ForegroundColor Green
    Write-Host "  ║                                                          ║" -ForegroundColor Green
    Write-Host "  ║   The following were NOT removed (manual removal):       ║" -ForegroundColor Gray
    Write-Host "  ║   • Docker Desktop (may be used by other apps)          ║" -ForegroundColor Gray
    Write-Host "  ║   • WSL2 (system feature)                               ║" -ForegroundColor Gray
    Write-Host "  ║   • This project folder                                 ║" -ForegroundColor Gray
    Write-Host "  ║                                                          ║" -ForegroundColor Green
    Write-Host "  ║   To completely remove, delete this folder:              ║" -ForegroundColor Gray
    Write-Host "  ║   $($PSScriptRoot.PadRight(55).Substring(0,55))║" -ForegroundColor Cyan
    Write-Host "  ║                                                          ║" -ForegroundColor Green
    Write-Host "  ╚══════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
}

# ---------------------------------------------------------------------------
# Command Dispatcher
# ---------------------------------------------------------------------------
try {
    switch ($Command) {
        'start'        { Invoke-Start }
        'stop'         { Invoke-Stop }
        'restart'      { Invoke-Restart }
        'status'       { Invoke-Status }
        'update'       { Invoke-Update }
        'models'       { Invoke-Models }
        'add-model'    { Invoke-AddModel }
        'remove-model' { Invoke-RemoveModel }
        'logs'         { Invoke-Logs }
        'config'       { Invoke-Config }
        'doctor'       { Invoke-Doctor }
        'backup'       { Invoke-Backup }
        'privacy'      { Invoke-Privacy }
        'uninstall'    { Invoke-Uninstall }
        'help'         { Show-Help }
        default        { Show-Help }
    }
} catch {
    Write-Host ""
    Write-Host "  [ERROR] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Run '.\localllm.ps1 doctor' to diagnose issues." -ForegroundColor Gray
    Write-Host ""
    exit 1
}
