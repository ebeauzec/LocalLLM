#Requires -Version 5.1
# Copyright (c) 2025-2026 Eugene Beauzec. All Rights Reserved.
# Project: LocalLLM - Self-Contained Local AI Platform

<#
.SYNOPSIS
Interactive configuration wizard for LocalLLM.
#>

function Select-InstallDirectory {
    try {
        $defaultPath = "D:\LocalLLM"
        $prompt = Read-Host "Enter installation directory [$defaultPath]"
        if ([string]::IsNullOrWhiteSpace($prompt)) {
            $prompt = $defaultPath
        }
        return $prompt
    } catch {
        Write-LogMessage "Error selecting install directory: $_" -Level Error
        return "D:\LocalLLM"
    }
}

function Select-Features {
    try {
        $features = @{
            RAG = $true
            WebSearch = $true
            ToolCalling = $true
            MultiUser = $false
            AutoStart = $true
        }

        Write-Host "Select Features (Press Enter to accept defaults [Yes]):" -ForegroundColor Cyan
        
        $rag = Read-Host "Enable RAG/Document Q&A? (Y/n) [Y]"
        if ($rag -match "n") { $features.RAG = $false }

        $web = Read-Host "Enable Web Search via SearXNG? (Y/n) [Y]"
        if ($web -match "n") { $features.WebSearch = $false }

        $tools = Read-Host "Enable Tool/Function Calling? (Y/n) [Y]"
        if ($tools -match "n") { $features.ToolCalling = $false }

        $multi = Read-Host "Enable Multi-user mode? (y/N) [N]"
        if ($multi -match "y") { $features.MultiUser = $true }

        $auto = Read-Host "Enable Auto-start on boot? (Y/n) [Y]"
        if ($auto -match "n") { $features.AutoStart = $false }

        return $features
    } catch {
        Write-LogMessage "Error selecting features: $_" -Level Error
        return @{}
    }
}

function Get-CloudAPIKeys {
    try {
        $keys = @{ OpenAI=''; Anthropic=''; Google='' }
        Write-Host "Optional Cloud API Keys for Fallback Models (Leave blank to skip):" -ForegroundColor Cyan
        
        $oai = Read-Host "OpenAI API Key (starts with sk-...)"
        if ($oai -match "^sk-") { $keys.OpenAI = $oai }

        $anth = Read-Host "Anthropic API Key"
        if (![string]::IsNullOrWhiteSpace($anth)) { $keys.Anthropic = $anth }

        $goog = Read-Host "Google API Key"
        if (![string]::IsNullOrWhiteSpace($goog)) { $keys.Google = $goog }

        return $keys
    } catch {
        Write-LogMessage "Error collecting API keys: $_" -Level Error
        return @{ OpenAI=''; Anthropic=''; Google='' }
    }
}

function Confirm-Configuration {
    param([hashtable]$Config)
    try {
        Write-Host "`n--- Configuration Summary ---" -ForegroundColor Cyan
        Write-Host "Install Path: $($Config.InstallPath)"
        Write-Host "Features: RAG=$($Config.Features.RAG), WebSearch=$($Config.Features.WebSearch)"
        Write-Host "Use GPU: $($Config.UseGPU)"
        
        $confirm = Read-Host "Proceed with this configuration? (Y/n) [Y]"
        return !($confirm -match "n")
    } catch {
        return $false
    }
}

function Start-ConfigurationWizard {
    [CmdletBinding()]
    param(
        [hashtable]$SystemProfile
    )
    try {
        $Config = @{
            InstallPath = Select-InstallDirectory
            SelectedModels = @()
            Features = Select-Features
            CloudKeys = Get-CloudAPIKeys
            UseGPU = $SystemProfile.HasNvidiaGPU
            DockerMode = 'compose'
            WebUIPort = 3000
            OllamaPort = 11434
            LiteLLMPort = 4000
            TotalDownloadGB = 0
        }

        if (-not (Confirm-Configuration -Config $Config)) {
            Write-Host "Configuration cancelled." -ForegroundColor Red
            exit
        }

        return $Config
    } catch {
        Write-LogMessage "Wizard failed: $_" -Level Error
        throw
    }
}
