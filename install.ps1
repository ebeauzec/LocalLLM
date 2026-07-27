#Requires -Version 5.1
# ============================================================================
# Copyright (c) 2025-2026 Eugene Beauzec. All Rights Reserved.
# Project: LocalLLM - Self-Contained Local AI Platform
# File:    install.ps1 - Main Installer Orchestrator
# ============================================================================

<#
.SYNOPSIS
    Main installer for LocalLLM - a self-contained local AI platform.

.DESCRIPTION
    This script orchestrates the complete installation of LocalLLM, including:
    - System hardware and software detection
    - Model selection based on hardware capabilities
    - Interactive configuration wizard
    - Prerequisite installation (WSL2, Docker, NVIDIA toolkit)
    - Docker Compose deployment of all services
    - Model downloading and verification
    - Health checks and self-healing diagnostics

    The installer saves progress to a state file, allowing it to resume
    from the last successful step if interrupted.

.EXAMPLE
    # Run the installer (will auto-elevate to Administrator)
    .\install.ps1

.EXAMPLE
    # Resume a previously interrupted installation
    .\install.ps1

.EXAMPLE
    # Force a clean reinstall from scratch
    .\install.ps1 -Force

.NOTES
    Requires: Windows 10/11 64-bit, PowerShell 5.1+, Administrator privileges
    Author:   Eugene Beauzec
    License:  Proprietary - All Rights Reserved
#>

[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$SkipBrowser,
    [string]$InstallPath
)

# ---------------------------------------------------------------------------
# Strict mode and error handling
# ---------------------------------------------------------------------------
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue' # Speed up web requests

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
$script:LOCALLLM_VERSION = '0.1.0'
$script:TOTAL_STEPS = 9
$script:STATE_FILE = Join-Path $PSScriptRoot '.localllm-install-state.json'

# ---------------------------------------------------------------------------
# Administrator Elevation
# ---------------------------------------------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

if (-not $isAdmin) {
    Write-Host ""
    Write-Host "  LocalLLM requires Administrator privileges." -ForegroundColor Yellow
    Write-Host "  Restarting with elevated permissions..." -ForegroundColor Yellow
    Write-Host ""

    $arguments = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"")
    if ($Force) { $arguments += "-Force" }
    if ($SkipBrowser) { $arguments += "-SkipBrowser" }
    if ($InstallPath) { $arguments += "-InstallPath `"$InstallPath`"" }

    Start-Process powershell -ArgumentList ($arguments -join ' ') -Verb RunAs
    exit 0
}

# ---------------------------------------------------------------------------
# Load Library Modules
# ---------------------------------------------------------------------------
$script:LibPath = Join-Path $PSScriptRoot "lib"

$modules = @(
    'utils.ps1',
    'system-detect.ps1',
    'model-selector.ps1',
    'prerequisites.ps1',
    'wizard.ps1',
    'deploy.ps1',
    'health-check.ps1',
    'privacy-guard.ps1',
    'setup-models.ps1',
    'configure-webui.ps1'
)

foreach ($mod in $modules) {
    $modPath = Join-Path $script:LibPath $mod
    if (Test-Path $modPath) {
        . $modPath
    } else {
        Write-Host "  [ERROR] Missing module: lib/$mod" -ForegroundColor Red
        Write-Host "  Please ensure all files are present. Re-clone the repository if needed." -ForegroundColor Red
        Write-Host "  git clone https://github.com/ebeauzec/LocalLLM.git" -ForegroundColor Cyan
        exit 1
    }
}

# ---------------------------------------------------------------------------
# State Management (Resume Support)
# ---------------------------------------------------------------------------
function Get-InstallState {
    if ($Force -or -not (Test-Path $script:STATE_FILE)) {
        return @{
            Version       = $script:LOCALLLM_VERSION
            StartedAt     = (Get-Date -Format 'o')
            LastStep      = 0
            CompletedAt   = $null
            SystemProfile = $null
            Configuration = $null
            SelectedModels = $null
        }
    }
    try {
        $state = Get-Content $script:STATE_FILE -Raw | ConvertFrom-Json
        # Convert back to hashtable for easier manipulation
        $ht = @{}
        $state.PSObject.Properties | ForEach-Object { $ht[$_.Name] = $_.Value }
        return $ht
    } catch {
        return @{ Version = $script:LOCALLLM_VERSION; StartedAt = (Get-Date -Format 'o'); LastStep = 0 }
    }
}

function Save-InstallState {
    param([hashtable]$State)
    $State | ConvertTo-Json -Depth 10 | Set-Content $script:STATE_FILE -Force
}

# ---------------------------------------------------------------------------
# Main Installation Flow
# ---------------------------------------------------------------------------
function Start-Installation {
    $state = Get-InstallState

    # Ensure log directory exists
    $logDir = Join-Path $PSScriptRoot "logs"
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

    # -----------------------------------------------------------------------
    # Banner
    # -----------------------------------------------------------------------
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║                                                          ║" -ForegroundColor Cyan
    Write-Host "  ║     ██╗      ██████╗  ██████╗ █████╗ ██╗     ██╗        ║" -ForegroundColor Cyan
    Write-Host "  ║     ██║     ██╔═══██╗██╔════╝██╔══██╗██║     ██║        ║" -ForegroundColor Cyan
    Write-Host "  ║     ██║     ██║   ██║██║     ███████║██║     ██║        ║" -ForegroundColor Cyan
    Write-Host "  ║     ██║     ██║   ██║██║     ██╔══██║██║     ██║        ║" -ForegroundColor Cyan
    Write-Host "  ║     ███████╗╚██████╔╝╚██████╗██║  ██║███████╗███████╗   ║" -ForegroundColor Cyan
    Write-Host "  ║     ╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝╚══════╝╚══════╝  ║" -ForegroundColor Cyan
    Write-Host "  ║              ██╗     ██╗     ███╗   ███╗                 ║" -ForegroundColor Magenta
    Write-Host "  ║              ██║     ██║     ████╗ ████║                 ║" -ForegroundColor Magenta
    Write-Host "  ║              ██║     ██║     ██╔████╔██║                 ║" -ForegroundColor Magenta
    Write-Host "  ║              ██║     ██║     ██║╚██╔╝██║                 ║" -ForegroundColor Magenta
    Write-Host "  ║              ███████╗███████╗██║ ╚═╝ ██║                ║" -ForegroundColor Magenta
    Write-Host "  ║              ╚══════╝╚══════╝╚═╝     ╚═╝                ║" -ForegroundColor Magenta
    Write-Host "  ║                                                          ║" -ForegroundColor Cyan
    Write-Host "  ║          Self-Contained Local AI Platform                ║" -ForegroundColor White
    Write-Host "  ║                  Version $script:LOCALLLM_VERSION                          ║" -ForegroundColor DarkGray
    Write-Host "  ║                                                          ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Copyright (c) 2025-2026 Eugene Beauzec. All Rights Reserved." -ForegroundColor DarkGray
    Write-Host ""

    # Check for resume
    if ($state.LastStep -gt 0 -and -not $Force) {
        Write-Host "  [INFO] Previous installation detected (completed step $($state.LastStep)/$script:TOTAL_STEPS)." -ForegroundColor Yellow
        Write-Host ""
        $resume = Read-Host "  Resume from step $($state.LastStep + 1)? [Y/n]"
        if ($resume -eq 'n' -or $resume -eq 'N') {
            $state.LastStep = 0
            Write-Host "  Starting fresh installation..." -ForegroundColor Cyan
        } else {
            Write-Host "  Resuming installation..." -ForegroundColor Green
        }
        Write-Host ""
    }

    try {
        # -------------------------------------------------------------------
        # STEP 1: System Assessment
        # -------------------------------------------------------------------
        if ($state.LastStep -lt 1) {
            Write-Host "  ┌─────────────────────────────────────────────────────┐" -ForegroundColor Cyan
            Write-Host "  │  Step 1/$script:TOTAL_STEPS: System Assessment                        │" -ForegroundColor Cyan
            Write-Host "  └─────────────────────────────────────────────────────┘" -ForegroundColor Cyan
            Write-Host ""

            Write-Host "  Scanning hardware and detecting existing tools..." -ForegroundColor Gray
            $systemProfile = Get-SystemProfile
            Show-SystemReport -SystemProfile $systemProfile

            $state.SystemProfile = $systemProfile
            $state.LastStep = 1
            Save-InstallState -State $state

            Write-Host ""
            Write-Host "  ✅ System assessment complete." -ForegroundColor Green
            Write-Host ""
            Start-Sleep -Seconds 1
        } else {
            Write-Host "  ⏭️  Step 1/$script:TOTAL_STEPS: System Assessment — skipped (already done)" -ForegroundColor DarkGray
            if (-not $state.SystemProfile) {
                $state.SystemProfile = Get-SystemProfile
            }
        }

        # -------------------------------------------------------------------
        # STEP 2: Model Selection
        # -------------------------------------------------------------------
        if ($state.LastStep -lt 2) {
            Write-Host "  ┌─────────────────────────────────────────────────────┐" -ForegroundColor Cyan
            Write-Host "  │  Step 2/$script:TOTAL_STEPS: Model Selection                          │" -ForegroundColor Cyan
            Write-Host "  └─────────────────────────────────────────────────────┘" -ForegroundColor Cyan
            Write-Host ""

            $recommended = Get-RecommendedModels -SystemProfile $state.SystemProfile
            $selectedModels = Show-ModelSelection -RecommendedModels $recommended -SystemProfile $state.SystemProfile

            $state.SelectedModels = $selectedModels
            $state.LastStep = 2
            Save-InstallState -State $state

            Write-Host ""
            Write-Host "  ✅ Model selection complete." -ForegroundColor Green
            Write-Host ""
            Start-Sleep -Seconds 1
        } else {
            Write-Host "  ⏭️  Step 2/$script:TOTAL_STEPS: Model Selection — skipped (already done)" -ForegroundColor DarkGray
        }

        # -------------------------------------------------------------------
        # STEP 3: Configuration Wizard
        # -------------------------------------------------------------------
        if ($state.LastStep -lt 3) {
            Write-Host "  ┌─────────────────────────────────────────────────────┐" -ForegroundColor Cyan
            Write-Host "  │  Step 3/$script:TOTAL_STEPS: Configuration                            │" -ForegroundColor Cyan
            Write-Host "  └─────────────────────────────────────────────────────┘" -ForegroundColor Cyan
            Write-Host ""

            $config = Start-ConfigurationWizard -SystemProfile $state.SystemProfile
            if ($state.SelectedModels) {
                $config.SelectedModels = $state.SelectedModels
            }

            $state.Configuration = $config
            $state.LastStep = 3
            Save-InstallState -State $state

            Write-Host ""
            Write-Host "  ✅ Configuration complete." -ForegroundColor Green
            Write-Host ""
            Start-Sleep -Seconds 1
        } else {
            Write-Host "  ⏭️  Step 3/$script:TOTAL_STEPS: Configuration — skipped (already done)" -ForegroundColor DarkGray
        }

        # -------------------------------------------------------------------
        # STEP 4: Prerequisites
        # -------------------------------------------------------------------
        if ($state.LastStep -lt 4) {
            Write-Host "  ┌─────────────────────────────────────────────────────┐" -ForegroundColor Cyan
            Write-Host "  │  Step 4/$script:TOTAL_STEPS: Installing Prerequisites                 │" -ForegroundColor Cyan
            Write-Host "  └─────────────────────────────────────────────────────┘" -ForegroundColor Cyan
            Write-Host ""

            $prereqResult = Install-Prerequisites -SystemProfile $state.SystemProfile
            if ($prereqResult.RebootRequired) {
                Write-Host ""
                Write-Host "  ⚠️  A system reboot is required to complete prerequisite installation." -ForegroundColor Yellow
                Write-Host "     Please reboot your computer and re-run this installer." -ForegroundColor Yellow
                Write-Host "     The installation will resume from step 5." -ForegroundColor Yellow
                Write-Host ""
                $state.LastStep = 4
                Save-InstallState -State $state
                Read-Host "  Press Enter to exit"
                exit 0
            }

            $state.LastStep = 4
            Save-InstallState -State $state

            Write-Host ""
            Write-Host "  ✅ Prerequisites installed." -ForegroundColor Green
            Write-Host ""
            Start-Sleep -Seconds 1
        } else {
            Write-Host "  ⏭️  Step 4/$script:TOTAL_STEPS: Prerequisites — skipped (already done)" -ForegroundColor DarkGray
        }

        # -------------------------------------------------------------------
        # STEP 5: Service Deployment
        # -------------------------------------------------------------------
        if ($state.LastStep -lt 5) {
            Write-Host "  ┌─────────────────────────────────────────────────────┐" -ForegroundColor Cyan
            Write-Host "  │  Step 5/$script:TOTAL_STEPS: Deploying Services                       │" -ForegroundColor Cyan
            Write-Host "  └─────────────────────────────────────────────────────┘" -ForegroundColor Cyan
            Write-Host ""

            Start-Deployment -Config $state.Configuration

            $state.LastStep = 5
            Save-InstallState -State $state

            Write-Host ""
            Write-Host "  ✅ Services deployed." -ForegroundColor Green
            Write-Host ""
            Start-Sleep -Seconds 1
        } else {
            Write-Host "  ⏭️  Step 5/$script:TOTAL_STEPS: Service Deployment — skipped (already done)" -ForegroundColor DarkGray
        }

        # -------------------------------------------------------------------
        # STEP 6: Model Download
        # -------------------------------------------------------------------
        if ($state.LastStep -lt 6) {
            Write-Host "  ┌─────────────────────────────────────────────────────┐" -ForegroundColor Cyan
            Write-Host "  │  Step 6/$script:TOTAL_STEPS: Downloading Models                       │" -ForegroundColor Cyan
            Write-Host "  └─────────────────────────────────────────────────────┘" -ForegroundColor Cyan
            Write-Host ""

            Install-OllamaModels -Config $state.Configuration

            $state.LastStep = 6
            Save-InstallState -State $state

            Write-Host ""
            Write-Host "  ✅ Models downloaded and verified." -ForegroundColor Green
            Write-Host ""
            Start-Sleep -Seconds 1
        } else {
            Write-Host "  ⏭️  Step 6/$script:TOTAL_STEPS: Model Download — skipped (already done)" -ForegroundColor DarkGray
        }

        # -------------------------------------------------------------------
        # STEP 7: Custom Model Profiles
        # -------------------------------------------------------------------
        if ($state.LastStep -lt 7) {
            Write-Host "  ┌─────────────────────────────────────────────────────┐" -ForegroundColor Cyan
            Write-Host "  │  Step 7/$script:TOTAL_STEPS: Setting Up AI Profiles                    │" -ForegroundColor Cyan
            Write-Host "  └─────────────────────────────────────────────────────┘" -ForegroundColor Cyan
            Write-Host ""

            Write-Host "  Creating specialized AI assistant profiles..." -ForegroundColor Gray
            Write-Host "    • General Assistant — All-purpose chat & Q&A" -ForegroundColor DarkGray
            Write-Host "    • Reasoning Engine — Deep thinking with chain-of-thought" -ForegroundColor DarkGray
            Write-Host "    • Code Developer  — Software engineering & debugging" -ForegroundColor DarkGray
            Write-Host "    • Data Analyst    — Statistics & data processing" -ForegroundColor DarkGray
            Write-Host "    • Creative Writer — Content creation & copywriting" -ForegroundColor DarkGray
            Write-Host "    • Security Analyst — Cybersecurity & threat modeling" -ForegroundColor DarkGray
            Write-Host ""

            Install-CustomModels -Config $state.Configuration

            $state.LastStep = 7
            Save-InstallState -State $state

            Write-Host ""
            Write-Host "  ✅ AI profiles created." -ForegroundColor Green
            Write-Host ""
            Start-Sleep -Seconds 1
        } else {
            Write-Host "  ⏭️  Step 7/$script:TOTAL_STEPS: AI Profiles — skipped (already done)" -ForegroundColor DarkGray
        }

        # -------------------------------------------------------------------
        # STEP 8: Enterprise Configuration
        # -------------------------------------------------------------------
        if ($state.LastStep -lt 8) {
            Write-Host "  ┌─────────────────────────────────────────────────────┐" -ForegroundColor Cyan
            Write-Host "  │  Step 8/$script:TOTAL_STEPS: Configuring Enterprise Features           │" -ForegroundColor Cyan
            Write-Host "  └─────────────────────────────────────────────────────┘" -ForegroundColor Cyan
            Write-Host ""

            Write-Host "  Enabling enterprise capabilities..." -ForegroundColor Gray
            Write-Host "    • Code execution sandbox" -ForegroundColor DarkGray
            Write-Host "    • Artifacts rendering" -ForegroundColor DarkGray
            Write-Host "    • Thinking/reasoning display" -ForegroundColor DarkGray
            Write-Host "    • Developer tools (7 built-in tools)" -ForegroundColor DarkGray
            Write-Host "    • Prompt template library (10 templates)" -ForegroundColor DarkGray
            Write-Host "    • RAG optimization" -ForegroundColor DarkGray
            Write-Host ""

            Initialize-OpenWebUI -Config $state.Configuration

            $state.LastStep = 8
            Save-InstallState -State $state

            Write-Host ""
            Write-Host "  ✅ Enterprise features configured." -ForegroundColor Green
            Write-Host ""
            Start-Sleep -Seconds 1
        } else {
            Write-Host "  ⏭️  Step 8/$script:TOTAL_STEPS: Enterprise Config — skipped (already done)" -ForegroundColor DarkGray
        }

        # -------------------------------------------------------------------
        # STEP 9: Verification & Health Check
        # -------------------------------------------------------------------
        if ($state.LastStep -lt 9) {
            Write-Host "  ┌─────────────────────────────────────────────────────┐" -ForegroundColor Cyan
            Write-Host "  │  Step 9/$script:TOTAL_STEPS: Verification                             │" -ForegroundColor Cyan
            Write-Host "  └─────────────────────────────────────────────────────┘" -ForegroundColor Cyan
            Write-Host ""

            $healthResults = Invoke-HealthCheck
            Show-HealthReport -Results $healthResults

            $failures = ($healthResults | Where-Object { $_.Status -eq 'Fail' }).Count
            if ($failures -gt 0) {
                Write-Host ""
                Write-Host "  ⚠️  $failures health check(s) failed. Attempting auto-repair..." -ForegroundColor Yellow
                foreach ($fail in ($healthResults | Where-Object { $_.Status -eq 'Fail' -and $_.AutoFixAvailable })) {
                    Write-Host "    Repairing: $($fail.Name)..." -ForegroundColor Yellow
                    Repair-Service -CheckResult $fail
                }
                Write-Host "  Re-running health checks..." -ForegroundColor Gray
                $healthResults = Invoke-HealthCheck
                Show-HealthReport -Results $healthResults
            }

            $state.LastStep = 9
            $state.CompletedAt = (Get-Date -Format 'o')
            Save-InstallState -State $state

            Write-Host ""
            Write-Host "  ✅ Verification complete." -ForegroundColor Green
            Write-Host ""
        }

        # -------------------------------------------------------------------
        # Completion
        # -------------------------------------------------------------------
        $webUIPort = if ($state.Configuration.WebUIPort) { $state.Configuration.WebUIPort } else { 3000 }

        Write-Host ""
        Write-Host "  ╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
        Write-Host "  ║                                                          ║" -ForegroundColor Green
        Write-Host "  ║   ✅  LocalLLM Installation Complete!                    ║" -ForegroundColor Green
        Write-Host "  ║                                                          ║" -ForegroundColor Green
        Write-Host "  ╠══════════════════════════════════════════════════════════╣" -ForegroundColor Green
        Write-Host "  ║                                                          ║" -ForegroundColor Green
        Write-Host "  ║   🌐 Open your AI assistant:                             ║" -ForegroundColor White
        Write-Host "  ║      http://localhost:$webUIPort                             ║" -ForegroundColor Cyan
        Write-Host "  ║                                                          ║" -ForegroundColor Green
        Write-Host "  ║   📋 First-time setup:                                   ║" -ForegroundColor White
        Write-Host "  ║      1. Open the URL above in your browser               ║" -ForegroundColor Gray
        Write-Host "  ║      2. Create your admin account                        ║" -ForegroundColor Gray
        Write-Host "  ║      3. Start chatting with your local AI!               ║" -ForegroundColor Gray
        Write-Host "  ║                                                          ║" -ForegroundColor Green
        Write-Host "  ║   🔧 Management commands:                               ║" -ForegroundColor White
        Write-Host "  ║      .\localllm.ps1 start    — Start services            ║" -ForegroundColor Gray
        Write-Host "  ║      .\localllm.ps1 stop     — Stop services             ║" -ForegroundColor Gray
        Write-Host "  ║      .\localllm.ps1 status   — Check health              ║" -ForegroundColor Gray
        Write-Host "  ║      .\localllm.ps1 doctor   — Run diagnostics           ║" -ForegroundColor Gray
        Write-Host "  ║      .\localllm.ps1 help     — Show all commands         ║" -ForegroundColor Gray
        Write-Host "  ║                                                          ║" -ForegroundColor Green
        Write-Host "  ╚══════════════════════════════════════════════════════════╝" -ForegroundColor Green
        Write-Host ""
        Write-Host "  Copyright (c) 2025-2026 Eugene Beauzec. All Rights Reserved." -ForegroundColor DarkGray
        Write-Host ""

        # Open browser
        if (-not $SkipBrowser) {
            $openBrowser = Read-Host "  Open LocalLLM in your browser now? [Y/n]"
            if ($openBrowser -ne 'n' -and $openBrowser -ne 'N') {
                Start-Process "http://localhost:$webUIPort"
            }
        }

    } catch {
        Write-Host ""
        Write-Host "  ╔══════════════════════════════════════════════════════════╗" -ForegroundColor Red
        Write-Host "  ║   ❌  Installation Error                                 ║" -ForegroundColor Red
        Write-Host "  ╠══════════════════════════════════════════════════════════╣" -ForegroundColor Red
        Write-Host "  ║                                                          ║" -ForegroundColor Red
        Write-Host "  ║   $($_.Exception.Message.PadRight(55).Substring(0,55))║" -ForegroundColor Yellow
        Write-Host "  ║                                                          ║" -ForegroundColor Red
        Write-Host "  ║   The installer has saved its progress.                  ║" -ForegroundColor Gray
        Write-Host "  ║   Re-run install.ps1 to resume from the last step.       ║" -ForegroundColor Gray
        Write-Host "  ║                                                          ║" -ForegroundColor Red
        Write-Host "  ║   For help: see docs/TROUBLESHOOTING.md                  ║" -ForegroundColor Gray
        Write-Host "  ║   Logs: logs/localllm.log                                ║" -ForegroundColor Gray
        Write-Host "  ║                                                          ║" -ForegroundColor Red
        Write-Host "  ╚══════════════════════════════════════════════════════════╝" -ForegroundColor Red
        Write-Host ""

        # Log the full error
        $errorLog = Join-Path $PSScriptRoot "logs" "install-error.log"
        $errorDetails = @"
[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Installation Error
Step: $($state.LastStep + 1)/$script:TOTAL_STEPS
Error: $($_.Exception.Message)
Stack: $($_.ScriptStackTrace)
"@
        Add-Content -Path $errorLog -Value $errorDetails -ErrorAction SilentlyContinue

        Save-InstallState -State $state

        exit 1
    }
}

# ---------------------------------------------------------------------------
# Entry Point
# ---------------------------------------------------------------------------
Start-Installation
