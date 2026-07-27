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
    try {
        # Try nvidia-smi first
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
                }
            }
        }
    } catch {}

    if ($gpus.Count -eq 0) {
        try {
            $videoControllers = Get-CimInstance Win32_VideoController
            foreach ($vc in $videoControllers) {
                $vendor = "Unknown"
                if ($vc.Name -match "NVIDIA") { $vendor = "NVIDIA" }
                elseif ($vc.Name -match "AMD|Radeon") { $vendor = "AMD" }
                elseif ($vc.Name -match "Intel") { $vendor = "Intel" }
                
                $vramGB = 0
                if ($vc.AdapterRAM) {
                    $vramGB = [math]::Round($vc.AdapterRAM / 1GB, 2)
                }
                $gpus += @{
                    Name = $vc.Name
                    Vendor = $vendor
                    VRAM_GB = $vramGB
                    DriverVersion = $vc.DriverVersion
                }
            }
        } catch {}
    }
    return $gpus
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
    $gpus = @(Get-GPUInfo)
    $disk = Get-DiskInfo
    $os = Get-OSInfo
    $tools = Get-ExistingTools
    
    $maxVram = 0
    $hasNvidia = $false
    $hasAMD = $false
    $primaryGPU = $null
    foreach ($g in $gpus) {
        if ($g.VRAM_GB -gt $maxVram) {
            $maxVram = $g.VRAM_GB
            $primaryGPU = $g
        }
        if ($g.Vendor -eq "NVIDIA") { $hasNvidia = $true }
        if ($g.Vendor -eq "AMD") { $hasAMD = $true }
    }
    
    $tier = Get-HardwareTier -RAM_GB $mem.TotalGB -VRAM_GB $maxVram
    $recommendGPU = ($maxVram -gt 4)
    
    $profile = [PSCustomObject]@{
        CPU = $cpu
        Memory = $mem
        GPUs = $gpus
        Disk = $disk
        OS = $os
        ExistingTools = $tools
        HardwareTier = $tier
        HasNvidiaGPU = $hasNvidia
        HasAMDGPU = $hasAMD
        PrimaryGPU = $primaryGPU
        RecommendGPUInference = $recommendGPU
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
    Write-Host "CPU: $($Profile.CPU.Name) ($($Profile.CPU.Cores) cores)"
    Write-Host "RAM: $($Profile.Memory.TotalGB) GB"
    if ($Profile.GPUs.Count -gt 0) {
        foreach ($g in $Profile.GPUs) {
            Write-Host "GPU: $($g.Name) ($($g.VRAM_GB) GB VRAM)"
        }
    } else {
        Write-Host "GPU: None detected"
    }
    Write-Host "Disk: $($Profile.Disk.FreeGB) GB free on $($Profile.Disk.Drive)"
    Write-Host "Hardware Tier: $($Profile.HardwareTier)" -ForegroundColor Magenta
    
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
