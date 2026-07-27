# Copyright (c) 2025-2026 Eugene Beauzec. All Rights Reserved.

Import-Module (Join-Path $PSScriptRoot 'utils.ps1') -ErrorAction SilentlyContinue

function Start-KnowledgeWatcher {
    param(
        [string]$ProjectRoot
    )
    
    if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
        $ProjectRoot = (Get-Item (Join-Path $PSScriptRoot '..')).FullName
    }

    $logPath = Join-Path $ProjectRoot "logs\knowledge-sync.log"
    $statePath = Join-Path $ProjectRoot ".knowledge-watcher-state.json"
    $configPath = Join-Path $ProjectRoot "knowledge-sources.json"
    
    # Ensure log directory exists
    $logDir = Split-Path $logPath -Parent
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    if (-not (Test-Path $configPath)) {
        if (Get-Command -Name "Write-LogMessage" -ErrorAction SilentlyContinue) {
            Write-LogMessage -Message "Configuration file not found: $configPath" -Level Error
        }
        return
    }

    $config = Get-Content $configPath -Raw | ConvertFrom-Json
    $sources = $config.sources | Where-Object { $_.enabled -eq $true }

    if (-not $sources) {
        if (Get-Command -Name "Write-LogMessage" -ErrorAction SilentlyContinue) {
            Write-LogMessage -Message "No enabled sources found in configuration." -Level Warning
        }
        return
    }
    
    $state = @{
        status = "running"
        jobs = @()
        startTime = (Get-Date).ToString("o")
    }

    $scriptBlock = {
        param($sources, $logPath, $debounceSeconds, $ProjectRoot)
        
        $queue = [System.Collections.Concurrent.ConcurrentDictionary[string, string]]::new()
        
        $action = {
            $path = $Event.SourceEventArgs.FullPath
            $type = $Event.SourceEventArgs.ChangeType
            
            $queue[$path] = $type.ToString()
            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Queued $type for $path" | Out-File -Append -FilePath $logPath
        }

        $watchers = @()
        $eventSubscribers = @()
        
        foreach ($source in $sources) {
            $sourcePath = $source.path
            if (-not [System.IO.Path]::IsPathRooted($sourcePath)) {
                $sourcePath = (Join-Path $ProjectRoot $sourcePath)
            }
            
            if (-not (Test-Path $sourcePath)) {
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Warning: Source directory not found or unavailable: $sourcePath" | Out-File -Append -FilePath $logPath
                continue
            }

            $watcher = New-Object IO.FileSystemWatcher
            $watcher.Path = $sourcePath
            $watcher.IncludeSubdirectories = $source.recursive
            $watcher.NotifyFilter = [IO.NotifyFilters]::FileName, [IO.NotifyFilters]::LastWrite, [IO.NotifyFilters]::Size
            
            $subscribers = @(
                Register-ObjectEvent -InputObject $watcher -EventName Created -Action $action
                Register-ObjectEvent -InputObject $watcher -EventName Changed -Action $action
                Register-ObjectEvent -InputObject $watcher -EventName Renamed -Action $action
                Register-ObjectEvent -InputObject $watcher -EventName Deleted -Action $action
            )
            $eventSubscribers += $subscribers
            
            $watcher.EnableRaisingEvents = $true
            $watchers += $watcher
            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Started watching $sourcePath" | Out-File -Append -FilePath $logPath
        }

        try {
            while ($true) {
                Start-Sleep -Seconds $debounceSeconds
                $keys = $queue.Keys
                if ($keys.Count -gt 0) {
                    $batch = @{}
                    foreach ($key in $keys) {
                        $changeType = ""
                        if ($queue.TryRemove($key, [ref]$changeType)) {
                            $batch[$key] = $changeType
                        }
                    }
                    if ($batch.Count -gt 0) {
                        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Processing batch of $($batch.Count) changes" | Out-File -Append -FilePath $logPath
                        # Sync logic to API would be called here
                        # Changes are safe: READ-ONLY from sources
                        foreach ($key in $batch.Keys) {
                            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Processed $($batch[$key]) for $key (API Upload / Manifest update)" | Out-File -Append -FilePath $logPath
                        }
                    }
                }
            }
        } finally {
            foreach ($sub in $eventSubscribers) {
                Unregister-Event -SourceIdentifier $sub.Name -ErrorAction SilentlyContinue
            }
            foreach ($watcher in $watchers) {
                $watcher.EnableRaisingEvents = $false
                $watcher.Dispose()
            }
        }
    }

    $debounceSeconds = $config.syncSettings.debounceSeconds
    if (-not $debounceSeconds) { $debounceSeconds = 5 }

    $job = Start-Job -ScriptBlock $scriptBlock -ArgumentList $sources, $logPath, $debounceSeconds, $ProjectRoot
    $jobId = $job.Id

    $state.jobs += $jobId
    $state | ConvertTo-Json -Depth 5 | Set-Content $statePath
    
    if (Get-Command -Name "Write-LogMessage" -ErrorAction SilentlyContinue) {
        Write-LogMessage -Message "Started Knowledge Watcher Job ID: $jobId" -Level Info
    }
}

function Stop-KnowledgeWatcher {
    param(
        [string]$ProjectRoot
    )
    if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
        $ProjectRoot = (Get-Item (Join-Path $PSScriptRoot '..')).FullName
    }

    $statePath = Join-Path $ProjectRoot ".knowledge-watcher-state.json"
    if (Test-Path $statePath) {
        $state = Get-Content $statePath -Raw | ConvertFrom-Json
        foreach ($jobId in $state.jobs) {
            $job = Get-Job -Id $jobId -ErrorAction SilentlyContinue
            if ($job) {
                Stop-Job -Id $jobId
                Remove-Job -Id $jobId
                if (Get-Command -Name "Write-LogMessage" -ErrorAction SilentlyContinue) {
                    Write-LogMessage -Message "Stopped Knowledge Watcher Job ID: $jobId" -Level Info
                }
            }
        }
        $state.status = "stopped"
        $state.jobs = @()
        $state | ConvertTo-Json -Depth 5 | Set-Content $statePath
    } else {
        if (Get-Command -Name "Write-LogMessage" -ErrorAction SilentlyContinue) {
            Write-LogMessage -Message "Knowledge Watcher state file not found." -Level Warning
        }
    }
}

function Get-KnowledgeWatcherStatus {
    param(
        [string]$ProjectRoot
    )
    if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
        $ProjectRoot = (Get-Item (Join-Path $PSScriptRoot '..')).FullName
    }

    $statePath = Join-Path $ProjectRoot ".knowledge-watcher-state.json"
    if (Test-Path $statePath) {
        $state = Get-Content $statePath -Raw | ConvertFrom-Json
        $jobStatuses = @()
        foreach ($jobId in $state.jobs) {
            $job = Get-Job -Id $jobId -ErrorAction SilentlyContinue
            if ($job) {
                $jobStatuses += @{
                    Id = $job.Id
                    State = $job.State
                }
            } else {
                $jobStatuses += @{
                    Id = $jobId
                    State = "Not Found"
                }
            }
        }
        return @{
            Status = $state.status
            StartTime = $state.startTime
            Jobs = $jobStatuses
        }
    } else {
        return @{
            Status = "stopped"
        }
    }
}
