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
    .DESCRIPTION
        Models are organized by tier (LOW → TITAN) and category (General, Code,
        Reasoning, Vision, Embedding). The installer picks the best models that
        fit the detected hardware automatically.
    .NOTES
        Copyright (c) 2025-2026 Eugene Beauzec. All Rights Reserved.
    #>
    return @(
        # ── LOW TIER (4-8 GB RAM) ──
        @{
            Name = 'phi4-mini:3.8b'
            DisplayName = 'Phi 4 Mini 3.8B'
            Category = 'General'
            Description = 'Fast general model for low-end hardware'
            SizeGB = 2.5; MinRAM = 4; MinVRAM = 2; MinTier = 'LOW'
            SupportsToolCalling = $true; SupportsVision = $false
            IsDefault = $true; Priority = 1
        },
        @{
            Name = 'qwen2.5:3b'
            DisplayName = 'Qwen 2.5 3B'
            Category = 'Code'
            Description = 'Compact code generation model'
            SizeGB = 2.0; MinRAM = 4; MinVRAM = 2; MinTier = 'LOW'
            SupportsToolCalling = $false; SupportsVision = $false
            IsDefault = $true; Priority = 2
        },

        # ── MEDIUM TIER (8-16 GB RAM) ──
        @{
            Name = 'llama3.3:8b'
            DisplayName = 'Llama 3.3 8B'
            Category = 'General'
            Description = 'Excellent balanced model for most tasks'
            SizeGB = 4.5; MinRAM = 8; MinVRAM = 6; MinTier = 'MEDIUM'
            SupportsToolCalling = $true; SupportsVision = $false
            IsDefault = $true; Priority = 1
        },
        @{
            Name = 'qwen3:8b'
            DisplayName = 'Qwen 3 8B'
            Category = 'Code'
            Description = 'Strong coding model for mid-range hardware'
            SizeGB = 4.5; MinRAM = 8; MinVRAM = 6; MinTier = 'MEDIUM'
            SupportsToolCalling = $true; SupportsVision = $false
            IsDefault = $true; Priority = 2
        },
        @{
            Name = 'deepseek-r1:8b-distill'
            DisplayName = 'DeepSeek R1 8B Distill'
            Category = 'Reasoning'
            Description = 'Advanced reasoning for mid-range hardware'
            SizeGB = 4.5; MinRAM = 8; MinVRAM = 6; MinTier = 'MEDIUM'
            SupportsToolCalling = $true; SupportsVision = $false
            IsDefault = $true; Priority = 3
        },

        # ── HIGH TIER (16-32 GB RAM) ──
        @{
            Name = 'qwen3.6:14b'
            DisplayName = 'Qwen 3.6 14B'
            Category = 'General'
            Description = 'Powerful general-purpose model'
            SizeGB = 8.0; MinRAM = 16; MinVRAM = 12; MinTier = 'HIGH'
            SupportsToolCalling = $true; SupportsVision = $false
            IsDefault = $true; Priority = 1
        },
        @{
            Name = 'deepseek-r1:14b-distill'
            DisplayName = 'DeepSeek R1 14B Distill'
            Category = 'Reasoning'
            Description = 'High-end reasoning model'
            SizeGB = 8.0; MinRAM = 16; MinVRAM = 12; MinTier = 'HIGH'
            SupportsToolCalling = $true; SupportsVision = $false
            IsDefault = $true; Priority = 2
        },
        @{
            Name = 'codeqwen:14b'
            DisplayName = 'CodeQwen 14B'
            Category = 'Code'
            Description = 'High-end code generation'
            SizeGB = 8.0; MinRAM = 16; MinVRAM = 12; MinTier = 'HIGH'
            SupportsToolCalling = $true; SupportsVision = $false
            IsDefault = $true; Priority = 3
        },

        # ── ULTRA TIER (32-64 GB RAM) ──
        @{
            Name = 'qwen3.6:27b-q4_K_M'
            DisplayName = 'Qwen 3.6 27B'
            Category = 'General'
            Description = 'Top all-round model with excellent tool calling'
            SizeGB = 18.0; MinRAM = 32; MinVRAM = 24; MinTier = 'ULTRA'
            SupportsToolCalling = $true; SupportsVision = $false
            IsDefault = $true; Priority = 1
        },
        @{
            Name = 'deepseek-r1:32b-distill'
            DisplayName = 'DeepSeek R1 32B Distill'
            Category = 'Reasoning'
            Description = 'Ultra reasoning model'
            SizeGB = 20.0; MinRAM = 32; MinVRAM = 24; MinTier = 'ULTRA'
            SupportsToolCalling = $true; SupportsVision = $false
            IsDefault = $true; Priority = 2
        },
        @{
            Name = 'qwen2.5-coder:32b-instruct-q4_K_M'
            DisplayName = 'Qwen 2.5 Coder 32B'
            Category = 'Code'
            Description = 'Ultra code generation and refactoring'
            SizeGB = 20.0; MinRAM = 32; MinVRAM = 24; MinTier = 'ULTRA'
            SupportsToolCalling = $true; SupportsVision = $false
            IsDefault = $true; Priority = 3
        },

        # ── TITAN TIER (64+ GB RAM) — Flagship models ──
        @{
            Name = 'llama3.3:70b-instruct-q4_K_M'
            DisplayName = 'Llama 3.3 70B'
            Category = 'General'
            Description = 'Flagship general model — near GPT-4 quality'
            SizeGB = 42.0; MinRAM = 64; MinVRAM = 0; MinTier = 'TITAN'
            SupportsToolCalling = $true; SupportsVision = $false
            IsDefault = $true; Priority = 1
        },
        @{
            Name = 'deepseek-r1:70b-distill-q4_K_M'
            DisplayName = 'DeepSeek R1 70B Distill'
            Category = 'Reasoning'
            Description = 'Flagship reasoning — best local chain-of-thought'
            SizeGB = 42.0; MinRAM = 64; MinVRAM = 0; MinTier = 'TITAN'
            SupportsToolCalling = $true; SupportsVision = $false
            IsDefault = $true; Priority = 2
        },
        @{
            Name = 'qwen2.5-coder:32b-instruct-q8_0'
            DisplayName = 'Qwen 2.5 Coder 32B (Q8)'
            Category = 'Code'
            Description = 'Highest-quality code model with Q8 precision'
            SizeGB = 34.0; MinRAM = 64; MinVRAM = 0; MinTier = 'TITAN'
            SupportsToolCalling = $true; SupportsVision = $false
            IsDefault = $true; Priority = 3
        },

        # ── VISION MODELS (all tiers) ──
        @{
            Name = 'llava:7b'
            DisplayName = 'LLaVA 7B'
            Category = 'Vision'
            Description = 'Image understanding and analysis'
            SizeGB = 4.5; MinRAM = 8; MinVRAM = 4; MinTier = 'MEDIUM'
            SupportsToolCalling = $false; SupportsVision = $true
            IsDefault = $true; Priority = 10
        },
        @{
            Name = 'llava:13b'
            DisplayName = 'LLaVA 13B'
            Category = 'Vision'
            Description = 'High-quality image analysis'
            SizeGB = 8.0; MinRAM = 16; MinVRAM = 8; MinTier = 'HIGH'
            SupportsToolCalling = $false; SupportsVision = $true
            IsDefault = $true; Priority = 10
        },

        # ── EMBEDDING MODEL (for RAG / search) ──
        @{
            Name = 'nomic-embed-text:latest'
            DisplayName = 'Nomic Embed Text'
            Category = 'Embedding'
            Description = 'Fast text embeddings for search and RAG'
            SizeGB = 0.3; MinRAM = 4; MinVRAM = 0; MinTier = 'LOW'
            SupportsToolCalling = $false; SupportsVision = $false
            IsDefault = $true; Priority = 20
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
    
    $tierOrder = @{ 'LOW'=1; 'MEDIUM'=2; 'HIGH'=3; 'ULTRA'=4; 'TITAN'=5 }
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
        Automatically selects the optimal model set for the detected hardware.
    .DESCRIPTION
        Strategy: pick the BEST (highest-tier) default model in each category
        (General, Code, Reasoning, Vision, Embedding) that fits the hardware.
        Then verify total download fits available disk space.
    .NOTES
        Copyright (c) 2025-2026 Eugene Beauzec. All Rights Reserved.
    #>
    param ($SystemProfile)
    
    $tier = $SystemProfile.HardwareTier
    $models = Get-ModelsByTier -Tier $tier
    $tierOrder = @{ 'LOW'=1; 'MEDIUM'=2; 'HIGH'=3; 'ULTRA'=4; 'TITAN'=5 }
    $targetLevel = $tierOrder[$tier]
    
    if ($SystemProfile.ExistingTools.Ollama.Installed) {
        Write-LogMessage -Message "Ollama is already installed. Existing models will be reused where possible." -Level Info
    }
    
    # For each category, pick the highest-tier default model that fits
    $categories = @('General', 'Code', 'Reasoning', 'Vision', 'Embedding')
    $recommended = @()
    
    foreach ($cat in $categories) {
        $catModels = $models | Where-Object { $_.Category -eq $cat -and $_.IsDefault }
        if ($catModels) {
            # Pick the model with the highest MinTier (best quality that fits)
            $best = $catModels | Sort-Object { $tierOrder[$_.MinTier] } -Descending | Select-Object -First 1
            $recommended += $best
        }
    }
    
    # Verify total download fits disk (leave 10GB headroom)
    $totalSizeGB = ($recommended | Measure-Object -Property SizeGB -Sum).Sum
    $diskFreeGB = 100  # default
    try {
        $driveLetter = (Get-Location).Drive.Name
        if (-not $driveLetter) { $driveLetter = "C" }
        $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$driveLetter`:'"
        $diskFreeGB = [math]::Round($disk.FreeSpace / 1GB, 1)
    } catch {}
    
    if ($totalSizeGB -gt ($diskFreeGB - 10)) {
        Write-LogMessage "Total model size (${totalSizeGB}GB) exceeds available disk (${diskFreeGB}GB). Dropping largest models." -Level Warning
        # Remove largest models until it fits
        $recommended = $recommended | Sort-Object SizeGB
        $runningTotal = 0
        $trimmed = @()
        foreach ($m in $recommended) {
            if (($runningTotal + $m.SizeGB) -le ($diskFreeGB - 10)) {
                $trimmed += $m
                $runningTotal += $m.SizeGB
            }
        }
        $recommended = $trimmed
    }
    
    return $recommended
}

function Show-ModelSelection {
    <#
    .SYNOPSIS
        Displays the auto-selected model configuration with hardware context.
    #>
    param ($SystemProfile)
    
    $tier = $SystemProfile.HardwareTier
    $recommended = Get-RecommendedModels -SystemProfile $SystemProfile
    $totalSizeGB = ($recommended | Measure-Object -Property SizeGB -Sum).Sum
    $ramGB = $SystemProfile.Memory.TotalGB
    
    Write-Section -Title "Optimal Model Configuration (Tier: $tier)"
    
    Write-Host "  Hardware: $($SystemProfile.CPU.Name)" -ForegroundColor White
    Write-Host "  RAM: ${ramGB}GB | GPU: $(if ($SystemProfile.PrimaryGPU) { $SystemProfile.PrimaryGPU.Name } else { 'None' })" -ForegroundColor Gray
    if ($SystemProfile.HasNPU) { Write-Host "  NPU: $($SystemProfile.NPUName)" -ForegroundColor Gray }
    Write-Host ""
    
    # Group by category
    $categories = @('General', 'Code', 'Reasoning', 'Vision', 'Embedding')
    foreach ($cat in $categories) {
        $catModels = @($recommended | Where-Object { $_.Category -eq $cat })
        if ($catModels.Count -gt 0) {
            $icon = switch ($cat) {
                'General'   { '💬' }
                'Code'      { '💻' }
                'Reasoning' { '🧠' }
                'Vision'    { '👁️' }
                'Embedding' { '🔍' }
            }
            foreach ($m in $catModels) {
                $toolCall = if ($m.SupportsToolCalling) { '✅ Tools' } else { '' }
                $vision = if ($m.SupportsVision) { '✅ Vision' } else { '' }
                $extras = @($toolCall, $vision) | Where-Object { $_ } | Join-String -Separator ', '
                Write-Host "  $icon $($m.DisplayName) ($($m.SizeGB)GB) [$cat]" -ForegroundColor Cyan
                Write-Host "     $($m.Description) $(if ($extras) { "| $extras" })" -ForegroundColor Gray
            }
        }
    }
    
    Write-Host ""
    Write-Host "  📦 Total download: ~$([math]::Round($totalSizeGB, 1)) GB" -ForegroundColor Yellow
    Write-Host "  💾 Estimated memory usage: ~$([math]::Round($totalSizeGB * 1.2, 1)) GB loaded" -ForegroundColor Yellow
    Write-Host "  ⚡ Models will be downloaded during installation" -ForegroundColor Gray
    Write-Host ""
}
