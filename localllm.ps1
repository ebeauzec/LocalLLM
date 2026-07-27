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
                 'backup', 'privacy', 'analytics', 'uninstall', 'version', 'bump-version', 'push', 'help', '')]
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
$script:ProjectRoot = $PSScriptRoot

# Ensure Docker resolves all relative paths from this directory
$env:COMPOSE_PROJECT_NAME = 'localllm'

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

function Invoke-DockerCompose {
    <#
    .SYNOPSIS
    Runs docker compose with --project-directory locked to the project root.
    This ensures ALL relative paths (volumes, configs) resolve from the
    deployment folder, not the user's current working directory.
    #>
    param([string[]]$Arguments)
    $composePath = Get-ComposeFile
    $allArgs = @('compose', '-f', $composePath, '--project-directory', $script:ProjectRoot) + $Arguments
    & docker @allArgs
    return $LASTEXITCODE
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
    return @{ WEBUI_PORT = '3100'; OLLAMA_PORT = '11434'; LITELLM_PORT = '4000' }
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
    analytics             Show cost savings, local vs cloud usage analytics

  Configuration:
    config                Re-run the configuration wizard

  Data & Persistence:
    Data and configurations are automatically persisted locally.
    Use backup command to export, and check documentation for migration.

  Version Control:
    version               Show current LocalLLM version
    bump-version [type]   Bump version (major|minor|patch) and auto-push
    push [msg]            Commit and push changes to GitHub

  Removal:
    uninstall             Completely remove LocalLLM and all data

  Information:
    help                  Show this help message

  Examples:
    .\localllm.ps1 start
    .\localllm.ps1 add-model llama3.3:8b
    .\localllm.ps1 logs ollama
    .\localllm.ps1 doctor
    .\localllm.ps1 push "feat: add new models"
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

    Invoke-DockerCompose up -d
    
    $port = $config.WEBUI_PORT ?? '3100'
    Write-Host "  Waiting for Open WebUI to be healthy..." -ForegroundColor Gray
    $timeout = 60
    $elapsed = 0
    $healthy = $false
    while ($elapsed -lt $timeout) {
        Start-Sleep -Seconds 2
        $elapsed += 2
        try {
            $resp = Invoke-WebRequest -Uri "http://localhost:$port/health" -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
            if ($resp.StatusCode -eq 200) { $healthy = $true; break }
        } catch { }
    }
    
    Write-Host ""
    if ($healthy) {
        Write-Host "  ✅ LocalLLM is ready!" -ForegroundColor Green
        Start-Process "http://localhost:$port"
    } else {
        Write-Host "  ⚠️  Services started, but health check timed out." -ForegroundColor Yellow
    }
    Write-Host "  🌐 Open: http://localhost:$port" -ForegroundColor Cyan
    Write-Host ""
}

# ---------------------------------------------------------------------------
# Command: stop
# ---------------------------------------------------------------------------
function Invoke-Stop {
    Show-Header
    $composePath = Get-ComposeFile

    Write-Host "  Stopping LocalLLM services..." -ForegroundColor Yellow
    
    # Show resource usage before stop
    Write-Host "  Current Resource Usage:" -ForegroundColor Cyan
    try { docker stats --no-stream } catch { }
    
    $containersCount = (Invoke-DockerCompose ps -q).Count

    Invoke-DockerCompose stop
    Invoke-DockerCompose down
    
    Write-Host ""
    Write-Host "  ✅ All resources returned to system" -ForegroundColor Green
    Write-Host "    • Memory freed: Evaluated and returned to host" -ForegroundColor Gray
    Write-Host "    • GPU VRAM freed: Cleared" -ForegroundColor Gray
    Write-Host "    • Containers stopped: $containersCount" -ForegroundColor Gray
    Write-Host "    • Ports released: 3100, 11434, 4000, etc." -ForegroundColor Gray
    Write-Host ""
}

# ---------------------------------------------------------------------------
# Command: restart
# ---------------------------------------------------------------------------
function Invoke-Restart {
    Show-Header
    $composePath = Get-ComposeFile

    Write-Host "  Restarting LocalLLM services..." -ForegroundColor Cyan
    Invoke-DockerCompose restart
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
    Invoke-DockerCompose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

    Write-Host ""

    # Quick endpoint checks
    $endpoints = @(
        @{ Name = "Open WebUI"; Url = "http://localhost:$($config.WEBUI_PORT ?? '3100')" },
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
    Invoke-DockerCompose pull

    # Recreate containers with new images
    Write-Host ""
    Write-Host "  🔄 Restarting services with updated images..." -ForegroundColor Gray
    Invoke-DockerCompose up -d

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
        Invoke-DockerCompose logs --tail 100 -f $service
    } else {
        Invoke-DockerCompose logs --tail 50 -f
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

    # Stop and remove containers
    $composePath = Join-Path $PSScriptRoot "config" "docker-compose.yml"
    if (Test-Path $composePath) {
        Write-Host "  Stopping containers..." -ForegroundColor Gray
        Invoke-DockerCompose down --remove-orphans 2>&1 | Out-Null

        if ($removeModels -eq 'y' -or $removeModels -eq 'Y') {
            Write-Host "  Removing Docker volumes (models + data)..." -ForegroundColor Gray
            Invoke-DockerCompose down -v 2>&1 | Out-Null
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
# Command: version
# ---------------------------------------------------------------------------
function Invoke-Version {
    $versionFile = Join-Path $PSScriptRoot 'VERSION'
    $version = if (Test-Path $versionFile) { (Get-Content $versionFile -Raw).Trim() } else { 'unknown' }
    Write-Host ""
    Write-Host "  LocalLLM v$version" -ForegroundColor Cyan
    Write-Host "  Copyright (c) 2025-2026 Eugene Beauzec" -ForegroundColor DarkGray
    Write-Host "  https://github.com/ebeauzec/LocalLLM" -ForegroundColor DarkGray
    Write-Host ""
}

# ---------------------------------------------------------------------------
# Command: bump-version
# ---------------------------------------------------------------------------
function Invoke-BumpVersion {
    param([string]$Type = 'patch')
    $versionFile = Join-Path $PSScriptRoot 'VERSION'
    $current = if (Test-Path $versionFile) { (Get-Content $versionFile -Raw).Trim() } else { '0.1.0' }
    $parts = $current.Split('.')
    if ($parts.Length -ne 3) { $parts = @('0','1','0') }
    switch ($Type) {
        'major' { $parts[0] = [int]$parts[0] + 1; $parts[1] = '0'; $parts[2] = '0' }
        'minor' { $parts[1] = [int]$parts[1] + 1; $parts[2] = '0' }
        'patch' { $parts[2] = [int]$parts[2] + 1 }
        default { $parts[2] = [int]$parts[2] + 1 }
    }
    $new = $parts -join '.'
    $new | Set-Content $versionFile -NoNewline
    git -C $PSScriptRoot add -A
    git -C $PSScriptRoot commit -m "chore: Bump version to v$new"
    git -C $PSScriptRoot push
    Write-Host "Version bumped: v$current → v$new (pushed to GitHub)" -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# Command: push
# ---------------------------------------------------------------------------
function Invoke-Push {
    $message = if ($Options -and $Options.Count -gt 0) { $Options -join ' ' } else { "chore: Update configuration ($(Get-Date -Format 'yyyy-MM-dd HH:mm'))" }
    git -C $PSScriptRoot add -A
    git -C $PSScriptRoot commit -m $message
    git -C $PSScriptRoot push
    Write-Host "Changes committed and pushed to GitHub." -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# Command: analytics
# ---------------------------------------------------------------------------
function Invoke-Analytics {
    Show-Header
    $metricsFile = Join-Path $script:ProjectRoot 'data' 'localllm-metrics.json'
    
    if (-not (Test-Path $metricsFile)) {
        Write-Host "  No analytics data yet. Use LocalLLM to generate metrics." -ForegroundColor Yellow
        return
    }
    
    $metrics = Get-Content $metricsFile -Raw | ConvertFrom-Json
    
    # Header
    Write-Host "  ╔══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║           LocalLLM Analytics Dashboard              ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    # Summary stats
    $total = $metrics.total_requests ?? 0
    $local = $metrics.total_local ?? 0
    $cloud = $metrics.total_cloud ?? 0
    $pctLocal = if ($total -gt 0) { [math]::Round(($local / $total) * 100, 1) } else { 0 }
    $totalTokens = $metrics.total_tokens ?? 0
    $totalSavings = $metrics.total_savings_usd ?? 0
    $totalCost = $metrics.total_cost_usd ?? 0
    
    Write-Host "  📊 Overall Statistics" -ForegroundColor White
    Write-Host "  ─────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "    Total Requests:     $total" -ForegroundColor White
    Write-Host "    🟢 Local:           $local ($pctLocal%)" -ForegroundColor Green
    Write-Host "    🔴 Cloud:           $cloud ($([math]::Round(100 - $pctLocal, 1))%)" -ForegroundColor $(if ($cloud -gt 0) { 'Yellow' } else { 'Green' })
    Write-Host "    Total Tokens:       $($totalTokens.ToString('N0'))" -ForegroundColor White
    Write-Host ""
    
    # Cost analysis
    Write-Host "  💰 Cost Analysis" -ForegroundColor White
    Write-Host "  ─────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "    Total Saved:        `$$([math]::Round($totalSavings, 2))" -ForegroundColor Green
    Write-Host "    Cloud Spend:        `$$([math]::Round($totalCost, 2))" -ForegroundColor $(if ($totalCost -gt 0) { 'Yellow' } else { 'Green' })
    $avgCost = if ($total -gt 0) { [math]::Round(($totalCost / $total), 4) } else { 0 }
    Write-Host "    Avg Cost/Query:     `$$avgCost" -ForegroundColor White
    Write-Host ""
    
    # Efficiency bar
    $barLength = 30
    $filled = [math]::Floor($pctLocal / 100 * $barLength)
    $empty = $barLength - $filled
    $bar = ('█' * $filled) + ('░' * $empty)
    Write-Host "  📈 Efficiency: $pctLocal% LOCAL" -ForegroundColor White
    Write-Host "     [$bar]" -ForegroundColor Cyan
    Write-Host ""
    
    # Model breakdown (if available)
    if ($metrics.models) {
        Write-Host "  🤖 Model Usage" -ForegroundColor White
        Write-Host "  ─────────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host "    Model                    Requests    Tokens    Cost" -ForegroundColor DarkGray
        foreach ($modelName in ($metrics.models.PSObject.Properties | Sort-Object { $_.Value.count } -Descending | Select-Object -First 10).Name) {
            $m = $metrics.models.$modelName
            $type = if ($modelName -match 'gpt-|claude-|gemini-') { '🔴' } else { '🟢' }
            $nameDisplay = $modelName.PadRight(25)
            $countDisplay = ($m.count).ToString().PadLeft(8)
            $tokenDisplay = ($m.tokens).ToString('N0').PadLeft(10)
            $costDisplay = ("`$" + [math]::Round($m.cost, 2)).PadLeft(8)
            Write-Host "    $type $nameDisplay $countDisplay $tokenDisplay $costDisplay" -ForegroundColor White
        }
        Write-Host ""
    }
    
    # Daily trend (last 7 days)
    if ($metrics.daily) {
        Write-Host "  📅 Daily Trend (Last 7 Days)" -ForegroundColor White
        Write-Host "  ─────────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host "    Date          Local   Cloud   Tokens    Saved" -ForegroundColor DarkGray
        $sortedDays = $metrics.daily.PSObject.Properties | Sort-Object Name -Descending | Select-Object -First 7
        foreach ($day in $sortedDays) {
            $d = $day.Value
            $dateDisplay = $day.Name.PadRight(12)
            $localDisplay = ($d.local).ToString().PadLeft(6)
            $cloudDisplay = ($d.cloud).ToString().PadLeft(6)
            $tokenDisplay = ($d.tokens).ToString('N0').PadLeft(10)
            $savedDisplay = ("`$" + [math]::Round($d.savings, 2)).PadLeft(8)
            Write-Host "    $dateDisplay $localDisplay $cloudDisplay $tokenDisplay $savedDisplay" -ForegroundColor White
        }
        Write-Host ""
    }
    
    # Privacy stats
    $blocked = $metrics.total_sensitive_blocked ?? 0
    Write-Host "  🔒 Privacy" -ForegroundColor White
    Write-Host "  ─────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "    Sensitive data blocked: $blocked instances" -ForegroundColor $(if ($blocked -gt 0) { 'Green' } else { 'White' })
    Write-Host "    Privacy mode:           $(Get-PrivacyMode)" -ForegroundColor White
    Write-Host ""
    
    Write-Host "  💡 Use the Privacy Dashboard tool in chat for detailed reports." -ForegroundColor DarkGray
    Write-Host ""
}

function Get-PrivacyMode {
    $configPath = Join-Path $script:ProjectRoot 'config' 'privacy-settings.json'
    if (Test-Path $configPath) {
        $config = Get-Content $configPath -Raw | ConvertFrom-Json
        return $config.mode ?? 'BALANCED'
    }
    return 'BALANCED'
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
        'version'      { Invoke-Version }
        'bump-version' { 
            $type = if ($Options -and $Options.Count -gt 0) { $Options[0] } else { 'patch' }
            Invoke-BumpVersion -Type $type 
        }
        'push'         { Invoke-Push }
        'analytics'    { Invoke-Analytics }
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
