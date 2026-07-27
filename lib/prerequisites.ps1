#Requires -Version 5.1
# Copyright (c) 2025-2026 Eugene Beauzec. All Rights Reserved.
# Project: LocalLLM - Self-Contained Local AI Platform

<#
.SYNOPSIS
Prerequisite installation module for LocalLLM.
.DESCRIPTION
Checks for and installs necessary prerequisites like WSL2, Docker Desktop,
NVIDIA Container Toolkit, and native Ollama if required.
#>

function Install-WSL2 {
    <#
    .SYNOPSIS
    Installs WSL2 if not already enabled.
    #>
    [CmdletBinding()]
    param()
    
    try {
        Write-Section "Checking WSL2 Status"
        $wslStatus = wsl --status 2>&1
        if ($LASTEXITCODE -eq 0 -and $wslStatus -match "Default Version: 2") {
            Write-LogMessage -Message 'Found existing WSL2, skipping installation' -Level Info
            Write-Host "WSL2 is already installed and set to default version 2." -ForegroundColor Green
            return $true
        }
        
        Write-Host "Installing WSL2..." -ForegroundColor Cyan
        Start-Process -FilePath "wsl.exe" -ArgumentList "--install" -Wait -NoNewWindow
        
        Write-Host "WSL2 installation initiated. A reboot may be required." -ForegroundColor Yellow
        Write-LogMessage -Message 'WSL2 installation executed. Reboot may be needed.' -Level Warn
        return $true
    } catch {
        Write-LogMessage -Message "Failed to install WSL2: $_" -Level Error
        return $false
    }
}

function Install-DockerDesktop {
    <#
    .SYNOPSIS
    Installs Docker Desktop.
    #>
    [CmdletBinding()]
    param()

    try {
        Write-Section "Checking Docker Desktop"
        if (Get-Command docker -ErrorAction SilentlyContinue) {
            $dockerInfo = docker info 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-LogMessage -Message 'Found existing Docker running, skipping installation' -Level Info
                Write-Host "Docker is already installed and running." -ForegroundColor Green
                return $true
            } else {
                Write-Host "Docker is installed but not running. Attempting to start..." -ForegroundColor Yellow
                Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
                Start-Sleep -Seconds 15
                return $true
            }
        }

        Write-Host "Downloading Docker Desktop..." -ForegroundColor Cyan
        $installerPath = "$env:TEMP\Docker Desktop Installer.exe"
        Invoke-WebRequest -Uri "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe" -OutFile $installerPath -UseBasicParsing

        Write-Host "Installing Docker Desktop silently..." -ForegroundColor Cyan
        Start-Process -FilePath $installerPath -ArgumentList "install --quiet --accept-license" -Wait -NoNewWindow

        Write-Host "Docker Desktop installed successfully." -ForegroundColor Green
        return $true
    } catch {
        Write-LogMessage -Message "Failed to install Docker Desktop: $_" -Level Error
        return $false
    }
}

function Install-NvidiaContainerToolkit {
    <#
    .SYNOPSIS
    Installs NVIDIA Container toolkit in WSL.
    #>
    [CmdletBinding()]
    param()

    try {
        Write-Section "Checking NVIDIA Container Toolkit"
        $checkCmd = wsl -- nvidia-smi 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "NVIDIA GPU not detected in WSL, skipping toolkit installation." -ForegroundColor Yellow
            return $true
        }

        $ctkCheck = wsl -- nvidia-ctk --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-LogMessage -Message 'Found existing nvidia-ctk, skipping installation' -Level Info
            Write-Host "NVIDIA Container Toolkit already installed." -ForegroundColor Green
            return $true
        }

        Write-Host "Installing NVIDIA Container Toolkit inside WSL..." -ForegroundColor Cyan
        # Simplified instruction for demonstration
        wsl -u root -- bash -c "curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list && sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit"
        
        Write-Host "NVIDIA Container Toolkit installed successfully." -ForegroundColor Green
        return $true
    } catch {
        Write-LogMessage -Message "Failed to install NVIDIA Container Toolkit: $_" -Level Error
        return $false
    }
}

function Test-DockerGPUAccess {
    [CmdletBinding()]
    param()
    try {
        Write-Host "Testing Docker GPU Access..." -ForegroundColor Cyan
        $res = docker run --rm --gpus all nvidia/cuda:12.0-base nvidia-smi 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "GPU Passthrough successful!" -ForegroundColor Green
            return $true
        }
        Write-Host "GPU Passthrough failed." -ForegroundColor Red
        return $false
    } catch {
        Write-LogMessage -Message "GPU access test error: $_" -Level Error
        return $false
    }
}

function Install-OllamaNative {
    [CmdletBinding()]
    param()
    try {
        if (Get-Command ollama -ErrorAction SilentlyContinue) {
            Write-LogMessage -Message 'Found existing Ollama, skipping installation' -Level Info
            Write-Host "Ollama is already installed natively." -ForegroundColor Green
            return $true
        }
        Write-Host "Downloading Ollama Native Installer..." -ForegroundColor Cyan
        $installer = "$env:TEMP\OllamaSetup.exe"
        Invoke-WebRequest -Uri "https://ollama.com/download/OllamaSetup.exe" -OutFile $installer -UseBasicParsing
        Write-Host "Installing Ollama silently..." -ForegroundColor Cyan
        Start-Process $installer -ArgumentList "/VERYSILENT" -Wait -NoNewWindow
        return $true
    } catch {
        Write-LogMessage -Message "Failed to install Ollama Native: $_" -Level Error
        return $false
    }
}

function Install-Prerequisites {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$SystemProfile
    )
    
    $success = $true
    if (-not (Install-WSL2)) { $success = $false }
    if (-not (Install-DockerDesktop)) { $success = $false }
    
    if ($SystemProfile.HasNvidiaGPU) {
        if (-not (Install-NvidiaContainerToolkit)) { $success = $false }
        Test-DockerGPUAccess | Out-Null
    }

    return $success
}
