#Requires -Version 5.1
# Copyright (c) 2025-2026 Eugene Beauzec. All Rights Reserved.
# Project: LocalLLM - Self-Contained Local AI Platform

<#
.SYNOPSIS
Deployment module for LocalLLM.
#>

function New-DockerComposeFile {
    param([hashtable]$Config, [string]$Path)
    try {
        $gpuSection = ""
        if ($Config.UseGPU) {
            $gpuSection = @"
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
"@
        }

        $compose = @"
version: '3.8'
services:
  ollama:
    image: ollama/ollama:latest
    container_name: localllm-ollama
    ports:
      - "$($Config.OllamaPort):11434"
    volumes:
      - ./data/ollama:/root/.ollama
    restart: unless-stopped
$gpuSection

  litellm:
    image: ghcr.io/berriai/litellm:main-latest
    container_name: localllm-litellm
    ports:
      - "$($Config.LiteLLMPort):4000"
    volumes:
      - ./litellm_config.yaml:/app/config.yaml
    command: [ "--config", "/app/config.yaml" ]
    restart: unless-stopped

  openwebui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: localllm-webui
    ports:
      - "$($Config.WebUIPort):8080"
    environment:
      - OLLAMA_BASE_URL=http://ollama:11434
      - OPENAI_API_BASE_URL=http://litellm:4000
    volumes:
      - ./data/webui:/app/backend/data
    restart: unless-stopped
"@
        $compose | Out-File -FilePath "$Path\docker-compose.yml" -Encoding UTF8
    } catch {
        Write-LogMessage "Error creating compose file: $_" -Level Error
    }
}

function New-LiteLLMConfig {
    param([hashtable]$Config, [string]$Path)
    try {
        $yaml = @"
model_list:
  - model_name: ollama-default
    litellm_params:
      model: ollama/llama3
      api_base: http://ollama:11434
"@
        $yaml | Out-File -FilePath "$Path\litellm_config.yaml" -Encoding UTF8
    } catch {
        Write-LogMessage "Error creating LiteLLM config: $_" -Level Error
    }
}

function New-EnvironmentFile {
    param([hashtable]$Config, [string]$Path)
    try {
        $env = @"
OLLAMA_PORT=$($Config.OllamaPort)
WEBUI_PORT=$($Config.WebUIPort)
LITELLM_PORT=$($Config.LiteLLMPort)
"@
        $env | Out-File -FilePath "$Path\.env" -Encoding UTF8
    } catch {
        Write-LogMessage "Error creating env file: $_" -Level Error
    }
}

function New-SearXNGConfig {
    param([hashtable]$Config, [string]$Path)
    # Placeholder for SearXNG logic
}

function Start-DockerCompose {
    param([string]$Path)
    try {
        Write-Host "Starting Docker Compose services..." -ForegroundColor Cyan
        Push-Location $Path
        docker compose up -d
        Pop-Location
    } catch {
        Write-LogMessage "Failed to start docker compose: $_" -Level Error
    }
}

function Install-OllamaModels {
    param([hashtable]$Config)
    try {
        Write-Host "Pulling models..." -ForegroundColor Cyan
        foreach ($model in $Config.SelectedModels) {
            docker exec localllm-ollama ollama pull $model
        }
    } catch {
        Write-LogMessage "Failed to pull models: $_" -Level Error
    }
}

function Wait-ForServices {
    try {
        Write-Host "Waiting for services to become ready..." -ForegroundColor Cyan
        Start-Sleep -Seconds 10
    } catch {}
}

function Start-Deployment {
    [CmdletBinding()]
    param(
        [hashtable]$Config
    )
    try {
        $installPath = $Config.InstallPath
        if (-not (Test-Path $installPath)) {
            New-Item -ItemType Directory -Path $installPath | Out-Null
        }
        
        New-DockerComposeFile -Config $Config -Path $installPath
        New-LiteLLMConfig -Config $Config -Path $installPath
        New-EnvironmentFile -Config $Config -Path $installPath
        
        if ($Config.Features.WebSearch) {
            New-SearXNGConfig -Config $Config -Path $installPath
        }

        Start-DockerCompose -Path $installPath
        Wait-ForServices
    } catch {
        Write-LogMessage "Deployment failed: $_" -Level Error
        throw
    }
}
