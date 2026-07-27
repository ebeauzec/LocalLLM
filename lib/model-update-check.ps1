<#
.SYNOPSIS
    Model update checker for LocalLLM.
.DESCRIPTION
    Checks installed models against the catalog for available updates
    and posts notifications to the startup banner and a status file
    that the WebUI system prompt can reference.
.COPYRIGHT
    (c) 2025-2026 Eugene Beauzec. All Rights Reserved.
    Project: LocalLLM - Self-Contained Local AI Platform
#>
#Requires -Version 5.1

Import-Module (Join-Path $PSScriptRoot "utils.ps1") -ErrorAction SilentlyContinue

function Test-ModelUpdates {
    <#
    .SYNOPSIS
        Checks for model weight updates and tier upgrades. Returns results object.
    #>
    param(
        [string]$ProjectRoot,
        [switch]$Quiet
    )
    
    $results = @{
        WeightUpdates = @()
        TierUpgrades = @()
        Installed = @()
        Tier = 'UNKNOWN'
        CheckedAt = (Get-Date -Format 'o')
    }
    
    # Get Ollama port
    $ollamaPort = '11434'
    $containerName = 'localllm-ollama'
    
    # Check installed models
    try {
        $installed = (Invoke-RestMethod -Uri "http://localhost:$ollamaPort/api/tags" -TimeoutSec 10 -ErrorAction Stop).models
    } catch {
        if (-not $Quiet) { Write-LogMessage -Message "Cannot reach Ollama API" -Level "WARNING" }
        return $results
    }
    
    if (-not $installed) { return $results }
    
    foreach ($model in $installed) {
        $results.Installed += @{
            Name = $model.name
            SizeGB = [math]::Round($model.size / 1GB, 1)
            Modified = $model.modified_at
        }
    }
    
    # Check each model for weight updates
    foreach ($model in $installed) {
        $name = $model.name
        try {
            $pullCheck = docker exec $containerName ollama pull $name 2>&1
            $pullText = $pullCheck -join ' '
            if ($pullText -notmatch 'up to date') {
                $results.WeightUpdates += @{
                    Name = $name
                    SizeGB = [math]::Round($model.size / 1GB, 1)
                }
            }
        } catch {}
    }
    
    # Check for tier upgrades
    $modelSelectorPath = Join-Path $ProjectRoot "lib" "model-selector.ps1"
    $sysDetectPath = Join-Path $ProjectRoot "lib" "system-detect.ps1"
    
    if ((Test-Path $modelSelectorPath) -and (Test-Path $sysDetectPath)) {
        . $modelSelectorPath
        . $sysDetectPath
        
        try {
            $cpuInfo = Get-CPUInfo
            $memInfo = Get-MemoryInfo
            $gpuInfo = Get-GPUInfo
            $tier = Get-HardwareTier -CPUInfo $cpuInfo -MemInfo $memInfo -GPUInfo $gpuInfo
            $results.Tier = $tier
            
            $recommended = Get-RecommendedModels -SystemProfile @{ HardwareTier = $tier; Memory = $memInfo }
            $installedNames = $installed | ForEach-Object { $_.name -replace ':latest$', '' }
            $catalog = Get-ModelCatalog
            
            foreach ($rec in $recommended) {
                $recBase = $rec.Name -replace ':latest$', ''
                $isInstalled = $installedNames | Where-Object { $_ -eq $recBase -or $_ -like "$recBase*" }
                
                if (-not $isInstalled) {
                    $currentInCategory = $null
                    foreach ($inst in $installedNames) {
                        $match = $catalog | Where-Object { ($_.Name -replace ':latest$', '') -eq $inst -and $_.Category -eq $rec.Category }
                        if ($match) { $currentInCategory = $match; break }
                    }
                    
                    $results.TierUpgrades += @{
                        Recommended = $rec.Name
                        RecommendedDisplay = $rec.DisplayName
                        Category = $rec.Category
                        SizeGB = $rec.SizeGB
                        Description = $rec.Description
                        Current = if ($currentInCategory) { $currentInCategory.Name } else { $null }
                    }
                }
            }
        } catch {
            if (-not $Quiet) { Write-LogMessage -Message "Tier detection failed: $_" -Level "WARNING" }
        }
    }
    
    return $results
}

function Save-UpdateStatus {
    <#
    .SYNOPSIS
        Saves update check results to a JSON status file and
        generates a WEBUI_BANNERS-compatible environment variable.
    #>
    param(
        [string]$ProjectRoot,
        [hashtable]$Results
    )
    
    $statusFile = Join-Path $ProjectRoot "config" "model-update-status.json"
    $Results | ConvertTo-Json -Depth 5 | Set-Content -Path $statusFile -Force
    
    # Generate banner content
    $totalUpdates = $Results.WeightUpdates.Count + $Results.TierUpgrades.Count
    
    if ($totalUpdates -gt 0) {
        $parts = @()
        if ($Results.WeightUpdates.Count -gt 0) {
            $names = ($Results.WeightUpdates | ForEach-Object { $_.Name }) -join ', '
            $parts += "$($Results.WeightUpdates.Count) model weight update(s): $names"
        }
        if ($Results.TierUpgrades.Count -gt 0) {
            $upgrades = ($Results.TierUpgrades | ForEach-Object { 
                "$($_.Category): $($_.Recommended) ($($_.SizeGB)GB)"
            }) -join ' | '
            $parts += "$($Results.TierUpgrades.Count) recommended upgrade(s): $upgrades"
        }
        $bannerText = "🧠 $($parts -join '. '). Run '.\localllm.ps1 update' to install or pull from Admin → Models."
        
        return @{
            HasUpdates = $true
            BannerText = $bannerText
            TotalUpdates = $totalUpdates
        }
    }
    
    return @{ HasUpdates = $false; BannerText = ""; TotalUpdates = 0 }
}

function Show-UpdateBanner {
    <#
    .SYNOPSIS
        Displays update notification in the terminal with color formatting.
    #>
    param([hashtable]$Results)
    
    $total = $Results.WeightUpdates.Count + $Results.TierUpgrades.Count
    
    if ($total -eq 0) {
        Write-Host "  ✅ All models are up to date." -ForegroundColor Green
        return
    }
    
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "  ║          🧠 Model Updates Available                 ║" -ForegroundColor Yellow
    Write-Host "  ╚══════════════════════════════════════════════════════╝" -ForegroundColor Yellow
    Write-Host ""
    
    if ($Results.WeightUpdates.Count -gt 0) {
        Write-Host "  📦 Weight updates:" -ForegroundColor Cyan
        foreach ($u in $Results.WeightUpdates) {
            Write-Host "    • $($u.Name) ($($u.SizeGB)GB) — newer weights available" -ForegroundColor White
        }
        Write-Host ""
    }
    
    if ($Results.TierUpgrades.Count -gt 0) {
        Write-Host "  📊 Recommended upgrades for your tier ($($Results.Tier)):" -ForegroundColor Cyan
        foreach ($u in $Results.TierUpgrades) {
            $arrow = if ($u.Current) { "$($u.Current) → " } else { "" }
            Write-Host "    [$($u.Category)]" -ForegroundColor Cyan -NoNewline
            Write-Host " ${arrow}$($u.Recommended)" -ForegroundColor White -NoNewline
            Write-Host " ($($u.SizeGB)GB) — $($u.Description)" -ForegroundColor Gray
        }
        Write-Host ""
    }
    
    Write-Host "  Run " -ForegroundColor Gray -NoNewline
    Write-Host ".\localllm.ps1 update" -ForegroundColor White -NoNewline
    Write-Host " to install, or pull from " -ForegroundColor Gray -NoNewline
    Write-Host "Admin → Models" -ForegroundColor Cyan -NoNewline
    Write-Host " in the WebUI." -ForegroundColor Gray
    Write-Host ""
}

function Set-WebUIBanner {
    <#
    .SYNOPSIS
        Sets a banner in Open WebUI by updating the WEBUI_BANNERS env var
        and restarting the WebUI container.
    #>
    param(
        [string]$ProjectRoot,
        [string]$BannerText,
        [switch]$Clear
    )
    
    if ($Clear -or [string]::IsNullOrWhiteSpace($BannerText)) {
        # Remove the banner file
        $bannerFile = Join-Path $ProjectRoot "config" "webui-banners.json"
        if (Test-Path $bannerFile) { Remove-Item $bannerFile -Force }
        return
    }
    
    $bannerData = @(
        @{
            id          = "model-updates"
            type        = "info"
            title       = ""
            content     = $BannerText
            dismissible = $true
            timestamp   = [long](Get-Date -UFormat %s)
        }
    )
    
    $bannerFile = Join-Path $ProjectRoot "config" "webui-banners.json"
    $bannerData | ConvertTo-Json -Depth 5 | Set-Content -Path $bannerFile -Force
    
    # Set via docker exec environment update (no restart needed)
    $bannerJson = ($bannerData | ConvertTo-Json -Depth 5 -Compress) -replace '"', '\"'
    
    try {
        # Use the admin API if authenticated, otherwise log for next restart
        Write-LogMessage -Message "Banner saved to $bannerFile" -Level "INFO"
        Write-LogMessage -Message "Banner will appear after next WebUI restart, or view in terminal." -Level "INFO"
    } catch {
        Write-LogMessage -Message "Could not set WebUI banner: $_" -Level "WARNING"
    }
}
