#Requires -Version 5.1
# ============================================================================
# Copyright (c) 2025-2026 Eugene Beauzec. All Rights Reserved.
# Project: LocalLLM - Self-Contained Local AI Platform
# File:    lib/wizard.ps1 - Interactive Configuration Wizard
# ============================================================================

<#
.SYNOPSIS
    Interactive configuration wizard for LocalLLM installation.

.DESCRIPTION
    Guides the user through all configuration options including installation
    directory, features, privacy mode, cloud API keys, and port selection.
    Returns a Configuration hashtable used by the deployment module.

.NOTES
    Author:  Eugene Beauzec
    License: Proprietary - All Rights Reserved
#>

# ---------------------------------------------------------------------------
# Install Directory Selection
# ---------------------------------------------------------------------------
function Select-InstallDirectory {
    <#
    .SYNOPSIS
        Prompts the user to select an installation directory.
    #>
    try {
        $defaultPath = $PSScriptRoot | Split-Path -Parent
        Write-Host ""
        Write-Host "  📁 Installation Directory" -ForegroundColor Cyan
        Write-Host "     Where should LocalLLM store its data (models, configs, chat history)?" -ForegroundColor Gray
        Write-Host ""
        $prompt = Read-Host "     Directory [$defaultPath]"
        if ([string]::IsNullOrWhiteSpace($prompt)) {
            $prompt = $defaultPath
        }

        # Validate path
        if (-not (Test-Path (Split-Path $prompt -Parent) -ErrorAction SilentlyContinue)) {
            Write-Host "     ⚠️  Parent directory doesn't exist. Using default: $defaultPath" -ForegroundColor Yellow
            $prompt = $defaultPath
        }

        Write-Host "     ✅ Install path: $prompt" -ForegroundColor Green
        return $prompt
    } catch {
        Write-LogMessage "Error selecting install directory: $_" -Level Error
        return $PSScriptRoot | Split-Path -Parent
    }
}

# ---------------------------------------------------------------------------
# Privacy Mode Selection
# ---------------------------------------------------------------------------
function Select-PrivacyMode {
    <#
    .SYNOPSIS
        Prompts the user to select a privacy/data protection mode.

    .DESCRIPTION
        Three modes control how data is routed:
        - STRICT: Everything stays local. No cloud APIs.
        - BALANCED: Prefer local, warn before cloud, scan for sensitive data.
        - PERMISSIVE: Prefer local, allow cloud, auto-redact sensitive data.
    #>
    try {
        Write-Host ""
        Write-Host "  ┌─────────────────────────────────────────────────────┐" -ForegroundColor Cyan
        Write-Host "  │  🔒 Data Privacy & Security Mode                    │" -ForegroundColor Cyan
        Write-Host "  └─────────────────────────────────────────────────────┘" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  LocalLLM keeps your data LOCAL by default. Choose how" -ForegroundColor Gray
        Write-Host "  strictly to enforce this:" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  1. STRICT   — Maximum privacy. ALL processing stays local." -ForegroundColor Green
        Write-Host "                 No data ever leaves your machine." -ForegroundColor DarkGray
        Write-Host "                 Cloud APIs are completely disabled." -ForegroundColor DarkGray
        Write-Host "                 Best for: classified data, corporate secrets," -ForegroundColor DarkGray
        Write-Host "                 medical/financial records, GDPR compliance." -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  2. BALANCED — Local-first with guarded cloud fallback." -ForegroundColor Yellow
        Write-Host "                 Scans for sensitive data before any cloud request." -ForegroundColor DarkGray
        Write-Host "                 Asks for your confirmation before sending to cloud." -ForegroundColor DarkGray
        Write-Host "                 Detects: credit cards, SSNs, API keys, passwords." -ForegroundColor DarkGray
        Write-Host "                 Best for: general business use. (RECOMMENDED)" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  3. PERMISSIVE — Local-first, cloud allowed freely." -ForegroundColor Red
        Write-Host "                   Still auto-redacts sensitive data patterns." -ForegroundColor DarkGray
        Write-Host "                   No confirmation prompts for cloud requests." -ForegroundColor DarkGray
        Write-Host "                   Best for: development/testing with non-sensitive data." -ForegroundColor DarkGray
        Write-Host ""

        $choice = Read-Host "  Select privacy mode [1-3, default=2]"

        switch ($choice) {
            '1' {
                Write-Host ""
                Write-Host "  🔒 STRICT mode selected — Maximum data protection enabled." -ForegroundColor Green
                Write-Host "     All processing will stay on this machine." -ForegroundColor Green
                Write-Host "     Cloud API keys will NOT be requested." -ForegroundColor Green
                return 'STRICT'
            }
            '3' {
                Write-Host ""
                Write-Host "  ⚠️  PERMISSIVE mode selected — Cloud access allowed." -ForegroundColor Yellow
                Write-Host "     Sensitive data will be auto-redacted before cloud sends." -ForegroundColor Yellow
                return 'PERMISSIVE'
            }
            default {
                Write-Host ""
                Write-Host "  🛡️  BALANCED mode selected — Smart privacy protection." -ForegroundColor Cyan
                Write-Host "     You'll be warned before any data leaves your machine." -ForegroundColor Cyan
                return 'BALANCED'
            }
        }
    } catch {
        Write-LogMessage "Error selecting privacy mode: $_" -Level Error
        return 'BALANCED'
    }
}

# ---------------------------------------------------------------------------
# Feature Selection
# ---------------------------------------------------------------------------
function Select-Features {
    <#
    .SYNOPSIS
        Interactive feature selection for LocalLLM capabilities.
    #>
    try {
        $features = @{
            RAG         = $true
            WebSearch   = $true
            ToolCalling = $true
            MultiUser   = $false
            AutoStart   = $true
        }

        Write-Host ""
        Write-Host "  ⚙️  Feature Selection" -ForegroundColor Cyan
        Write-Host "     Press Enter to accept defaults shown in [brackets]." -ForegroundColor Gray
        Write-Host ""

        $rag = Read-Host "  📄 RAG / Document Q&A (upload docs, ask questions)? [Y/n]"
        if ($rag -match '^[Nn]') { $features.RAG = $false }

        $web = Read-Host "  🔍 Web Search via SearXNG (private, no tracking)?   [Y/n]"
        if ($web -match '^[Nn]') { $features.WebSearch = $false }

        $tools = Read-Host "  🔧 Tool / Function Calling?                         [Y/n]"
        if ($tools -match '^[Nn]') { $features.ToolCalling = $false }

        $multi = Read-Host "  👥 Multi-user mode (shared instance)?               [y/N]"
        if ($multi -match '^[Yy]') { $features.MultiUser = $true }

        $auto = Read-Host "  🚀 Auto-start services on system boot?              [Y/n]"
        if ($auto -match '^[Nn]') { $features.AutoStart = $false }

        Write-Host ""
        Write-Host "  ✅ Features configured." -ForegroundColor Green
        return $features
    } catch {
        Write-LogMessage "Error selecting features: $_" -Level Error
        return @{ RAG = $true; WebSearch = $true; ToolCalling = $true; MultiUser = $false; AutoStart = $true }
    }
}

# ---------------------------------------------------------------------------
# Cloud API Key Collection
# ---------------------------------------------------------------------------

function Get-APIKeysPath {
    <#
    .SYNOPSIS
        Returns the path to the persistent API keys file.
    #>
    $configDir = Join-Path $PSScriptRoot '..' 'config'
    if (-not (Test-Path $configDir)) { New-Item -ItemType Directory -Path $configDir -Force | Out-Null }
    return Join-Path $configDir 'api-keys.json'
}

function Save-CloudAPIKeys {
    <#
    .SYNOPSIS
        Persists API keys to local config/api-keys.json.
    #>
    param($Keys)
    $keysPath = Get-APIKeysPath
    $Keys | ConvertTo-Json -Depth 3 | Set-Content -Path $keysPath -Encoding UTF8
    Write-LogMessage "API keys saved to config/api-keys.json" -Level Info
}

function Load-CloudAPIKeys {
    <#
    .SYNOPSIS
        Loads API keys from persistent storage. Returns null if not found.
    #>
    $keysPath = Get-APIKeysPath
    if (Test-Path $keysPath) {
        try {
            $keys = Get-Content $keysPath -Raw | ConvertFrom-Json
            # Convert PSCustomObject back to hashtable
            $result = @{ OpenAI = ''; Anthropic = ''; Google = '' }
            if ($keys.OpenAI) { $result.OpenAI = $keys.OpenAI }
            if ($keys.Anthropic) { $result.Anthropic = $keys.Anthropic }
            if ($keys.Google) { $result.Google = $keys.Google }
            return $result
        } catch {
            Write-LogMessage "Failed to load saved API keys: $_" -Level Warning
        }
    }
    return $null
}

function Get-CloudAPIKeys {
    <#
    .SYNOPSIS
        Collects optional cloud API keys for fallback routing.

    .DESCRIPTION
        Keys are persisted locally in config/api-keys.json so they
        survive reboots, install state resets, and re-runs.
        If keys already exist, offers to reuse them.
    #>
    param(
        [string]$PrivacyMode = 'BALANCED'
    )

    try {
        $keys = @{ OpenAI = ''; Anthropic = ''; Google = '' }

        if ($PrivacyMode -eq 'STRICT') {
            Write-Host ""
            Write-Host "  🔒 Cloud API keys skipped (STRICT privacy mode)." -ForegroundColor Green
            Write-Host "     All processing will remain local." -ForegroundColor Gray
            return $keys
        }

        # Check for previously saved keys
        $savedKeys = Load-CloudAPIKeys
        if ($savedKeys) {
            $configured = ($savedKeys.Values | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count
            if ($configured -gt 0) {
                Write-Host ""
                Write-Host "  🔑 Found $configured saved API key(s) from previous setup:" -ForegroundColor Green
                if (-not [string]::IsNullOrWhiteSpace($savedKeys.OpenAI))    { Write-Host "    • OpenAI     ✅" -ForegroundColor Gray }
                if (-not [string]::IsNullOrWhiteSpace($savedKeys.Anthropic)) { Write-Host "    • Anthropic  ✅" -ForegroundColor Gray }
                if (-not [string]::IsNullOrWhiteSpace($savedKeys.Google))    { Write-Host "    • Google     ✅" -ForegroundColor Gray }
                Write-Host ""
                $reuse = Read-HostOrConfig -Prompt "  Use saved keys? [Y/n]" -Default 'Y' -ConfigKey 'ReuseSavedKeys'
                if ($reuse -ne 'n' -and $reuse -ne 'N') {
                    Write-Host "  ✅ Using saved API keys." -ForegroundColor Green
                    return $savedKeys
                }
                Write-Host "  Entering new keys..." -ForegroundColor Gray
            }
        }

        Write-Host ""
        Write-Host "  ┌─────────────────────────────────────────────────────┐" -ForegroundColor Cyan
        Write-Host "  │  ☁️  Cloud API Keys (Optional Fallback)              │" -ForegroundColor Cyan
        Write-Host "  └─────────────────────────────────────────────────────┘" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Cloud models are used ONLY when local models fail." -ForegroundColor Gray
        Write-Host "  Local models cost `$0 and keep your data private." -ForegroundColor Gray
        Write-Host "  Leave blank to skip (you can add these later)." -ForegroundColor Gray
        Write-Host ""

        if ($PrivacyMode -eq 'BALANCED') {
            Write-Host "  ℹ️  BALANCED mode: You'll be warned before any cloud request" -ForegroundColor Yellow
            Write-Host "     and sensitive data will be detected and blocked." -ForegroundColor Yellow
            Write-Host ""
        }

        # OpenAI
        $oai = Read-Host "  OpenAI API Key (starts with sk-..., blank to skip)"
        if ($oai -match '^sk-') {
            $keys.OpenAI = $oai
            Write-Host "     ✅ OpenAI key accepted." -ForegroundColor Green
        } elseif (-not [string]::IsNullOrWhiteSpace($oai)) {
            Write-Host "     ⚠️  Invalid format (expected sk-...). Skipped." -ForegroundColor Yellow
        }

        # Anthropic
        $anth = Read-Host "  Anthropic API Key (starts with sk-ant-..., blank to skip)"
        if ($anth -match '^sk-ant-') {
            $keys.Anthropic = $anth
            Write-Host "     ✅ Anthropic key accepted." -ForegroundColor Green
        } elseif (-not [string]::IsNullOrWhiteSpace($anth)) {
            Write-Host "     ⚠️  Invalid format (expected sk-ant-...). Skipped." -ForegroundColor Yellow
        }

        # Google
        $goog = Read-Host "  Google/Gemini API Key (blank to skip)"
        if (-not [string]::IsNullOrWhiteSpace($goog)) {
            $keys.Google = $goog
            Write-Host "     ✅ Google key accepted." -ForegroundColor Green
        }

        # Save keys persistently
        Save-CloudAPIKeys -Keys $keys

        # Summary
        $configured = ($keys.Values | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count
        Write-Host ""
        if ($configured -eq 0) {
            Write-Host "  ℹ️  No cloud keys configured — running in local-only mode." -ForegroundColor Cyan
            Write-Host "     This saves costs and maximizes privacy." -ForegroundColor Gray
        } else {
            Write-Host "  ℹ️  $configured cloud provider(s) configured as fallback." -ForegroundColor Cyan
            Write-Host "     Local models will always be used first (free, private)." -ForegroundColor Gray
            Write-Host "     Cloud is only used when local cannot handle the request." -ForegroundColor Gray
            Write-Host "     Keys saved to config/api-keys.json (persistent)." -ForegroundColor DarkGray
        }

        return $keys
    } catch {
        Write-LogMessage "Error collecting API keys: $_" -Level Error
        return @{ OpenAI = ''; Anthropic = ''; Google = '' }
    }
}

# ---------------------------------------------------------------------------
# Port Configuration
# ---------------------------------------------------------------------------
function Select-Ports {
    <#
    .SYNOPSIS
        Allows the user to customize service ports.
    #>
    try {
        Write-Host ""
        Write-Host "  🔌 Port Configuration" -ForegroundColor Cyan
        Write-Host "     Press Enter to accept defaults." -ForegroundColor Gray
        Write-Host ""

        $webui = Read-Host "     Web UI port [3100]"
        if ([string]::IsNullOrWhiteSpace($webui)) { $webui = 3100 } else { $webui = [int]$webui }

        $ollama = Read-Host "     Ollama port  [11434]"
        if ([string]::IsNullOrWhiteSpace($ollama)) { $ollama = 11434 } else { $ollama = [int]$ollama }

        $litellm = Read-Host "     LiteLLM port [4000]"
        if ([string]::IsNullOrWhiteSpace($litellm)) { $litellm = 4000 } else { $litellm = [int]$litellm }

        return @{
            WebUIPort   = $webui
            OllamaPort  = $ollama
            LiteLLMPort = $litellm
        }
    } catch {
        return @{ WebUIPort = 3100; OllamaPort = 11434; LiteLLMPort = 4000 }
    }
}

# ---------------------------------------------------------------------------
# Configuration Summary & Confirmation
# ---------------------------------------------------------------------------
function Confirm-Configuration {
    <#
    .SYNOPSIS
        Displays a summary of all configuration choices and asks for confirmation.
    #>
    param($Config)

    try {
        Write-Host ""
        Write-Host "  ┌─────────────────────────────────────────────────────┐" -ForegroundColor Cyan
        Write-Host "  │  📋 Configuration Summary                           │" -ForegroundColor Cyan
        Write-Host "  └─────────────────────────────────────────────────────┘" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Install Path:    $($Config.InstallPath)" -ForegroundColor White

        # Privacy mode with color
        $privColor = switch ($Config.PrivacyMode) {
            'STRICT'     { 'Green' }
            'BALANCED'   { 'Yellow' }
            'PERMISSIVE' { 'Red' }
            default      { 'White' }
        }
        Write-Host "  Privacy Mode:    $($Config.PrivacyMode)" -ForegroundColor $privColor

        Write-Host "  GPU Inference:   $(if ($Config.UseGPU) { '✅ Enabled' } else { '❌ CPU only' })" -ForegroundColor White
        Write-Host ""

        Write-Host "  Features:" -ForegroundColor White
        Write-Host "    RAG/Documents: $(if ($Config.Features.RAG) { '✅' } else { '❌' })" -ForegroundColor Gray
        Write-Host "    Web Search:    $(if ($Config.Features.WebSearch) { '✅' } else { '❌' })" -ForegroundColor Gray
        Write-Host "    Tool Calling:  $(if ($Config.Features.ToolCalling) { '✅' } else { '❌' })" -ForegroundColor Gray
        Write-Host "    Multi-user:    $(if ($Config.Features.MultiUser) { '✅' } else { '❌' })" -ForegroundColor Gray
        Write-Host "    Auto-start:    $(if ($Config.Features.AutoStart) { '✅' } else { '❌' })" -ForegroundColor Gray
        Write-Host ""

        # Cloud keys
        $cloudCount = ($Config.CloudKeys.Values | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count
        if ($Config.PrivacyMode -eq 'STRICT') {
            Write-Host "  Cloud Fallback:  🔒 Disabled (STRICT mode)" -ForegroundColor Green
        } elseif ($cloudCount -eq 0) {
            Write-Host "  Cloud Fallback:  ℹ️  None configured (local only)" -ForegroundColor Cyan
        } else {
            Write-Host "  Cloud Fallback:  $cloudCount provider(s) as last resort" -ForegroundColor Yellow
            if (-not [string]::IsNullOrWhiteSpace($Config.CloudKeys.OpenAI))    { Write-Host "    • OpenAI     ✅" -ForegroundColor Gray }
            if (-not [string]::IsNullOrWhiteSpace($Config.CloudKeys.Anthropic)) { Write-Host "    • Anthropic  ✅" -ForegroundColor Gray }
            if (-not [string]::IsNullOrWhiteSpace($Config.CloudKeys.Google))    { Write-Host "    • Google     ✅" -ForegroundColor Gray }
        }

        Write-Host ""
        Write-Host "  Ports:" -ForegroundColor White
        Write-Host "    Web UI:   http://localhost:$($Config.WebUIPort)" -ForegroundColor Gray
        Write-Host "    Ollama:   http://localhost:$($Config.OllamaPort)" -ForegroundColor Gray
        Write-Host "    LiteLLM:  http://localhost:$($Config.LiteLLMPort)" -ForegroundColor Gray
        Write-Host ""

        $confirm = Read-Host "  Proceed with this configuration? [Y/n]"
        return -not ($confirm -match '^[Nn]')
    } catch {
        return $false
    }
}

# ---------------------------------------------------------------------------
# Main Wizard Orchestrator
# ---------------------------------------------------------------------------
function Start-ConfigurationWizard {
    <#
    .SYNOPSIS
        Main entry point for the interactive configuration wizard.

    .DESCRIPTION
        Guides the user through all configuration steps and returns
        a complete Configuration hashtable for the deployment module.

    .PARAMETER SystemProfile
        System profile object from Get-SystemProfile containing hardware
        and existing tool information.

    .OUTPUTS
        Hashtable with all configuration settings.

    .EXAMPLE
        $config = Start-ConfigurationWizard -SystemProfile $profile
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $SystemProfile
    )

    try {
        Write-Host ""
        Write-Host "  ┌─────────────────────────────────────────────────────┐" -ForegroundColor Cyan
        Write-Host "  │  🧙 Configuration Wizard                            │" -ForegroundColor Cyan
        Write-Host "  │                                                      │" -ForegroundColor Cyan
        Write-Host "  │  Answer a few questions to customize your setup.     │" -ForegroundColor Gray
        Write-Host "  │  Press Enter to accept defaults at any prompt.       │" -ForegroundColor Gray
        Write-Host "  └─────────────────────────────────────────────────────┘" -ForegroundColor Cyan

        # Step 1: Privacy Mode (FIRST — this affects all other choices)
        $privacyMode = Select-PrivacyMode

        # Step 2: Install Directory
        $installPath = Select-InstallDirectory

        # Step 3: Features
        $features = Select-Features

        # Step 4: Cloud API Keys (skipped in STRICT mode)
        $cloudKeys = Get-CloudAPIKeys -PrivacyMode $privacyMode

        # Step 5: Ports
        $ports = Select-Ports

        # Build config object
        $Config = @{
            InstallPath    = $installPath
            SelectedModels = @()
            Features       = $features
            CloudKeys      = $cloudKeys
            PrivacyMode    = $privacyMode
            UseGPU         = ($SystemProfile.HasNvidiaGPU -eq $true)
            DockerMode     = 'compose'
            WebUIPort      = $ports.WebUIPort
            OllamaPort     = $ports.OllamaPort
            LiteLLMPort    = $ports.LiteLLMPort
            SearXNGPort    = 8888
            TikaPort       = 9998
            PipelinesPort  = 9099
            TotalDownloadGB = 0
        }

        # In STRICT mode, clear any cloud keys that might have been set
        if ($privacyMode -eq 'STRICT') {
            $Config.CloudKeys = @{ OpenAI = ''; Anthropic = ''; Google = '' }
        }

        # Confirm
        if (-not (Confirm-Configuration -Config $Config)) {
            Write-Host ""
            Write-Host "  Configuration cancelled. Re-run the installer to try again." -ForegroundColor Red
            exit 1
        }

        Write-Host ""
        Write-Host "  ✅ Configuration saved." -ForegroundColor Green

        return $Config
    } catch {
        Write-LogMessage "Configuration wizard failed: $_" -Level Error
        throw
    }
}
