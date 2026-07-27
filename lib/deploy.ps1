#Requires -Version 5.1
# Copyright (c) 2025-2026 Eugene Beauzec. All Rights Reserved.
# Project: LocalLLM - Self-Contained Local AI Platform

<#
.SYNOPSIS
Deployment module for LocalLLM.
.DESCRIPTION
This module handles reading templates, replacing variables based on configuration,
generating output files in the config folder, starting docker compose, pulling
Ollama models, and waiting for the services to be healthy.
#>

$script:ProjectRoot = $PSScriptRoot | Split-Path -Parent

function New-LiteLLMKey {
    <#
    .SYNOPSIS
    Generates a random LiteLLM API key.
    #>
    [CmdletBinding()]
    param()
    $bytes = New-Object byte[] 16
    (New-Object System.Security.Cryptography.RNGCryptoServiceProvider).GetBytes($bytes)
    $hex = [System.BitConverter]::ToString($bytes) -replace '-'
    return "sk-localllm-$($hex.ToLower())"
}

function New-DockerComposeFile {
    <#
    .SYNOPSIS
    Generates docker-compose.yml from template.
    #>
    [CmdletBinding()]
    param($Config)
    
    try {
        $templatePath = Join-Path $script:ProjectRoot "templates\docker-compose.yml.tmpl"
        $outPath = Join-Path $script:ProjectRoot "config\docker-compose.yml"
        
        if (-not (Test-Path $templatePath)) {
            throw "Template not found: $templatePath"
        }
        
        $content = Get-Content -Path $templatePath -Raw
        
        # Safe config value accessor — PSCustomObject from JSON may not have all properties
        function Get-ConfigValue($Obj, $Prop, $Default) {
            try { $val = $Obj.$Prop; if ($null -ne $val) { return $val } } catch {}
            return $Default
        }
        
        # Replace basic variables with safe defaults
        $content = $content -replace '\{\{OLLAMA_PORT\}\}', (Get-ConfigValue $Config 'OllamaPort' 11434)
        $content = $content -replace '\{\{LITELLM_PORT\}\}', (Get-ConfigValue $Config 'LiteLLMPort' 4000)
        $content = $content -replace '\{\{WEBUI_PORT\}\}', (Get-ConfigValue $Config 'WebUIPort' 3000)
        $content = $content -replace '\{\{SEARXNG_PORT\}\}', (Get-ConfigValue $Config 'SearXNGPort' 8888)
        $content = $content -replace '\{\{TIKA_PORT\}\}', (Get-ConfigValue $Config 'TikaPort' 9998)
        $content = $content -replace '\{\{PIPELINES_PORT\}\}', (Get-ConfigValue $Config 'PipelinesPort' 9099)
        $content = $content -replace '\{\{DATA_PATH\}\}', './data'
        $content = $content -replace '\{\{CONFIG_PATH\}\}', './config'
        
        # Accelerator Config Section
        $accelConfig = Get-ConfigValue $Config 'AcceleratorConfig' $null
        if (-not $accelConfig) {
            # Fallback if not provided
            $accelConfig = @{
                OllamaImage = 'ollama/ollama:latest'
                OllamaEnvVars = @{ OLLAMA_NUM_THREADS = 4 }
                DockerDevices = @()
                DockerGPUDeploy = $null
            }
            if (Get-ConfigValue $Config 'UseGPU' $false) {
                $accelConfig.DockerGPUDeploy = @"
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
"@
            }
        }
        
        $content = $content -replace '\{\{OLLAMA_IMAGE\}\}', $accelConfig.OllamaImage
        
        $envVars = ""
        if ($accelConfig.OllamaEnvVars) {
            $envObj = $accelConfig.OllamaEnvVars
            if ($envObj -is [hashtable]) {
                foreach ($key in $envObj.Keys) {
                    $envVars += "      - $key=$($envObj[$key])`n"
                }
            } else {
                # PSCustomObject from JSON deserialization
                foreach ($prop in $envObj.PSObject.Properties) {
                    $envVars += "      - $($prop.Name)=$($prop.Value)`n"
                }
            }
        }
        $content = $content -replace '\{\{OLLAMA_ENV_VARS\}\}', $envVars.TrimEnd()
        
        $accelBlock = ""
        if ($accelConfig.DockerDevices -and $accelConfig.DockerDevices.Count -gt 0) {
            $accelBlock += "    devices:`n"
            foreach ($dev in $accelConfig.DockerDevices) {
                $accelBlock += "      - ${dev}:${dev}`n"
            }
        }
        if ($accelConfig.DockerGPUDeploy) {
            $accelBlock += $accelConfig.DockerGPUDeploy + "`n"
        }
        
        $content = $content -replace '\{\{ACCELERATOR_BLOCK\}\}', $accelBlock.TrimEnd()
        
        # Cleanup old GPU section tokens just in case
        $content = $content -replace '\{\{GPU_SECTION_START\}\}', ''
        $content = $content -replace '\{\{GPU_SECTION_END\}\}', ''
        
        # Feature-based sections (safe access for PSCustomObject)
        $features = Get-ConfigValue $Config 'Features' $null

        # Web Search section
        $hasWebSearch = $false
        try { $hasWebSearch = $features.WebSearch } catch {}
        if ($hasWebSearch) {
            $content = $content -replace '\{\{SEARXNG_SECTION_START\}\}', ''
            $content = $content -replace '\{\{SEARXNG_SECTION_END\}\}', ''
            $content = $content -replace '\{\{RAG_WEB_SEARCH_ENV\}\}', "- SEARXNG_API_URL=http://searxng:8080"
        } else {
            $content = $content -replace '(?s)\{\{SEARXNG_SECTION_START\}\}.*?\{\{SEARXNG_SECTION_END\}\}', ''
            $content = $content -replace '\{\{RAG_WEB_SEARCH_ENV\}\}', ''
        }
        
        # ToolCalling section
        $hasToolCalling = $false
        try { $hasToolCalling = $features.ToolCalling } catch {}
        if ($hasToolCalling) {
            $content = $content -replace '\{\{PIPELINES_SECTION_START\}\}', ''
            $content = $content -replace '\{\{PIPELINES_SECTION_END\}\}', ''
            $content = $content -replace '\{\{PIPELINES_ENV\}\}', "- PIPELINES_URL=http://pipelines:9099"
        } else {
            $content = $content -replace '(?s)\{\{PIPELINES_SECTION_START\}\}.*?\{\{PIPELINES_SECTION_END\}\}', ''
            $content = $content -replace '\{\{PIPELINES_ENV\}\}', ''
        }
        
        # Tika section
        $hasRAG = $false
        try { $hasRAG = $features.RAG } catch {}
        if ($hasRAG) {
            $content = $content -replace '\{\{TIKA_SECTION_START\}\}', ''
            $content = $content -replace '\{\{TIKA_SECTION_END\}\}', ''
            $content = $content -replace '\{\{TIKA_ENV\}\}', "- CONTENT_EXTRACTION_ENGINE=tika`n      - TIKA_SERVER_URL=http://tika:9998"
        } else {
            $content = $content -replace '(?s)\{\{TIKA_SECTION_START\}\}.*?\{\{TIKA_SECTION_END\}\}', ''
            $content = $content -replace '\{\{TIKA_ENV\}\}', ''
        }
        
        # Cloud Keys Env (handle both hashtable and PSCustomObject)
        $cloudKeysStr = ""
        $cloudKeys = Get-ConfigValue $Config 'CloudKeys' $null
        if ($cloudKeys) {
            if ($cloudKeys -is [hashtable]) {
                foreach ($key in $cloudKeys.Keys) {
                    $val = $cloudKeys[$key]
                    if (-not [string]::IsNullOrWhiteSpace($val)) {
                        $cloudKeysStr += "`n      - ${key}=${val}"
                    }
                }
            } else {
                foreach ($prop in $cloudKeys.PSObject.Properties) {
                    if (-not [string]::IsNullOrWhiteSpace($prop.Value)) {
                        $cloudKeysStr += "`n      - $($prop.Name)=$($prop.Value)"
                    }
                }
            }
        }
        $content = $content -replace '\{\{CLOUD_KEYS_ENV\}\}', $cloudKeysStr
        
        # Generate LiteLLM key and replace in compose file too
        $liteLLMKey = Get-ConfigValue $Config 'LiteLLMKey' $null
        if (-not $liteLLMKey) { $liteLLMKey = New-LiteLLMKey; $Config.LiteLLMKey = $liteLLMKey }
        $hasMultiUser = $false
        try { $hasMultiUser = $features.MultiUser } catch {}
        $multiUser = if ($hasMultiUser) { "True" } else { "False" }
        $content = $content -replace '\{\{LITELLM_KEY\}\}', $liteLLMKey
        $content = $content -replace '\{\{MULTI_USER\}\}', $multiUser
        
        # Ensure config dir exists
        $configDir = Split-Path $outPath
        if (-not (Test-Path $configDir)) { New-Item -ItemType Directory -Path $configDir | Out-Null }
        
        $content | Out-File -FilePath $outPath -Encoding UTF8
        Write-LogMessage "Generated docker-compose.yml" -Level Success
    } catch {
        Write-LogMessage "Error creating docker-compose file: $_" -Level Error
        throw
    }
}

function New-LiteLLMConfig {
    [CmdletBinding()]
    param($Config)
    
    try {
        $templatePath = Join-Path $script:ProjectRoot "templates\litellm_config.yaml.tmpl"
        $outPath = Join-Path $script:ProjectRoot "config\litellm_config.yaml"
        
        if (-not (Test-Path $templatePath)) {
            Write-LogMessage "litellm_config.yaml.tmpl missing, using basic structure." -Level Warning
            $content = "model_list:`n{{LOCAL_MODELS_SECTION}}`n{{CLOUD_MODELS_SECTION}}`n{{FALLBACK_RULES_SECTION}}"
        } else {
            $content = Get-Content -Path $templatePath -Raw
        }
        
        # Local models
        $localModels = ""
        foreach ($model in $Config.SelectedModels) {
            $modelName = if ($model -is [string]) { $model } else { $model.Name }
            $localModels += @"
  - model_name: $modelName
    litellm_params:
      model: ollama/$modelName
      api_base: http://ollama:11434
"@ + "`n"
        }
        
        # Cloud models
        $cloudModels = ""
        if ($Config.CloudKeys) {
            if ($Config.CloudKeys.Contains('OPENAI_API_KEY')) {
                $cloudModels += @"
  - model_name: gpt-4o
    litellm_params:
      model: openai/gpt-4o
"@ + "`n"
            }
            if ($Config.CloudKeys.Contains('ANTHROPIC_API_KEY')) {
                $cloudModels += @"
  - model_name: claude-3-5-sonnet
    litellm_params:
      model: anthropic/claude-3-5-sonnet-20240620
"@ + "`n"
            }
        }
        
        $content = $content -replace '\{\{LOCAL_MODELS_SECTION\}\}', $localModels.TrimEnd()
        $content = $content -replace '\{\{CLOUD_MODELS_SECTION\}\}', $cloudModels.TrimEnd()
        
        # Fallback rules dummy
        $fallback = ""
        $content = $content -replace '\{\{FALLBACK_RULES_SECTION\}\}', $fallback
        
        # Replace LiteLLM key
        $liteLLMKey = Get-ConfigValue $Config 'LiteLLMKey' $null
        if (-not $liteLLMKey) { $liteLLMKey = New-LiteLLMKey; $Config.LiteLLMKey = $liteLLMKey }
        $content = $content -replace '\{\{LITELLM_KEY\}\}', $liteLLMKey
        
        # Ensure config dir exists
        $configDir = Split-Path $outPath
        if (-not (Test-Path $configDir)) { New-Item -ItemType Directory -Path $configDir -Force | Out-Null }
        
        $content | Out-File -FilePath $outPath -Encoding UTF8
        Write-LogMessage "Generated litellm_config.yaml" -Level Success
    } catch {
        Write-LogMessage "Error creating LiteLLM config: $_" -Level Error
        throw
    }
}

function New-EnvironmentFile {
    [CmdletBinding()]
    param($Config)
    
    try {
        $templatePath = Join-Path $script:ProjectRoot "templates\.env.tmpl"
        $outPath = Join-Path $script:ProjectRoot "config\.env"
        
        if (-not (Test-Path $templatePath)) {
            $content = "LITELLM_MASTER_KEY={{LITELLM_KEY}}`nMULTI_USER={{MULTI_USER}}"
        } else {
            $content = Get-Content -Path $templatePath -Raw
        }
        
        $liteLLMKey = New-LiteLLMKey
        $Config.LiteLLMKey = $liteLLMKey
        
        $hasMultiUser = $false
        $features = Get-ConfigValue $Config 'Features' $null
        try { $hasMultiUser = $features.MultiUser } catch {}
        $multiUser = if ($hasMultiUser) { "True" } else { "False" }
        
        $content = $content -replace '\{\{LITELLM_KEY\}\}', $liteLLMKey
        $content = $content -replace '\{\{MULTI_USER\}\}', $multiUser
        
        $content | Out-File -FilePath $outPath -Encoding UTF8
        Write-LogMessage "Generated .env file" -Level Success
    } catch {
        Write-LogMessage "Error creating env file: $_" -Level Error
        throw
    }
}

function New-SearXNGConfig {
    [CmdletBinding()]
    param($Config)
    
    try {
        $searxngConfigDir = Join-Path $script:ProjectRoot "config\searxng"
        if (-not (Test-Path $searxngConfigDir)) { New-Item -ItemType Directory -Path $searxngConfigDir | Out-Null }
        
        $settingsTmpl = Join-Path $script:ProjectRoot "templates\searxng\settings.yml.tmpl"
        $settingsOut = Join-Path $searxngConfigDir "settings.yml"
        if (Test-Path $settingsTmpl) {
            $content = Get-Content -Path $settingsTmpl -Raw
            $bytes = New-Object byte[] 16
            (New-Object System.Security.Cryptography.RNGCryptoServiceProvider).GetBytes($bytes)
            $hex = [System.BitConverter]::ToString($bytes) -replace '-'
            $content = $content -replace '\{\{SEARXNG_SECRET\}\}', $hex
            $content | Out-File -FilePath $settingsOut -Encoding UTF8
        }
        
        $limiterTmpl = Join-Path $script:ProjectRoot "templates\searxng\limiter.toml.tmpl"
        $limiterOut = Join-Path $searxngConfigDir "limiter.toml"
        if (Test-Path $limiterTmpl) {
            Copy-Item -Path $limiterTmpl -Destination $limiterOut -Force
        }
        
        Write-LogMessage "Generated SearXNG configuration" -Level Success
    } catch {
        Write-LogMessage "Error creating SearXNG config: $_" -Level Error
        throw
    }
}

function Start-DockerCompose {
    <#
    .SYNOPSIS
        Starts Docker Compose services with retry logic.
    .DESCRIPTION
        Pulls images first (with retries for transient network errors),
        then starts services. Separating pull from up avoids partial
        startups when one image fails to download.
    #>
    [CmdletBinding()]
    param()
    
    $configDir = Join-Path $script:ProjectRoot "config"
    $composePath = Join-Path $configDir "docker-compose.yml"
    $maxRetries = 3
    
    # Step 1: Pull images (retries for network failures)
    Write-LogMessage "Pulling Docker images..." -Level Step
    for ($attempt = 1; $attempt -le $maxRetries; $attempt++) {
        $process = Start-Process -FilePath "docker" -ArgumentList "compose -f `"$composePath`" --project-directory `"$($script:ProjectRoot)`" pull" -Wait -NoNewWindow -PassThru
        if ($process.ExitCode -eq 0) {
            Write-LogMessage "All images pulled successfully." -Level Success
            break
        }
        if ($attempt -lt $maxRetries) {
            $waitSecs = $attempt * 15
            Write-LogMessage "Image pull failed (attempt $attempt/$maxRetries). Retrying in ${waitSecs}s..." -Level Warning
            Start-Sleep -Seconds $waitSecs
        } else {
            Write-LogMessage "Image pull failed after $maxRetries attempts. Continuing with available images..." -Level Warning
        }
    }
    
    # Step 2: Start services
    try {
        Write-LogMessage "Starting Docker Compose services..." -Level Step
        Push-Location $script:ProjectRoot
        $process = Start-Process -FilePath "docker" -ArgumentList "compose -f `"$composePath`" --project-directory `"$($script:ProjectRoot)`" up -d" -Wait -NoNewWindow -PassThru
        Pop-Location
        
        if ($process.ExitCode -ne 0) {
            throw "Docker compose failed with exit code $($process.ExitCode)"
        }
        Write-LogMessage "Docker Compose started successfully." -Level Success
    } catch {
        Write-LogMessage "Failed to start docker compose: $_" -Level Error
        throw
    }
}

function Install-OllamaModels {
    [CmdletBinding()]
    param($Config)
    
    try {
        Write-LogMessage "Pulling selected models..." -Level Step
        
        $modelsToPull = @()
        foreach ($model in $Config.SelectedModels) {
            $modelsToPull += if ($model -is [string]) { $model } else { $model.Name }
        }
        
        # Pull llava:7b as vision model if system has >= 8GB RAM
        $systemRAM = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB
        if ($systemRAM -ge 8 -and 'llava:7b' -notin $modelsToPull) {
            $modelsToPull += 'llava:7b'
        }

        foreach ($modelName in $modelsToPull) {
            Write-Host "Pulling model: $modelName" -ForegroundColor Cyan
            $process = Start-Process -FilePath "docker" -ArgumentList "exec localllm-ollama ollama pull $modelName" -Wait -NoNewWindow -PassThru
            if ($process.ExitCode -ne 0) {
                Write-LogMessage "Failed to pull model $modelName" -Level Warning
            } else {
                Write-LogMessage "Model $modelName pulled successfully." -Level Success
            }
        }
    } catch {
        Write-LogMessage "Failed to pull models: $_" -Level Error
        throw
    }
}

function Wait-ForServices {
    [CmdletBinding()]
    param($Config, [int]$TimeoutSeconds = 120)
    
    try {
        Write-LogMessage "Waiting for services to become ready (Timeout: ${TimeoutSeconds}s)..." -Level Step
        
        $ollamaUrl = "http://localhost:$($Config.OllamaPort)/"
        $litellmUrl = "http://localhost:$($Config.LiteLLMPort)/health"
        $webuiUrl = "http://localhost:$($Config.WebUIPort)/"
        
        $services = @{
            "Ollama" = $ollamaUrl
            "LiteLLM" = $litellmUrl
            "OpenWebUI" = $webuiUrl
        }
        
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        
        foreach ($service in $services.Keys) {
            $url = $services[$service]
            $isReady = $false
            
            while ($stopwatch.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
                try {
                    $response = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 3 -ErrorAction Stop
                    $isReady = $true
                    Write-LogMessage "$service is ready." -Level Success
                    break
                } catch {
                    Start-Sleep -Seconds 3
                }
            }
            
            if (-not $isReady) {
                throw "$service failed to start within timeout."
            }
        }
        
        Write-LogMessage "All services are up and running." -Level Success
    } catch {
        Write-LogMessage "Service wait error: $_" -Level Error
        throw
    }
}

function Start-Deployment {
    [CmdletBinding()]
    param($Config)
    
    try {
        Write-LogMessage "Starting Deployment" -Level Step
        
        $configDir = Join-Path $script:ProjectRoot "config"
        if (-not (Test-Path $configDir)) {
            New-Item -ItemType Directory -Path $configDir | Out-Null
        }
        
        # Clean up stale Docker-created directories (Docker mounts missing files as dirs)
        $staleTargets = @(
            (Join-Path $configDir 'litellm_config.yaml'),
            (Join-Path $configDir 'tika-config.xml')
        )
        foreach ($target in $staleTargets) {
            if ((Test-Path $target) -and (Get-Item $target).PSIsContainer) {
                Remove-Item $target -Recurse -Force
                Write-LogMessage "Removed stale directory at $target (Docker artifact)" -Level Warning
            }
        }
        
        New-DockerComposeFile -Config $Config
        New-LiteLLMConfig -Config $Config
        New-EnvironmentFile -Config $Config
        
        $features = Get-ConfigValue $Config 'Features' $null
        $hasWebSearch = $false
        try { $hasWebSearch = $features.WebSearch } catch {}
        if ($hasWebSearch) {
            New-SearXNGConfig -Config $Config
        }
        
        Start-DockerCompose
        Wait-ForServices -Config $Config -TimeoutSeconds 120
        Install-OllamaModels -Config $Config
        
        Write-LogMessage "Deployment completed successfully!" -Level Success
    } catch {
        Write-LogMessage "Deployment failed: $_" -Level Error
        throw
    }
}
