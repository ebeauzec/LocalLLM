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

$script:ProjectRoot = $PSScriptRoot | Split-Path -Parent

function Install-WSL2 {
    <#
    .SYNOPSIS
    Installs WSL2 if not already enabled. Verifies functionality before
    requesting a reboot — avoids unnecessary reboots when WSL2/Docker
    is already working.
    #>
    [CmdletBinding()]
    param()
    
    try {
        Write-LogMessage "Checking WSL2 Status" -Level Step

        # Check 1: wsl --status
        $wslWorks = $false
        try {
            $wslStatus = wsl --status 2>&1 | Out-String
            if ($LASTEXITCODE -eq 0) { $wslWorks = $true }
        } catch {}

        # Check 2: wsl -l (lists distros — works even without --status)
        if (-not $wslWorks) {
            try {
                $wslList = wsl -l 2>&1 | Out-String
                if ($LASTEXITCODE -eq 0) { $wslWorks = $true }
            } catch {}
        }

        # Check 3: Windows feature enabled
        if (-not $wslWorks) {
            try {
                $feature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -ErrorAction SilentlyContinue
                if ($feature -and $feature.State -eq 'Enabled') { $wslWorks = $true }
            } catch {}
        }

        # Check 4: Docker is running with WSL2 backend (most reliable indicator)
        if (-not $wslWorks) {
            try {
                $dockerInfo = docker info 2>&1 | Out-String
                if ($dockerInfo -match 'WSL2' -or $dockerInfo -match 'wsl') { $wslWorks = $true }
            } catch {}
        }

        if ($wslWorks) {
            Write-LogMessage -Message 'WSL2 is already installed and functional' -Level Info
            return @{ Success=$true; RebootRequired=$false }
        }
        
        # WSL2 not working — install it
        Write-LogMessage "Installing WSL2..." -Level Info
        $process = Start-Process -FilePath "wsl.exe" -ArgumentList "--install --no-distribution" -Wait -NoNewWindow -PassThru
        
        # Verify if WSL2 works NOW (often works without reboot on modern Windows 11)
        Start-Sleep -Seconds 3
        $postInstallWorks = $false
        try {
            $check = wsl --status 2>&1 | Out-String
            if ($LASTEXITCODE -eq 0) { $postInstallWorks = $true }
        } catch {}

        # Also check if Docker is running (Docker+WSL2 = no reboot needed)
        if (-not $postInstallWorks) {
            try {
                $dockerRunning = docker info 2>&1 | Out-String
                if ($LASTEXITCODE -eq 0) { $postInstallWorks = $true }
            } catch {}
        }

        if ($postInstallWorks) {
            Write-LogMessage -Message 'WSL2 installed and working — no reboot needed' -Level Success
            return @{ Success=$true; RebootRequired=$false }
        }

        Write-LogMessage -Message 'WSL2 installed but may need a reboot to activate' -Level Warning
        return @{ Success=$true; RebootRequired=$true }
    } catch {
        Write-LogMessage -Message "Failed to install WSL2: $_" -Level Error
        return @{ Success=$false; RebootRequired=$false }
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
        Write-LogMessage "Checking Docker Desktop" -Level Step
        if (Get-Command docker -ErrorAction SilentlyContinue) {
            $dockerInfo = docker info 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-LogMessage -Message 'Found existing Docker running, skipping installation' -Level Info
                return $true
            } else {
                Write-LogMessage "Docker is installed but not running. Attempting to start..." -Level Warning
                Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
                
                # Poll docker info
                $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                Write-LogMessage "Waiting for Docker daemon to start..." -Level Info
                while ($stopwatch.Elapsed.TotalSeconds -lt 120) {
                    $dockerInfo = docker info 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Write-LogMessage "Docker daemon is ready." -Level Success
                        return $true
                    }
                    Start-Sleep -Seconds 5
                }
                Write-LogMessage "Docker failed to start within timeout." -Level Error
                return $false
            }
        }

        Write-LogMessage "Downloading Docker Desktop..." -Level Info
        $installerPath = "$env:TEMP\Docker Desktop Installer.exe"
        
        # Show download progress natively
        $progressPreference = 'Continue'
        Invoke-WebRequest -Uri "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe" -OutFile $installerPath
        $progressPreference = 'SilentlyContinue'

        Write-LogMessage "Installing Docker Desktop silently..." -Level Info
        $process = Start-Process -FilePath $installerPath -ArgumentList "install --quiet --accept-license" -Wait -NoNewWindow -PassThru

        if ($process.ExitCode -eq 0) {
            Write-LogMessage "Docker Desktop installed successfully." -Level Success
            return $true
        } else {
            Write-LogMessage "Docker installation returned exit code $($process.ExitCode)." -Level Error
            return $false
        }
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
        Write-LogMessage "Checking NVIDIA Container Toolkit" -Level Step
        $checkCmd = wsl -- nvidia-smi 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-LogMessage "NVIDIA GPU not detected in WSL, skipping toolkit installation." -Level Warning
            return $true
        }

        $ctkCheck = wsl -- nvidia-ctk --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-LogMessage -Message 'Found existing nvidia-ctk, skipping installation' -Level Info
            return $true
        }

        Write-LogMessage "Installing NVIDIA Container Toolkit inside WSL..." -Level Info
        wsl -u root -- bash -c "curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list && sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit"
        
        Write-LogMessage "NVIDIA Container Toolkit installed successfully." -Level Success
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
        Write-LogMessage "Testing Docker GPU Access..." -Level Step
        $res = docker run --rm --gpus all nvidia/cuda:12.0-base nvidia-smi 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-LogMessage "GPU Passthrough successful!" -Level Success
            return $true
        }
        Write-LogMessage "GPU Passthrough failed." -Level Error
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
            return $true
        }
        Write-LogMessage "Downloading Ollama Native Installer..." -Level Info
        $installer = "$env:TEMP\OllamaSetup.exe"
        
        $progressPreference = 'Continue'
        Invoke-WebRequest -Uri "https://ollama.com/download/OllamaSetup.exe" -OutFile $installer
        $progressPreference = 'SilentlyContinue'
        
        Write-LogMessage "Installing Ollama silently..." -Level Info
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
        $SystemProfile
    )
    
    $result = @{
        Success = $true
        RebootRequired = $false
        InstalledComponents = @()
        SkippedComponents = @()
        FailedComponents = @()
    }
    
    $wslResult = Install-WSL2
    if ($wslResult.Success) {
        $result.InstalledComponents += "WSL2"
        if ($wslResult.RebootRequired) {
            $result.RebootRequired = $true
        }
    } else {
        $result.Success = $false
        $result.FailedComponents += "WSL2"
    }
    
    if (Install-DockerDesktop) {
        $result.InstalledComponents += "Docker Desktop"
    } else {
        $result.Success = $false
        $result.FailedComponents += "Docker Desktop"
    }
    
    if ($SystemProfile.HasNvidiaGPU) {
        if (Install-NvidiaContainerToolkit) {
            $result.InstalledComponents += "NVIDIA Container Toolkit"
            Test-DockerGPUAccess | Out-Null
        } else {
            $result.Success = $false
            $result.FailedComponents += "NVIDIA Container Toolkit"
        }
    } else {
        $result.SkippedComponents += "NVIDIA Toolkit (no GPU detected)"
    }

    return $result
}
