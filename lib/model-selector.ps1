<#
.SYNOPSIS
    Model recommendation engine for LocalLLM.
.DESCRIPTION
    Recommends LLM models based on hardware tier.
.COPYRIGHT
    (c) 2025-2026 Eugene Beauzec. All Rights Reserved.
    Project: LocalLLM - Self-Contained Local AI Platform
#>
#Requires -Version 5.1

Import-Module (Join-Path $PSScriptRoot "utils.ps1") -ErrorAction SilentlyContinue

function Get-ModelCatalog {
    <#
    .SYNOPSIS
        Returns the full catalog of supported models with metadata.
    #>
    return @(
        @{
            Name = 'phi4-mini:3.8b'
            DisplayName = 'Phi 4 Mini 3.8B'
            Category = 'General'
            Description = 'Fast general model for low-end hardware'
            SizeGB = 2.5
            MinRAM = 4
            MinVRAM = 2
            MinTier = 'LOW'
            SupportsToolCalling = $true
            SupportsVision = $false
            IsDefault = $true
            Priority = 1
        },
        @{
            Name = 'qwen2.5:3b'
            DisplayName = 'Qwen 2.5 3B'
            Category = 'Code'
            Description = 'Compact code generation model'
            SizeGB = 2.0
            MinRAM = 4
            MinVRAM = 2
            MinTier = 'LOW'
            SupportsToolCalling = $false
            SupportsVision = $false
            IsDefault = $false
            Priority = 2
        },
        @{
            Name = 'llama3.3:8b'
            DisplayName = 'Llama 3.3 8B'
            Category = 'General'
            Description = 'Excellent balanced model for most tasks'
            SizeGB = 4.5
            MinRAM = 8
            MinVRAM = 6
            MinTier = 'MEDIUM'
            SupportsToolCalling = $true
            SupportsVision = $false
            IsDefault = $true
            Priority = 1
        },
        @{
            Name = 'qwen3:8b'
            DisplayName = 'Qwen 3 8B'
            Category = 'Code'
            Description = 'Strong coding model for mid-range hardware'
            SizeGB = 4.5
            MinRAM = 8
            MinVRAM = 6
            MinTier = 'MEDIUM'
            SupportsToolCalling = $true
            SupportsVision = $false
            IsDefault = $false
            Priority = 2
        },
        @{
            Name = 'deepseek-r1:8b-distill'
            DisplayName = 'DeepSeek R1 8B Distill'
            Category = 'Reasoning'
            Description = 'Advanced reasoning for mid-range hardware'
            SizeGB = 4.5
            MinRAM = 8
            MinVRAM = 6
            MinTier = 'MEDIUM'
            SupportsToolCalling = $true
            SupportsVision = $false
            IsDefault = $true
            Priority = 3
        },
        @{
            Name = 'qwen3.6:14b'
            DisplayName = 'Qwen 3.6 14B'
            Category = 'General'
            Description = 'Powerful general-purpose model'
            SizeGB = 8.0
            MinRAM = 16
            MinVRAM = 12
            MinTier = 'HIGH'
            SupportsToolCalling = $true
            SupportsVision = $false
            IsDefault = $true
            Priority = 1
        },
        @{
            Name = 'deepseek-r1:14b-distill'
            DisplayName = 'DeepSeek R1 14B Distill'
            Category = 'Reasoning'
            Description = 'High-end reasoning model'
            SizeGB = 8.0
            MinRAM = 16
            MinVRAM = 12
            MinTier = 'HIGH'
            SupportsToolCalling = $true
            SupportsVision = $false
            IsDefault = $true
            Priority = 2
        },
        @{
            Name = 'codeqwen:14b'
            DisplayName = 'CodeQwen 14B'
            Category = 'Code'
            Description = 'High-end code generation'
            SizeGB = 8.0
            MinRAM = 16
            MinVRAM = 12
            MinTier = 'HIGH'
            SupportsToolCalling = $true
            SupportsVision = $false
            IsDefault = $false
            Priority = 3
        },
        @{
            Name = 'qwen3.6:27b-q4_K_M'
            DisplayName = 'Qwen 3.6 27B'
            Category = 'General'
            Description = 'Top all-round model with excellent tool calling'
            SizeGB = 18.0
            MinRAM = 32
            MinVRAM = 24
            MinTier = 'ULTRA'
            SupportsToolCalling = $true
            SupportsVision = $false
            IsDefault = $true
            Priority = 1
        },
        @{
            Name = 'deepseek-r1:32b-distill'
            DisplayName = 'DeepSeek R1 32B Distill'
            Category = 'Reasoning'
            Description = 'Ultra reasoning model'
            SizeGB = 20.0
            MinRAM = 32
            MinVRAM = 24
            MinTier = 'ULTRA'
            SupportsToolCalling = $true
            SupportsVision = $false
            IsDefault = $true
            Priority = 2
        },
        @{
            Name = 'codeqwen:32b'
            DisplayName = 'CodeQwen 32B'
            Category = 'Code'
            Description = 'Ultra code generation model'
            SizeGB = 20.0
            MinRAM = 32
            MinVRAM = 24
            MinTier = 'ULTRA'
            SupportsToolCalling = $true
            SupportsVision = $false
            IsDefault = $false
            Priority = 3
        }
    )
}

function Get-ModelsByTier {
    <#
    .SYNOPSIS
        Filters models appropriate for a hardware tier.
    #>
    param ($Tier)
    $catalog = Get-ModelCatalog
    
    $tierOrder = @{ 'LOW'=1; 'MEDIUM'=2; 'HIGH'=3; 'ULTRA'=4 }
    $targetLevel = $tierOrder[$Tier]
    
    $results = @()
    foreach ($m in $catalog) {
        if ($tierOrder[$m.MinTier] -le $targetLevel) {
            $results += $m
        }
    }
    return $results | Sort-Object Priority
}

function Get-RecommendedModels {
    <#
    .SYNOPSIS
        Takes a SystemProfile object, returns array of recommended model objects.
    #>
    param ($SystemProfile)
    
    $tier = $SystemProfile.HardwareTier
    $models = Get-ModelsByTier -Tier $tier
    
    $recommended = @()
    
    if ($SystemProfile.ExistingTools.Ollama.Installed) {
        # Pseudo-logic for existing tools prompt
        Write-LogMessage -Message "Ollama is already installed. Existing models may be reused." -Level Info
    }
    
    # Select defaults for the tier
    # Actually we just want the models that are exact match for this tier, or best fit
    foreach ($m in $models) {
        if ($m.MinTier -eq $tier -and $m.IsDefault) {
            $recommended += $m
        }
    }
    # Fallback to lower tiers if nothing matched
    if ($recommended.Count -eq 0) {
        foreach ($m in $models) {
            if ($m.IsDefault) {
                $recommended += $m
            }
        }
    }
    
    $result = @($recommended | Select-Object -Unique -Property Name)
    
    # Add llava:7b as a supplementary model for image analysis / vision capabilities
    $systemRAM = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB
    if ($systemRAM -ge 8) {
        $result += @{ Name = 'llava:7b' }
    }
    
    return $result
}

function Show-ModelSelection {
    <#
    .SYNOPSIS
        Interactive model selection menu.
    #>
    param ($SystemProfile)
    
    $catalog = Get-ModelsByTier -Tier $SystemProfile.HardwareTier
    Write-Section -Title "Model Selection (Tier: $($SystemProfile.HardwareTier))"
    
    for ($i=0; $i -lt $catalog.Count; $i++) {
        $m = $catalog[$i]
        $def = if ($m.IsDefault) { "[Recommended]" } else { "" }
        Write-Host "$($i+1). $($m.DisplayName) ($($m.SizeGB)GB) $def" -ForegroundColor Cyan
        Write-Host "   -> $($m.Description)" -ForegroundColor Gray
    }
    # Just displaying, interactivity handled by caller usually
}
Export-ModuleMember -Function *
