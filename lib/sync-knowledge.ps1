# ============================================================================
# LocalLLM Knowledge Sync — Read-Only Folder Ingestion for RAG
# Copyright (c) 2025-2026 Eugene Beauzec. All Rights Reserved.
#
# Scans specified read-only folders, uploads documents to Open WebUI,
# and organizes them into knowledge collections for RAG retrieval.
#
# USAGE:
#   .\lib\sync-knowledge.ps1                    # Sync all configured sources
#   .\lib\sync-knowledge.ps1 -AddSource "C:\Docs\ProjectX" -Name "Project X"
#   .\lib\sync-knowledge.ps1 -RemoveSource "Project X"
#   .\lib\sync-knowledge.ps1 -ListSources
#   .\lib\sync-knowledge.ps1 -Force              # Re-sync all files (ignore cache)
# ============================================================================

[CmdletBinding()]
param(
    [string]$AddSource,
    [string]$Name,
    [string]$RemoveSource,
    [switch]$ListSources,
    [switch]$Force,
    [string]$ConfigPath
)

$ErrorActionPreference = "Stop"

# ── Configuration ──────────────────────────────────────────────────────────
$DEFAULT_CONFIG = Join-Path $PSScriptRoot ".." "config" "knowledge-sources.json"
if (-not $ConfigPath) { $ConfigPath = $DEFAULT_CONFIG }

$WEBUI_URL = "http://localhost:3100"
$ADMIN_EMAIL = "admin@localllm.local"
$ADMIN_PASSWORD = "localllm-admin"

# Supported file extensions (Tika can handle all of these)
$SUPPORTED_EXTENSIONS = @(
    ".pdf", ".docx", ".doc", ".xlsx", ".xls", ".pptx", ".ppt",
    ".txt", ".md", ".csv", ".json", ".yaml", ".yml",
    ".html", ".htm", ".xml", ".rtf", ".odt", ".ods", ".odp",
    ".log", ".ini", ".cfg", ".conf", ".properties",
    ".py", ".js", ".ts", ".java", ".cs", ".go", ".rs", ".rb",
    ".sh", ".ps1", ".bat", ".cmd"
)

# Max file size (50MB)
$MAX_FILE_SIZE = 50 * 1024 * 1024

# ── Helper Functions ───────────────────────────────────────────────────────

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN"  { "Yellow" }
        "OK"    { "Green" }
        default { "Gray" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Get-AuthToken {
    try {
        $body = @{ email = $ADMIN_EMAIL; password = $ADMIN_PASSWORD } | ConvertTo-Json
        $resp = Invoke-RestMethod -Uri "$WEBUI_URL/api/v1/auths/signin" -Method Post -Body $body -ContentType "application/json"
        return $resp.token
    } catch {
        Write-Log "Failed to authenticate with Open WebUI: $_" "ERROR"
        throw
    }
}

function Get-Config {
    if (Test-Path $ConfigPath) {
        return Get-Content $ConfigPath -Raw | ConvertFrom-Json
    }
    return @{
        sources = @()
        sync_state = @{}
    }
}

function Save-Config {
    param($Config)
    $dir = Split-Path $ConfigPath -Parent
    if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
    $Config | ConvertTo-Json -Depth 10 | Set-Content $ConfigPath -Encoding UTF8
}

function Get-FileHash256 {
    param([string]$Path)
    $hash = Get-FileHash -Path $Path -Algorithm SHA256
    return $hash.Hash.ToLower()
}

# ── Source Management ──────────────────────────────────────────────────────

if ($ListSources) {
    $config = Get-Config
    if (-not $config.sources -or $config.sources.Count -eq 0) {
        Write-Host "`nNo knowledge sources configured.`n"
        Write-Host "Add a source:  .\lib\sync-knowledge.ps1 -AddSource 'C:\path\to\folder' -Name 'My Project'"
        exit 0
    }
    Write-Host "`n📚 Configured Knowledge Sources:`n"
    foreach ($src in $config.sources) {
        $status = if (Test-Path $src.path) { "✅ Accessible" } else { "❌ Not Found" }
        $fileCount = if ($config.sync_state.$($src.name)) { $config.sync_state.$($src.name).Count } else { 0 }
        Write-Host "  📁 $($src.name)"
        Write-Host "     Path: $($src.path)"
        Write-Host "     Status: $status"
        Write-Host "     Synced files: $fileCount"
        Write-Host ""
    }
    exit 0
}

if ($AddSource) {
    if (-not $Name) {
        $Name = Split-Path $AddSource -Leaf
    }
    if (-not (Test-Path $AddSource)) {
        Write-Log "Path does not exist: $AddSource" "ERROR"
        exit 1
    }
    $config = Get-Config
    if (-not $config.sources) { $config | Add-Member -NotePropertyName "sources" -NotePropertyValue @() -Force }
    
    # Check for duplicates
    $existing = $config.sources | Where-Object { $_.path -eq $AddSource -or $_.name -eq $Name }
    if ($existing) {
        Write-Log "Source already exists: $Name ($AddSource)" "WARN"
        exit 1
    }
    
    $config.sources += @{ name = $Name; path = $AddSource; added = (Get-Date -Format "o") }
    Save-Config $config
    Write-Log "Added knowledge source: $Name → $AddSource" "OK"
    exit 0
}

if ($RemoveSource) {
    $config = Get-Config
    $before = $config.sources.Count
    $config.sources = @($config.sources | Where-Object { $_.name -ne $RemoveSource })
    if ($config.sources.Count -eq $before) {
        Write-Log "Source not found: $RemoveSource" "WARN"
        exit 1
    }
    # Clean sync state
    if ($config.sync_state.$RemoveSource) {
        $config.sync_state.PSObject.Properties.Remove($RemoveSource)
    }
    Save-Config $config
    Write-Log "Removed knowledge source: $RemoveSource" "OK"
    exit 0
}

# ── Main Sync Logic ────────────────────────────────────────────────────────

Write-Log "Starting knowledge sync..."

$config = Get-Config
if (-not $config.sources -or $config.sources.Count -eq 0) {
    Write-Log "No knowledge sources configured. Use -AddSource to add one." "WARN"
    exit 0
}

# Authenticate
$token = Get-AuthToken
$headers = @{ "Authorization" = "Bearer $token" }
Write-Log "Authenticated with Open WebUI"

# Get existing knowledge collections
$existingKnowledge = @{}
try {
    $resp = Invoke-RestMethod -Uri "$WEBUI_URL/api/v1/knowledge/" -Headers $headers
    foreach ($k in $resp.items) {
        $existingKnowledge[$k.name] = $k.id
    }
} catch {
    Write-Log "Could not fetch knowledge collections: $_" "WARN"
}

# Initialize sync state if needed
if (-not $config.sync_state) {
    $config | Add-Member -NotePropertyName "sync_state" -NotePropertyValue @{} -Force
}

$totalUploaded = 0
$totalSkipped = 0
$totalErrors = 0

foreach ($source in $config.sources) {
    Write-Log "Processing source: $($source.name) → $($source.path)"
    
    if (-not (Test-Path $source.path)) {
        Write-Log "  Path not accessible: $($source.path)" "ERROR"
        $totalErrors++
        continue
    }

    # Create or get knowledge collection
    $collectionName = "📁 $($source.name)"
    $collectionId = $existingKnowledge[$collectionName]
    
    if (-not $collectionId) {
        Write-Log "  Creating knowledge collection: $collectionName"
        try {
            $payload = @{
                name = $collectionName
                description = "Auto-synced from: $($source.path)"
                data = @{ source_path = $source.path; source_name = $source.name }
            } | ConvertTo-Json -Depth 5
            $collection = Invoke-RestMethod -Uri "$WEBUI_URL/api/v1/knowledge/create" -Method Post -Headers $headers -Body $payload -ContentType "application/json"
            $collectionId = $collection.id
            Write-Log "  Created collection: $collectionId" "OK"
        } catch {
            Write-Log "  Failed to create collection: $_" "ERROR"
            $totalErrors++
            continue
        }
    } else {
        Write-Log "  Using existing collection: $collectionId"
    }

    # Get sync state for this source
    $syncState = @{}
    if ($config.sync_state.$($source.name)) {
        $syncState = $config.sync_state.$($source.name)
        if ($syncState -is [PSCustomObject]) {
            $temp = @{}
            $syncState.PSObject.Properties | ForEach-Object { $temp[$_.Name] = $_.Value }
            $syncState = $temp
        }
    }

    # Scan folder (read-only — never write to source folders!)
    $files = Get-ChildItem -Path $source.path -Recurse -File -ErrorAction SilentlyContinue | 
        Where-Object { $_.Extension.ToLower() -in $SUPPORTED_EXTENSIONS -and $_.Length -le $MAX_FILE_SIZE }
    
    Write-Log "  Found $($files.Count) supported files"

    foreach ($file in $files) {
        $relativePath = $file.FullName.Substring($source.path.Length).TrimStart('\', '/')
        $fileHash = Get-FileHash256 -Path $file.FullName

        # Skip if already synced and hash matches (unless -Force)
        if (-not $Force -and $syncState[$relativePath] -eq $fileHash) {
            $totalSkipped++
            continue
        }

        Write-Log "  Uploading: $relativePath ($([math]::Round($file.Length/1024, 1)) KB)"

        try {
            # Upload file to Open WebUI
            $boundary = [System.Guid]::NewGuid().ToString()
            $fileBytes = [System.IO.File]::ReadAllBytes($file.FullName)
            $fileB64 = [Convert]::ToBase64String($fileBytes)
            
            # Use multipart form upload
            $form = @{
                file = Get-Item $file.FullName
            }
            
            $uploadResp = Invoke-RestMethod -Uri "$WEBUI_URL/api/v1/files/" -Method Post -Headers $headers -Form $form
            $fileId = $uploadResp.id
            
            if ($fileId) {
                # Add file to knowledge collection
                $addPayload = @{ file_id = $fileId } | ConvertTo-Json
                Invoke-RestMethod -Uri "$WEBUI_URL/api/v1/knowledge/$collectionId/file/add" -Method Post -Headers $headers -Body $addPayload -ContentType "application/json" | Out-Null
                
                # Update sync state
                $syncState[$relativePath] = $fileHash
                $totalUploaded++
                Write-Log "    ✅ Uploaded and added to collection" "OK"
            }
        } catch {
            Write-Log "    ❌ Failed: $_" "ERROR"
            $totalErrors++
        }
    }

    # Save sync state
    $config.sync_state | Add-Member -NotePropertyName $source.name -NotePropertyValue $syncState -Force
}

# Save updated config with sync state
Save-Config $config

Write-Log "════════════════════════════════════════════════════════"
Write-Log "Knowledge sync complete!"
Write-Log "  Uploaded: $totalUploaded files"
Write-Log "  Skipped:  $totalSkipped files (unchanged)"
Write-Log "  Errors:   $totalErrors"
Write-Log "════════════════════════════════════════════════════════"
