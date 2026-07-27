# Copyright (c) 2025-2026 Eugene Beauzec. All Rights Reserved.

<#
.SYNOPSIS
Knowledge Repository sync engine for LocalLLM.

.DESCRIPTION
Syncs documents from READ-ONLY source folders into Open WebUI's RAG vector database.
#>

Import-Module (Join-Path $PSScriptRoot 'utils.ps1') -ErrorAction SilentlyContinue

# Default sources template if not exists
$DefaultSources = @{
    sources = @(
        @{ path = "knowledge/"; collection = "default"; recursive = $true }
    )
    fileTypes = @(".pdf", ".docx", ".doc", ".pptx", ".xlsx", ".csv", ".txt", ".md", ".rtf", ".eml", ".msg", ".html", ".json", ".xml", ".png", ".jpg", ".tiff")
    excludePatterns = @("**/node_modules/**", "**/.git/**", "**/~$*", "**/*.tmp")
    chunkSize = 1500
    chunkOverlap = 200
}

function Get-OpenWebUIToken {
    param([string]$ProjectRoot)
    
    # Try to read admin token from state or config
    $stateFile = Join-Path $ProjectRoot ".localllm-state.json"
    if (Test-Path $stateFile) {
        try {
            $state = Get-Content $stateFile -Raw | ConvertFrom-Json
            if ($state.webUiToken) { return $state.webUiToken }
        } catch { }
    }
    
    # Fallback to config
    $configFile = Join-Path $ProjectRoot "config" "localllm.config.json"
    if (Test-Path $configFile) {
        try {
            $config = Get-Content $configFile -Raw | ConvertFrom-Json
            if ($config.webUiToken) { return $config.webUiToken }
        } catch { }
    }
    
    throw "Could not find Open WebUI token in state or config."
}

function Invoke-WebUIApi {
    param(
        [Parameter(Mandatory=$true)] [string]$Endpoint,
        [Parameter(Mandatory=$false)] [string]$Method = "GET",
        [Parameter(Mandatory=$false)] [hashtable]$Body,
        [Parameter(Mandatory=$false)] [string]$Token,
        [Parameter(Mandatory=$false)] [switch]$IsMultipart,
        [Parameter(Mandatory=$false)] [hashtable]$Form
    )
    
    $baseUrl = "http://localhost:3000" # Should read from config/env
    $url = "$baseUrl/api/v1$Endpoint"
    
    $headers = @{}
    if ($Token) {
        $headers["Authorization"] = "Bearer $Token"
    }
    
    $params = @{
        Uri = $url
        Method = $Method
        Headers = $headers
        ErrorAction = "Stop"
    }
    
    if ($IsMultipart -and $Form) {
        $params.Form = $Form
    } elseif ($Body) {
        $params.Body = ($Body | ConvertTo-Json -Depth 10)
        $headers["Content-Type"] = "application/json"
    }
    
    try {
        return Invoke-RestMethod @params
    } catch {
        Write-LogMessage -Message "API Error calling $url`: $_" -Level Error
        throw $_
    }
}

function Get-KnowledgeSourcesConfig {
    param([string]$ProjectRoot)
    $configFile = Join-Path $ProjectRoot "knowledge-sources.json"
    
    if (-not (Test-Path $configFile)) {
        $DefaultSources | ConvertTo-Json -Depth 10 | Set-Content $configFile
    }
    
    return Get-Content $configFile -Raw | ConvertFrom-Json
}

function Save-KnowledgeSourcesConfig {
    param([string]$ProjectRoot, $Config)
    $configFile = Join-Path $ProjectRoot "knowledge-sources.json"
    $Config | ConvertTo-Json -Depth 10 | Set-Content $configFile
}

function Get-KnowledgeManifest {
    param([string]$ProjectRoot)
    $knowledgeDir = Join-Path $ProjectRoot "knowledge"
    if (-not (Test-Path $knowledgeDir)) {
        New-Item -ItemType Directory -Path $knowledgeDir -Force | Out-Null
    }
    
    $manifestFile = Join-Path $knowledgeDir ".knowledge-manifest.json"
    
    if (-not (Test-Path $manifestFile)) {
        return @{
            version = 1
            lastSync = $null
            collections = @{}
            files = @{}
        }
    }
    
    return Get-Content $manifestFile -Raw | ConvertFrom-Json -AsHashtable
}

function Save-KnowledgeManifest {
    param([string]$ProjectRoot, [hashtable]$Manifest)
    $manifestFile = Join-Path $ProjectRoot "knowledge\.knowledge-manifest.json"
    $Manifest.lastSync = (Get-Date).ToString("o")
    $Manifest | ConvertTo-Json -Depth 10 | Set-Content $manifestFile
}


function Sync-KnowledgeBase {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ProjectRoot,
        
        [switch]$Force,
        [switch]$DryRun
    )
    
    $config = Get-KnowledgeSourcesConfig -ProjectRoot $ProjectRoot
    $manifest = Get-KnowledgeManifest -ProjectRoot $ProjectRoot
    $token = Get-OpenWebUIToken -ProjectRoot $ProjectRoot
    
    $stats = @{ new = 0; updated = 0; unchanged = 0; removed = 0; errors = 0 }
    
    Write-LogMessage -Message "Starting knowledge base sync..." -Level Info
    
    # 1. Fetch existing knowledge bases from WebUI
    $kbs = @{}
    try {
        $webuiKbs = Invoke-WebUIApi -Endpoint "/knowledge" -Method GET -Token $token
        foreach ($kb in $webuiKbs) {
            $kbs[$kb.name] = $kb.id
        }
    } catch {
        Write-LogMessage -Message "Failed to fetch knowledge bases from WebUI" -Level Error
        return
    }
    
    # 2. Process sources
    $currentFiles = @{}
    
    foreach ($source in $config.sources) {
        $sourcePath = $source.path
        if (-not [System.IO.Path]::IsPathRooted($sourcePath)) {
            $sourcePath = Join-Path $ProjectRoot $sourcePath
        }
        
        if (-not (Test-Path $sourcePath)) {
            Write-LogMessage -Message "Source path not found: $sourcePath" -Level Warning
            continue
        }
        
        $collectionName = $source.collection
        
        # Ensure KB exists in WebUI
        if (-not $kbs.ContainsKey($collectionName) -and -not $DryRun) {
            Write-LogMessage -Message "Creating new knowledge base: $collectionName" -Level Info
            try {
                $newKb = Invoke-WebUIApi -Endpoint "/knowledge" -Method POST -Body @{ name = $collectionName; description = "Synced by LocalLLM" } -Token $token
                $kbs[$collectionName] = $newKb.id
                
                if (-not $manifest.collections.ContainsKey($collectionName)) {
                    $manifest.collections[$collectionName] = @{ webUIKnowledgeId = $newKb.id; fileCount = 0 }
                }
            } catch {
                Write-LogMessage -Message "Failed to create KB $collectionName" -Level Error
                continue
            }
        }
        
        # Get files
        $fileItems = @()
        if (Test-Path $sourcePath -PathType Leaf) {
            $fileItems = @(Get-Item $sourcePath)
        } else {
            $fileItems = Get-ChildItem -Path $sourcePath -Recurse:$source.recursive -File -ErrorAction SilentlyContinue | Where-Object {
                $ext = $_.Extension.ToLower()
                $config.fileTypes -contains $ext
            }
        }
        
        foreach ($file in $fileItems) {
            $relPath = if ($file.FullName.StartsWith($ProjectRoot)) { $file.FullName.Substring($ProjectRoot.Length).Trim('\/') } else { $file.FullName }
            $currentFiles[$relPath] = $true
            
            try {
                $hash = (Get-FileHash -Path $file.FullName -Algorithm SHA256).Hash
                $size = $file.Length
                $modified = $file.LastWriteTimeUtc.ToString("o")
                
                $needsSync = $true
                $isNew = $true
                
                if (-not $Force -and $manifest.files.ContainsKey($relPath)) {
                    $isNew = $false
                    $existing = $manifest.files[$relPath]
                    if ($existing.hash -eq $hash) {
                        $needsSync = $false
                    }
                }
                
                if ($needsSync) {
                    if ($DryRun) {
                        Write-Host "[DRY RUN] Would sync: $relPath"
                        if ($isNew) { $stats.new++ } else { $stats.updated++ }
                    } else {
                        Write-LogMessage -Message "Syncing file: $relPath" -Level Info
                        
                        # Upload to WebUI
                        $form = @{
                            file = Get-Item -Path $file.FullName
                        }
                        $uploaded = Invoke-WebUIApi -Endpoint "/files" -Method POST -IsMultipart -Form $form -Token $token
                        $fileId = $uploaded.id
                        
                        # Add to Knowledge Base
                        $kbId = $kbs[$collectionName]
                        Invoke-WebUIApi -Endpoint "/knowledge/$kbId/file/add" -Method POST -Body @{ file_id = $fileId } -Token $token
                        
                        $manifest.files[$relPath] = @{
                            hash = $hash
                            size = $size
                            lastModified = $modified
                            syncedAt = (Get-Date).ToString("o")
                            collection = $collectionName
                            webUIFileId = $fileId
                            status = "synced"
                        }
                        
                        if ($isNew) { $stats.new++ } else { $stats.updated++ }
                    }
                } else {
                    $stats.unchanged++
                }
            } catch {
                Write-LogMessage -Message "Error processing file $($file.FullName): $_" -Level Error
                $stats.errors++
            }
        }
    }
    
    # 3. Handle removed files
    if (-not $DryRun) {
        $filesToRemove = @()
        foreach ($key in $manifest.files.Keys) {
            if (-not $currentFiles.ContainsKey($key) -and $manifest.files[$key].status -eq "synced") {
                $filesToRemove += $key
            }
        }
        
        foreach ($key in $filesToRemove) {
            Write-LogMessage -Message "File removed from source: $key" -Level Info
            $manifest.files[$key].status = "removed"
            $stats.removed++
        }
        
        # Save manifest
        Save-KnowledgeManifest -ProjectRoot $ProjectRoot -Manifest $manifest
    }
    
    Write-LogMessage -Message "Sync complete. New: $($stats.new), Updated: $($stats.updated), Unchanged: $($stats.unchanged), Removed: $($stats.removed), Errors: $($stats.errors)" -Level Info
    
    if ($Verbose) {
        $stats | Format-Table
    }
}

function Add-KnowledgeSource {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ProjectRoot,
        
        [Parameter(Mandatory=$true)]
        [string]$Path,
        
        [Parameter(Mandatory=$true)]
        [string]$Collection,
        
        [switch]$Recursive
    )
    
    if (-not (Test-Path $Path)) {
        throw "Path does not exist: $Path"
    }
    
    $fullPath = (Resolve-Path $Path).Path
    $projectRootFull = (Resolve-Path $ProjectRoot).Path
    
    if ($fullPath.StartsWith((Join-Path $projectRootFull "config")) -or $fullPath.StartsWith((Join-Path $projectRootFull "lib"))) {
        throw "Cannot add knowledge sources from config/ or lib/ folders."
    }
    
    $config = Get-KnowledgeSourcesConfig -ProjectRoot $ProjectRoot
    
    # Check if already exists
    $exists = $config.sources | Where-Object { $_.path -eq $Path -and $_.collection -eq $Collection }
    if ($exists) {
        Write-Warning "Source already exists."
        return
    }
    
    $config.sources += @{ path = $Path; collection = $Collection; recursive = $Recursive.IsPresent }
    Save-KnowledgeSourcesConfig -ProjectRoot $ProjectRoot -Config $config
    
    Write-Host "Added source $Path to collection $Collection. Running initial sync..."
    Sync-KnowledgeBase -ProjectRoot $ProjectRoot
}

function Remove-KnowledgeSource {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ProjectRoot,
        
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    
    $config = Get-KnowledgeSourcesConfig -ProjectRoot $ProjectRoot
    $newSources = $config.sources | Where-Object { $_.path -ne $Path }
    
    if ($newSources.Count -eq $config.sources.Count) {
        Write-Warning "Source not found: $Path"
        return
    }
    
    $config.sources = @($newSources)
    Save-KnowledgeSourcesConfig -ProjectRoot $ProjectRoot -Config $config
    
    Write-Host "Removed source $Path. Note: No indexed files have been deleted from the knowledge base."
}

function Get-KnowledgeStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ProjectRoot
    )
    
    $manifest = Get-KnowledgeManifest -ProjectRoot $ProjectRoot
    
    Write-Host "Knowledge Base Status" -ForegroundColor Cyan
    Write-Host "=====================" -ForegroundColor Cyan
    
    $lastSync = if ($manifest.lastSync) { [datetime]::Parse($manifest.lastSync).ToLocalTime().ToString() } else { "Never" }
    Write-Host "Last Sync: $lastSync"
    
    $syncedCount = 0
    $collections = @{}
    
    foreach ($key in $manifest.files.Keys) {
        $file = $manifest.files[$key]
        if ($file.status -eq "synced") {
            $syncedCount++
            $col = $file.collection
            if (-not $collections.ContainsKey($col)) { $collections[$col] = 0 }
            $collections[$col]++
        }
    }
    
    Write-Host "Total Files Indexed: $syncedCount"
    Write-Host "`nPer-Collection Counts:"
    foreach ($col in $collections.Keys) {
        Write-Host "  - $col: $($collections[$col])"
    }
}

function Search-Knowledge {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ProjectRoot,
        
        [Parameter(Mandatory=$true)]
        [string]$Query,
        
        [string]$Collection = "default",
        
        [int]$TopK = 5
    )
    
    $token = Get-OpenWebUIToken -ProjectRoot $ProjectRoot
    $manifest = Get-KnowledgeManifest -ProjectRoot $ProjectRoot
    
    $kbId = $null
    if ($manifest.collections.ContainsKey($Collection)) {
        $kbId = $manifest.collections[$Collection].webUIKnowledgeId
    }
    
    if (-not $kbId) {
        # Try fetching from WebUI directly
        try {
            $webuiKbs = Invoke-WebUIApi -Endpoint "/knowledge" -Method GET -Token $token
            $kb = $webuiKbs | Where-Object { $_.name -eq $Collection } | Select-Object -First 1
            if ($kb) { $kbId = $kb.id }
        } catch { }
    }
    
    if (-not $kbId) {
        throw "Collection '$Collection' not found."
    }
    
    $body = @{
        query = $Query
        knowledge_ids = @($kbId)
        top_k = $TopK
    }
    
    try {
        $results = Invoke-WebUIApi -Endpoint "/retrieval/query" -Method POST -Body $body -Token $token
        
        Write-Host "Search Results for '$Query' in '$Collection':" -ForegroundColor Cyan
        Write-Host "===============================================" -ForegroundColor Cyan
        
        foreach ($res in $results.documents) {
            Write-Host "Source: $($res.metadata.source)" -ForegroundColor Green
            Write-Host "Score: $($res.score)" -ForegroundColor DarkGray
            Write-Host "Excerpt:"
            Write-Host $res.page_content
            Write-Host "-----------------------------------------------"
        }
    } catch {
        Write-Error "Failed to search knowledge base: $_"
    }
}

function Get-KnowledgeSources {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ProjectRoot
    )
    
    $config = Get-KnowledgeSourcesConfig -ProjectRoot $ProjectRoot
    
    Write-Host "Knowledge Sources" -ForegroundColor Cyan
    Write-Host "=================" -ForegroundColor Cyan
    
    foreach ($source in $config.sources) {
        $status = "Inaccessible"
        $path = $source.path
        if (-not [System.IO.Path]::IsPathRooted($path)) {
            $path = Join-Path $ProjectRoot $path
        }
        
        if (Test-Path $path) {
            $status = "Accessible"
        }
        
        Write-Host "Path: $($source.path)"
        Write-Host "  Collection: $($source.collection)"
        Write-Host "  Recursive: $($source.recursive)"
        
        if ($status -eq "Accessible") {
            Write-Host "  Status: $status" -ForegroundColor Green
        } else {
            Write-Host "  Status: $status" -ForegroundColor Red
        }
        Write-Host ""
    }
}

Export-ModuleMember -Function Sync-KnowledgeBase, Add-KnowledgeSource, Remove-KnowledgeSource, Get-KnowledgeStatus, Search-Knowledge, Get-KnowledgeSources
