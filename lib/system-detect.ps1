<#
.SYNOPSIS
    Hardware and software detection module for LocalLLM.
.DESCRIPTION
    Detects hardware specs and checks for existing tool installations.
.COPYRIGHT
    (c) 2025-2026 Eugene Beauzec. All Rights Reserved.
    Project: LocalLLM - Self-Contained Local AI Platform
#>
#Requires -Version 5.1

Import-Module (Join-Path $PSScriptRoot "utils.ps1") -ErrorAction SilentlyContinue

function Get-CPUInfo {
    <#
    .SYNOPSIS
        Gets CPU information.
    #>
    try {
        $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
        return @{
            Name = $cpu.Name
            Cores = $cpu.NumberOfCores
            LogicalProcessors = $cpu.NumberOfLogicalProcessors
            Architecture = $cpu.Architecture
            SpeedMHz = $cpu.MaxClockSpeed
        }
    } catch {
        return @{ Name="Unknown"; Cores=0; LogicalProcessors=0; Architecture=0; SpeedMHz=0 }
    }
}

function Get-MemoryInfo {
    <#
    .SYNOPSIS
        Gets RAM information.
    #>
    try {
        $mem = Get-CimInstance Win32_OperatingSystem
        $total = [math]::Round($mem.TotalVisibleMemorySize / 1MB, 2)
        $avail = [math]::Round($mem.FreePhysicalMemory / 1MB, 2)
        return @{ TotalGB = $total; AvailableGB = $avail }
    } catch {
        return @{ TotalGB = 0; AvailableGB = 0 }
    }
}

function Get-GPUInfo {
    <#
    .SYNOPSIS
        Gets GPU information.
    #>
    $gpus = @()
    $hasNvidia = $false
    $hasAMD = $false
    $hasIntel = $false
    $hasNpu = $false
    $npuName = ""

    # Nvidia
    try {
        $nvidiaSmi = Get-Command "nvidia-smi" -ErrorAction SilentlyContinue
        if ($nvidiaSmi) {
            $xml = & nvidia-smi -q -x | Select-Xml -XPath "//gpu"
            foreach ($node in $xml.Node) {
                $vramStr = $node.fb_memory_usage.total
                $vramGB = 0
                if ($vramStr -match "(\d+)") {
                    $vramGB = [math]::Round([double]$matches[1] / 1024, 2)
                }
                $gpus += @{
                    Name = $node.product_name
                    Vendor = "NVIDIA"
                    VRAM_GB = $vramGB
                    DriverVersion = $node.driver_version
                    ROCmCapable = $false
                    Architecture = 'Unknown'
                }
                $hasNvidia = $true
            }
        }
    } catch {}

    # WMI fallback for AMD/Intel and missing Nvidia
    try {
        $videoControllers = Get-CimInstance Win32_VideoController
        foreach ($vc in $videoControllers) {
            $vendor = "Unknown"
            $rocm = $false
            $arch = "Unknown"
            if ($vc.Name -match "NVIDIA") { 
                $vendor = "NVIDIA" 
                $hasNvidia = $true 
            }
            elseif ($vc.Name -match "AMD|Radeon") { 
                $vendor = "AMD" 
                $hasAMD = $true
                $rocm = $true
                if ($vc.Name -match "8060S|7900|7800|7700|7600") { $arch = "RDNA3" }
                elseif ($vc.Name -match "6900|6800|6700|6600") { $arch = "RDNA2" }
            }
            elseif ($vc.Name -match "Intel") { 
                $vendor = "Intel" 
                $hasIntel = $true 
            }
            
            $vramGB = 0
            if ($vc.AdapterRAM) {
                $vramGB = [math]::Round($vc.AdapterRAM / 1GB, 2)
            }
            
            $exists = $gpus | Where-Object { $_.Name -eq $vc.Name -and $_.Vendor -eq $vendor }
            if (-not $exists) {
                $gpus += @{
                    Name = $vc.Name
                    Vendor = $vendor
                    VRAM_GB = $vramGB
                    DriverVersion = $vc.DriverVersion
                    ROCmCapable = $rocm
                    Architecture = $arch
                }
            }
        }
    } catch {}

    # NPU Detection
    try {
        $npus = Get-PnpDevice -ErrorAction SilentlyContinue | Where-Object { $_.FriendlyName -match "NPU Compute Accelerator Device|Intel\(R\) AI Boost|Intel NPU|Hexagon" -or $_.FriendlyName -eq "AMD XDNA NPU" }
        if ($npus) {
            $hasNpu = $true
            $npuName = $npus[0].FriendlyName
        }
    } catch {}

    $primaryGPU = $null
    $maxVram = -1
    foreach ($g in $gpus) {
        if ($g.VRAM_GB -gt $maxVram) {
            $maxVram = $g.VRAM_GB
            $primaryGPU = $g
        }
    }

    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1

    return @{
        HasNvidiaGPU = $hasNvidia
        HasAMDGPU = $hasAMD
        HasIntelGPU = $hasIntel
        HasNPU = $hasNpu
        NPUName = $npuName
        PrimaryGPU = $primaryGPU
        AllGPUs = $gpus
        CPUCores = $cpu.NumberOfCores
        CPUThreads = $cpu.NumberOfLogicalProcessors
    }
}

function Get-AcceleratorConfig {
    param([hashtable]$GPUInfo, [hashtable]$SystemProfile)
    
    $config = @{
        DockerGPUMode = 'none'     # 'nvidia', 'amd-rocm', 'intel', 'none'
        OllamaImage = 'ollama/ollama:latest'  # or ollama/ollama:rocm
        OllamaEnvVars = @{}        # OLLAMA_NUM_PARALLEL, OLLAMA_NUM_THREADS, etc.
        DockerDevices = @()         # /dev/kfd, /dev/dri, etc.
        DockerGPUDeploy = $null     # GPU deploy block for docker-compose
    }
    
    # CPU optimization (always apply)
    $physicalCores = $GPUInfo.CPUCores
    $config.OllamaEnvVars['OLLAMA_NUM_PARALLEL'] = [math]::Min(4, [math]::Max(1, [math]::Floor($physicalCores / 4)))
    $config.OllamaEnvVars['OLLAMA_NUM_THREADS'] = $physicalCores
    $config.OllamaEnvVars['OLLAMA_FLASH_ATTENTION'] = '1'
    $config.OllamaEnvVars['OLLAMA_KEEP_ALIVE'] = '24h'
    
    # With 127GB RAM, can load multiple models
    $ramGB = $SystemProfile.TotalRAMGB
    if ($null -eq $ramGB) { $ramGB = $SystemProfile.Memory.TotalGB }
    $config.OllamaEnvVars['OLLAMA_MAX_LOADED_MODELS'] = [math]::Min(4, [math]::Max(1, [math]::Floor($ramGB / 16)))
    
    # KV cache optimization for high-memory systems
    if ($ramGB -ge 64) {
        $config.OllamaEnvVars['OLLAMA_KV_CACHE_TYPE'] = 'q8_0'
    } elseif ($ramGB -ge 32) {
        $config.OllamaEnvVars['OLLAMA_KV_CACHE_TYPE'] = 'q4_0'
    }
    
    # GPU-specific configuration
    if ($GPUInfo.HasNvidiaGPU) {
        $config.DockerGPUMode = 'nvidia'
        $config.DockerGPUDeploy = @"
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
"@
    } elseif ($GPUInfo.HasAMDGPU -and $GPUInfo.PrimaryGPU.ROCmCapable) {
        $config.DockerGPUMode = 'amd-rocm'
        $config.OllamaImage = 'ollama/ollama:rocm'
        $config.DockerDevices = @('/dev/kfd', '/dev/dri')
        # Set HSA_OVERRIDE_GFX_VERSION for RDNA3 cards
        if ($GPUInfo.PrimaryGPU.Architecture -eq 'RDNA3') {
            $config.OllamaEnvVars['HSA_OVERRIDE_GFX_VERSION'] = '11.0.0'
        }
    }
    
    return $config
}

function Get-DiskInfo {
    <#
    .SYNOPSIS
        Gets available disk space on the install drive.
    #>
    try {
        $driveLetter = (Get-Location).Drive.Name
        if (-not $driveLetter) { $driveLetter = "C" }
        $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$driveLetter:'"
        return @{
            Drive = "$driveLetter:"
            FreeGB = [math]::Round($disk.FreeSpace / 1GB, 2)
            TotalGB = [math]::Round($disk.Size / 1GB, 2)
        }
    } catch {
        return @{ Drive="Unknown"; FreeGB=0; TotalGB=0 }
    }
}

function Get-OSInfo {
    <#
    .SYNOPSIS
        Gets OS information.
    #>
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        return @{
            Name = $os.Caption
            Version = $os.Version
            Build = $os.BuildNumber
            Architecture = $os.OSArchitecture
        }
    } catch {
        return @{ Name="Unknown"; Version="0"; Build="0"; Architecture="Unknown" }
    }
}

function Get-ExistingTools {
    <#
    .SYNOPSIS
        Checks for existing installations of required tools.
    #>
    $tools = @{}
    
    # Docker Desktop
    $dockerInstalled = $false
    $dockerVer = ""
    $dockerRunning = $false
    try {
        if (Get-Command docker -ErrorAction SilentlyContinue) {
            $dockerInstalled = $true
            $dockerVer = (docker --version) -replace "Docker version ",""
            $dockerRunning = (docker info 2>&1) -match "Server:"
        }
    } catch {}
    $tools['Docker'] = @{ Installed=$dockerInstalled; Version=$dockerVer; Running=$dockerRunning; Path=""; Details=@{} }

    # Docker Compose
    $dcInstalled = $false
    $dcVer = ""
    try {
        if (Get-Command "docker-compose" -ErrorAction SilentlyContinue -or (docker compose version 2>$null)) {
            $dcInstalled = $true
            $dcVer = (docker compose version)
        }
    } catch {}
    $tools['DockerCompose'] = @{ Installed=$dcInstalled; Version=$dcVer; Running=$false; Path=""; Details=@{} }

    # WSL2
    $wslInstalled = $false
    try {
        if (Get-Command wsl -ErrorAction SilentlyContinue) {
            $wslInstalled = $true
            $status = (wsl --status 2>&1) -join " "
        }
    } catch {}
    $tools['WSL2'] = @{ Installed=$wslInstalled; Version=""; Running=$false; Path=""; Details=@{} }

    # Ollama
    $ollamaInstalled = $false
    $ollamaVer = ""
    $ollamaRunning = $false
    try {
        if (Get-Command ollama -ErrorAction SilentlyContinue) {
            $ollamaInstalled = $true
            $ollamaVer = (ollama --version)
            $ollamaRunning = (Invoke-WebRequest "http://127.0.0.1:11434" -UseBasicParsing -ErrorAction SilentlyContinue).StatusCode -eq 200
        }
    } catch {}
    $tools['Ollama'] = @{ Installed=$ollamaInstalled; Version=$ollamaVer; Running=$ollamaRunning; Path=""; Details=@{} }

    # LM Studio
    $lmInstalled = $false
    $lmPath = "$env:LOCALAPPDATA\Programs\lm-studio\LM Studio.exe"
    if (Test-Path $lmPath) {
        $lmInstalled = $true
    }
    $tools['LMStudio'] = @{ Installed=$lmInstalled; Version=""; Running=$false; Path=$lmPath; Details=@{} }

    # Python
    $pyInstalled = $false
    $pyVer = ""
    try {
        if (Get-Command python -ErrorAction SilentlyContinue) {
            $pyInstalled = $true
            $pyVer = (python --version)
        }
    } catch {}
    $tools['Python'] = @{ Installed=$pyInstalled; Version=$pyVer; Running=$false; Path=""; Details=@{} }

    # Node.js
    $nodeInstalled = $false
    $nodeVer = ""
    try {
        if (Get-Command node -ErrorAction SilentlyContinue) {
            $nodeInstalled = $true
            $nodeVer = (node -v)
        }
    } catch {}
    $tools['NodeJS'] = @{ Installed=$nodeInstalled; Version=$nodeVer; Running=$false; Path=""; Details=@{} }

    # Git
    $gitInstalled = $false
    $gitVer = ""
    try {
        if (Get-Command git -ErrorAction SilentlyContinue) {
            $gitInstalled = $true
            $gitVer = (git --version)
        }
    } catch {}
    $tools['Git'] = @{ Installed=$gitInstalled; Version=$gitVer; Running=$false; Path=""; Details=@{} }

    # NVIDIA Container Toolkit
    $nvCtkInstalled = $false
    try {
        if (Get-Command nvidia-ctk -ErrorAction SilentlyContinue) {
            $nvCtkInstalled = $true
        }
    } catch {}
    $tools['NvidiaToolkit'] = @{ Installed=$nvCtkInstalled; Version=""; Running=$false; Path=""; Details=@{} }

    return $tools
}

function Get-HardwareTier {
    <#
    .SYNOPSIS
        Classifies system into LOW/MEDIUM/HIGH/ULTRA.
    #>
    param ($RAM_GB, $VRAM_GB)
    
    if ($RAM_GB -gt 32 -and $VRAM_GB -gt 16) { return "ULTRA" }
    if ($RAM_GB -ge 17 -or $VRAM_GB -ge 9) { return "HIGH" }
    if ($RAM_GB -ge 9 -or $VRAM_GB -ge 5) { return "MEDIUM" }
    return "LOW"
}

function Get-SystemProfile {
    <#
    .SYNOPSIS
        Master function returning a complete profile object.
    #>
    $cpu = Get-CPUInfo
    $mem = Get-MemoryInfo
    $gpuInfo = Get-GPUInfo
    $gpus = $gpuInfo.AllGPUs
    $disk = Get-DiskInfo
    $os = Get-OSInfo
    $tools = Get-ExistingTools
    
    $maxVram = 0
    if ($gpuInfo.PrimaryGPU) {
        $maxVram = $gpuInfo.PrimaryGPU.VRAM_GB
    }
    
    $tier = Get-HardwareTier -RAM_GB $mem.TotalGB -VRAM_GB $maxVram
    $recommendGPU = ($maxVram -gt 4)

    # We need a partial profile for Get-AcceleratorConfig
    $tempProfile = @{ TotalRAMGB = $mem.TotalGB; Memory = $mem }
    $accelConfig = Get-AcceleratorConfig -GPUInfo $gpuInfo -SystemProfile $tempProfile
    
    $profile = [PSCustomObject]@{
        CPU = $cpu
        Memory = $mem
        GPUs = $gpus
        Disk = $disk
        OS = $os
        ExistingTools = $tools
        HardwareTier = $tier
        HasNvidiaGPU = $gpuInfo.HasNvidiaGPU
        HasAMDGPU = $gpuInfo.HasAMDGPU
        PrimaryGPU = $gpuInfo.PrimaryGPU
        RecommendGPUInference = $recommendGPU
        HasNPU = $gpuInfo.HasNPU
        NPUName = $gpuInfo.NPUName
        CPUCores = $gpuInfo.CPUCores
        CPUThreads = $gpuInfo.CPUThreads
        AcceleratorConfig = $accelConfig
    }
    return $profile
}

function Show-SystemReport {
    <#
    .SYNOPSIS
        Pretty-prints the system profile.
    #>
    param ($Profile)
    
    Write-Section -Title "System Report"
    Write-Host "OS: $($Profile.OS.Name) ($($Profile.OS.Architecture))"
    Write-Host "CPU: $($Profile.CPU.Name) ($($Profile.CPUCores) cores, $($Profile.CPUThreads) threads)"
    Write-Host "RAM: $($Profile.Memory.TotalGB) GB"
    if ($Profile.GPUs.Count -gt 0) {
        foreach ($g in $Profile.GPUs) {
            Write-Host "GPU: $($g.Name) ($($g.VRAM_GB) GB VRAM)"
        }
    } else {
        Write-Host "GPU: None detected"
    }
    if ($Profile.HasNPU) {
        Write-Host "NPU: $($Profile.NPUName)" -ForegroundColor Cyan
    } else {
        Write-Host "NPU: None detected"
    }
    Write-Host "Disk: $($Profile.Disk.FreeGB) GB free on $($Profile.Disk.Drive)"
    Write-Host "Hardware Tier: $($Profile.HardwareTier)" -ForegroundColor Magenta
    
    Write-Host "`nAccelerator Config:" -ForegroundColor Yellow
    Write-Host " Mode: $($Profile.AcceleratorConfig.DockerGPUMode)"
    Write-Host " Optimization: $($Profile.AcceleratorConfig.OllamaEnvVars['OLLAMA_NUM_THREADS']) threads, Parallel: $($Profile.AcceleratorConfig.OllamaEnvVars['OLLAMA_NUM_PARALLEL'])"
    
    Write-Host "`nExisting Tools:"
    foreach ($tool in $Profile.ExistingTools.Keys) {
        $info = $Profile.ExistingTools[$tool]
        if ($info.Installed) {
            Write-Host " [X] $tool (Installed: $($info.Version))" -ForegroundColor Green
        } else {
            Write-Host " [ ] $tool (Not Installed)" -ForegroundColor Gray
        }
    }
    Write-Host ""
}
