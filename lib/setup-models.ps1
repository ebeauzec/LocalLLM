#Requires -Version 5.1
<#
.SYNOPSIS
    Creates custom Ollama models from Modelfiles.

.DESCRIPTION
    This module reads Modelfiles from the models directory, replaces placeholders
    with configured model names, and uses the Ollama CLI (via Docker) to create
    custom model profiles.

.NOTES
    Copyright (c) 2025-2026 Eugene Beauzec. All Rights Reserved.
    License: Proprietary - All Rights Reserved
#>

# Import utils for Write-LogMessage if not already loaded
if (-not (Get-Command Write-LogMessage -ErrorAction SilentlyContinue)) {
    $utilsPath = Join-Path -Path $PSScriptRoot -ChildPath "utils.ps1"
    if (Test-Path $utilsPath) {
        . $utilsPath
    } else {
        function Write-LogMessage {
            param($Message, $Level = "INFO")
            Write-Host "[$Level] $Message"
        }
    }
}

<#
.SYNOPSIS
    Installs custom Ollama models from Modelfiles.
.DESCRIPTION
    Reads Modelfiles, replaces placeholders, and pipes them to docker exec ollama create.
#>
function Install-CustomModels {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        $Configuration
    )

    try {
        Write-LogMessage -Message "Starting custom models installation..." -Level "INFO"
        
        $modelsDir = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath "models"
        
        if (-not (Test-Path $modelsDir)) {
            Write-LogMessage -Message "Models directory not found at $modelsDir" -Level "WARNING"
            return
        }

        # Get model assignments with safe fallbacks
        $selectedModels = @()
        try { $selectedModels = @($Configuration.SelectedModels) } catch {}
        $firstModel = if ($selectedModels.Count -gt 0) {
            $m = $selectedModels[0]
            if ($m -is [string]) { $m } else { $m.Name }
        } else { "llama3.2" }
        
        $baseModel = $firstModel
        $reasoningModel = $firstModel
        $codeModel = $firstModel
        try { if ($Configuration.BaseModel) { $baseModel = $Configuration.BaseModel } } catch {}
        try { if ($Configuration.ReasoningModel) { $reasoningModel = $Configuration.ReasoningModel } } catch {}
        try { if ($Configuration.CodeModel) { $codeModel = $Configuration.CodeModel } } catch {}

        $modelMapping = @{
            "general-assistant.modelfile"         = "localllm-assistant"
            "reasoning-engine.modelfile"          = "localllm-reasoning"
            "code-developer.modelfile"            = "localllm-developer"
            "data-analyst.modelfile"              = "localllm-analyst"
            "creative-writer.modelfile"           = "localllm-creative"
            "security-analyst.modelfile"          = "localllm-security"
            "solutions-architect.modelfile"       = "localllm-architect"
            "storage-engineer.modelfile"          = "localllm-storage"
            "technical-account-manager.modelfile" = "localllm-tam"
            "devops-engineer.modelfile"           = "localllm-devops"
            "executive-advisor.modelfile"         = "localllm-executive"
            "technical-writer.modelfile"          = "localllm-writer"
            "project-manager.modelfile"           = "localllm-pm"
            "document-processor.modelfile"        = "localllm-docproc"
        }

        foreach ($file in $modelMapping.Keys) {
            $filePath = Join-Path -Path $modelsDir -ChildPath $file
            $modelName = $modelMapping[$file]

            if (Test-Path $filePath) {
                Write-LogMessage -Message "Processing $file for custom model $modelName..." -Level "INFO"
                
                # Read content and replace placeholders
                $content = Get-Content -Path $filePath -Raw
                $content = $content -replace "\{\{BASE_MODEL\}\}", $baseModel
                $content = $content -replace "\{\{REASONING_MODEL\}\}", $reasoningModel
                $content = $content -replace "\{\{CODE_MODEL\}\}", $codeModel

                # Create temp file for Docker to use
                $tempFile = [System.IO.Path]::GetTempFileName()
                Set-Content -Path $tempFile -Value $content -Encoding UTF8

                try {
                    # Execute ollama create via docker
                    $catCmd = Get-Content -Path $tempFile -Raw
                    
                    Write-LogMessage -Message "Creating model $modelName in Ollama..." -Level "INFO"
                    # Using PowerShell pipelining to docker exec might be tricky,
                    # writing a sh script in the container or passing via stdin
                    $dockerCmd = "docker exec -i ollama bash -c 'cat > /tmp/modelfile && ollama create $modelName -f /tmp/modelfile'"
                    $content | docker exec -i localllm-ollama sh -c "cat > /tmp/modelfile && ollama create $modelName -f /tmp/modelfile"
                    
                    Write-LogMessage -Message "Successfully created $modelName" -Level "INFO"
                } catch {
                    Write-LogMessage -Message "Failed to create model ${modelName}: $_" -Level "ERROR"
                } finally {
                    Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
                }
            } else {
                Write-LogMessage -Message "Modelfile not found: $filePath" -Level "WARNING"
            }
        }
        
        Write-LogMessage -Message "Custom models installation completed." -Level "INFO"
    } catch {
        Write-LogMessage -Message "Error installing custom models: $_" -Level "ERROR"
        throw
    }
}

<#
.SYNOPSIS
    Checks which custom models are created and reports status.
#>
function Get-CustomModelStatus {
    [CmdletBinding()]
    param ()

    try {
        Write-LogMessage -Message "Checking custom models status..." -Level "INFO"
        
        $ollamaList = docker exec ollama ollama list
        
        $expectedModels = @(
            "localllm-assistant",
            "localllm-reasoning",
            "localllm-developer",
            "localllm-analyst",
            "localllm-creative",
            "localllm-security"
        )

        $status = @()

        foreach ($model in $expectedModels) {
            $isInstalled = ($ollamaList -match "$model")
            $statusObj = [PSCustomObject]@{
                ModelName = $model
                Installed = $isInstalled
            }
            $status += $statusObj
            
            if ($isInstalled) {
                Write-LogMessage -Message "Model $model is INSTALLED" -Level "INFO"
            } else {
                Write-LogMessage -Message "Model $model is NOT INSTALLED" -Level "WARNING"
            }
        }

        return $status
    } catch {
        Write-LogMessage -Message "Error getting custom model status: $_" -Level "ERROR"
        throw
    }
}
