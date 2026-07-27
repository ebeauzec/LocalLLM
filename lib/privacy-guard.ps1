<#
.SYNOPSIS
    Data Privacy Guard system for LocalLLM.

.DESCRIPTION
    This module implements a DATA PRIVACY GUARD system that prevents sensitive 
    corporate and personal data from being sent to external/cloud LLMs. 
    It ensures local-first processing and only uses cloud APIs as a last resort.

    Copyright: (c) 2025-2026 Eugene Beauzec. All Rights Reserved.
    Project: LocalLLM - Self-Contained Local AI Platform
#>
#Requires -Version 5.1

# Module Scoped Variables for Paths
$script:LocalLlmRoot = (Get-Item $PSScriptRoot).Parent.FullName
$script:ConfigDir = Join-Path $script:LocalLlmRoot "config"
$script:DataDir = Join-Path $script:LocalLlmRoot "data"
$script:PrivacyConfigFile = Join-Path $script:ConfigDir "privacy-config.json"
$script:PrivacyBlocklistFile = Join-Path $script:ConfigDir "privacy-blocklist.txt"
$script:PrivacyAuditFile = Join-Path $script:DataDir "privacy-audit.json"

# Default configuration
$script:DefaultConfig = @{
    PrivacyMode = 'BALANCED'
}

function Initialize-PrivacyGuard {
    <#
    .SYNOPSIS
        Initializes the privacy guard directories and files.
    #>
    if (-not (Test-Path $script:ConfigDir)) { New-Item -ItemType Directory -Path $script:ConfigDir -Force | Out-Null }
    if (-not (Test-Path $script:DataDir)) { New-Item -ItemType Directory -Path $script:DataDir -Force | Out-Null }
    
    if (-not (Test-Path $script:PrivacyConfigFile)) {
        $script:DefaultConfig | ConvertTo-Json | Set-Content -Path $script:PrivacyConfigFile -Encoding UTF8
    }
    
    if (-not (Test-Path $script:PrivacyBlocklistFile)) {
        "# Add custom sensitive patterns here (one per line)`n" | Set-Content -Path $script:PrivacyBlocklistFile -Encoding UTF8
    }

    if (-not (Test-Path $script:PrivacyAuditFile)) {
        $initialAudit = @{
            TotalRequests = 0
            LocalRequests = 0
            CloudRequests = 0
            TokensSaved = 0
            CostSaved = 0
            Detections = @{}
            BlockedDataEvents = 0
        }
        $initialAudit | ConvertTo-Json | Set-Content -Path $script:PrivacyAuditFile -Encoding UTF8
    }
}

function Get-PrivacyMode {
    <#
    .SYNOPSIS
        Returns the current privacy mode from config.
    .DESCRIPTION
        Retrieves the configured privacy mode (STRICT, BALANCED, PERMISSIVE).
    .EXAMPLE
        $mode = Get-PrivacyMode
    #>
    Initialize-PrivacyGuard
    try {
        $config = Get-Content $script:PrivacyConfigFile -Raw | ConvertFrom-Json
        return $config.PrivacyMode
    } catch {
        Write-LogMessage -Message "Failed to read privacy config, falling back to BALANCED" -Level "Warning"
        return "BALANCED"
    }
}

function Set-PrivacyMode {
    <#
    .SYNOPSIS
        Sets the privacy mode.
    .DESCRIPTION
        Saves the new privacy mode to the configuration file.
    .PARAMETER Mode
        The privacy mode to set. Must be STRICT, BALANCED, or PERMISSIVE.
    .EXAMPLE
        Set-PrivacyMode -Mode 'STRICT'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('STRICT', 'BALANCED', 'PERMISSIVE')]
        [string]$Mode
    )
    
    Initialize-PrivacyGuard
    try {
        $config = Get-Content $script:PrivacyConfigFile -Raw | ConvertFrom-Json
        if ($null -eq $config) { $config = @{} }
        $config.PrivacyMode = $Mode
        $config | ConvertTo-Json | Set-Content -Path $script:PrivacyConfigFile -Encoding UTF8
        Write-LogMessage -Message "Privacy mode set to $Mode" -Level "Info"
        Write-Host "Privacy mode successfully set to $Mode" -ForegroundColor Green
    } catch {
        Write-LogMessage -Message "Failed to set privacy mode: $_" -Level "Error"
        throw
    }
}

function Test-SensitiveContent {
    <#
    .SYNOPSIS
        Scans text content for sensitive data patterns.
    .DESCRIPTION
        Checks the input text against common sensitive data patterns and custom blocklist.
        Returns an object with detection details.
    .PARAMETER Content
        The text to scan.
    .EXAMPLE
        $result = Test-SensitiveContent -Content "My SSN is 123-45-6789"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Content
    )
    
    Initialize-PrivacyGuard
    
    $detections = @()
    $riskLevel = 'LOW'
    
    $patterns = @{
        'CREDIT_CARD' = '(?:\d[ -]*?){13,16}' # Simple generic CC regex
        'SSN' = '\b\d{3}-\d{2}-\d{4}\b'
        'EMAIL' = '\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'
        'PHONE' = '\b(?:\+\d{1,2}\s)?\(?\d{3}\)?[\s.-]\d{3}[\s.-]\d{4}\b'
        'API_KEY' = '\b(?:sk-[a-zA-Z0-9]{32,}|ghp_[a-zA-Z0-9]{36}|AKIA[0-9A-Z]{16})\b'
        'PRIVATE_KEY' = '-----BEGIN (?:RSA )?PRIVATE KEY-----'
        'PASSWORD' = '(?i)(?:password|passwd|pwd)\s*[=:]\s*[^\s]+'
        'INTERNAL_IP' = '\b(?:10\.\d{1,3}\.\d{1,3}\.\d{1,3}|192\.168\.\d{1,3}\.\d{1,3}|172\.(?:1[6-9]|2\d|3[0-1])\.\d{1,3}\.\d{1,3})\b'
        'DB_CONNECTION' = '(?i)(?:Server=|mongodb://|postgres://)'
        'INTERNAL_PATH' = '(?i)(?:\\\\server\\share|C:\\Users\\[^\s]+)'
    }
    
    # Check built-in patterns
    foreach ($key in $patterns.Keys) {
        $regex = $patterns[$key]
        $matches = [regex]::Matches($Content, $regex)
        foreach ($m in $matches) {
            $detections += [pscustomobject]@{
                Type = $key
                Match = $m.Value
                Index = $m.Index
                Length = $m.Length
                Confidence = 'HIGH'
            }
        }
    }
    
    # Check custom blocklist
    if (Test-Path $script:PrivacyBlocklistFile) {
        $customPatterns = Get-Content $script:PrivacyBlocklistFile | Where-Object { $_ -notmatch '^\s*#' -and $_.Trim() -ne '' }
        foreach ($cp in $customPatterns) {
            $escaped = [regex]::Escape($cp.Trim())
            $matches = [regex]::Matches($Content, "(?i)\b$escaped\b")
            foreach ($m in $matches) {
                $detections += [pscustomobject]@{
                    Type = 'CUSTOM_BLOCKLIST'
                    Match = $m.Value
                    Index = $m.Index
                    Length = $m.Length
                    Confidence = 'HIGH'
                }
            }
        }
    }
    
    # Determine Risk
    if ($detections.Count -gt 0) {
        $criticalTypes = @('PRIVATE_KEY', 'API_KEY', 'CREDIT_CARD', 'SSN', 'PASSWORD')
        $mediumTypes = @('DB_CONNECTION', 'INTERNAL_PATH', 'INTERNAL_IP')
        
        $riskLevel = 'LOW'
        foreach ($d in $detections) {
            if ($d.Type -in $criticalTypes) {
                $riskLevel = 'CRITICAL'
                break
            } elseif ($d.Type -in $mediumTypes -and $riskLevel -ne 'CRITICAL') {
                $riskLevel = 'MEDIUM'
            } elseif ($riskLevel -eq 'LOW') {
                $riskLevel = 'LOW'
            }
        }
    }
    
    return [pscustomobject]@{
        ContainsSensitiveData = ($detections.Count -gt 0)
        Detections = $detections
        RiskLevel = $riskLevel
    }
}

function New-RedactedContent {
    <#
    .SYNOPSIS
        Redacts sensitive data from content based on detections.
    .DESCRIPTION
        Takes content and an array of detections, returns the content with all sensitive data 
        replaced with [REDACTED_TYPE] placeholders.
    .PARAMETER Content
        The original text content.
    .PARAMETER Detections
        Array of detection objects from Test-SensitiveContent.
    .EXAMPLE
        $redacted = New-RedactedContent -Content "SSN is 123-45-6789" -Detections $dets
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Content,
        
        [Parameter(Mandatory=$true)]
        [array]$Detections
    )
    
    if (-not $Detections -or $Detections.Count -eq 0) {
        return $Content
    }
    
    # Sort descending by index so string manipulation doesn't offset subsequent replacements
    $sorted = $Detections | Sort-Object Index -Descending
    
    $redacted = $Content
    foreach ($d in $sorted) {
        $placeholder = "[REDACTED_$($d.Type)]"
        $redacted = $redacted.Remove($d.Index, $d.Length).Insert($d.Index, $placeholder)
    }
    
    return $redacted
}

function Invoke-PrivacyCheck {
    <#
    .SYNOPSIS
        Master function that checks content against privacy mode.
    .DESCRIPTION
        Evaluates content based on current PrivacyMode. Can block, prompt, or auto-redact.
    .PARAMETER Content
        The text content to check before sending.
    .PARAMETER IsCloudRequest
        Boolean indicating if the request is bound for the cloud.
    .EXAMPLE
        $result = Invoke-PrivacyCheck -Content "Prompt text" -IsCloudRequest $true
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Content,
        
        [Parameter(Mandatory=$false)]
        [switch]$IsCloudRequest
    )
    
    $mode = Get-PrivacyMode
    $scan = Test-SensitiveContent -Content $Content
    
    $result = @{
        Allowed = $true
        Mode = $mode
        Detections = $scan.Detections
        RedactedContent = $Content
        UserConfirmed = $false
        RoutingAdvice = 'LOCAL_PREFERRED'
    }
    
    # Update audit tracking logic helper
    $updateAudit = {
        param($type, $dets)
        $audit = Get-Content $script:PrivacyAuditFile -Raw | ConvertFrom-Json
        $audit.TotalRequests++
        if ($type -eq 'LOCAL') { $audit.LocalRequests++ }
        if ($type -eq 'CLOUD') { $audit.CloudRequests++ }
        if ($type -eq 'BLOCKED') { $audit.BlockedDataEvents++ }
        
        if ($dets) {
            foreach ($d in $dets) {
                $dt = $d.Type
                if (-not $audit.Detections.$dt) { $audit.Detections | Add-Member -NotePropertyName $dt -NotePropertyValue 0 }
                $audit.Detections.$dt++
            }
        }
        $audit | ConvertTo-Json -Depth 5 | Set-Content -Path $script:PrivacyAuditFile -Encoding UTF8
    }
    
    if (-not $IsCloudRequest) {
        # Local requests are always allowed
        $result.RoutingAdvice = 'LOCAL_ONLY'
        &$updateAudit 'LOCAL' $null
        return [pscustomobject]$result
    }
    
    if ($mode -eq 'STRICT') {
        Write-LogMessage -Message "PrivacyGuard: Blocked cloud request in STRICT mode." -Level "Warning"
        $result.Allowed = $false
        $result.RoutingAdvice = 'LOCAL_ONLY'
        &$updateAudit 'BLOCKED' $scan.Detections
        return [pscustomobject]$result
    }
    
    if ($scan.ContainsSensitiveData) {
        $result.RedactedContent = New-RedactedContent -Content $Content -Detections $scan.Detections
        
        if ($mode -eq 'BALANCED') {
            Write-Host "`n[PRIVACY GUARD WARNING]" -ForegroundColor Yellow
            Write-Host "Sensitive data detected in content bound for Cloud API:" -ForegroundColor Yellow
            foreach ($d in $scan.Detections) {
                Write-Host " - Type: $($d.Type) | Confidence: $($d.Confidence)" -ForegroundColor Red
            }
            Write-Host "Risk Level: $($scan.RiskLevel)" -ForegroundColor Red
            
            $choice = Read-Host "Do you want to send REDACTED content to cloud? (Y/N)"
            if ($choice -match "^[yY]") {
                $result.UserConfirmed = $true
                $result.RoutingAdvice = 'CLOUD_ALLOWED'
                Write-LogMessage -Message "PrivacyGuard: User approved sending redacted content to cloud." -Level "Info"
                &$updateAudit 'CLOUD' $scan.Detections
            } else {
                $result.Allowed = $false
                $result.RoutingAdvice = 'LOCAL_ONLY'
                Write-LogMessage -Message "PrivacyGuard: User denied cloud send." -Level "Info"
                &$updateAudit 'BLOCKED' $scan.Detections
            }
        } elseif ($mode -eq 'PERMISSIVE') {
            Write-LogMessage -Message "PrivacyGuard: Auto-redacting sensitive content in PERMISSIVE mode before cloud send." -Level "Info"
            $result.RoutingAdvice = 'CLOUD_ALLOWED'
            &$updateAudit 'CLOUD' $scan.Detections
        }
    } else {
        $result.RoutingAdvice = 'CLOUD_ALLOWED'
        &$updateAudit 'CLOUD' $null
    }
    
    return [pscustomobject]$result
}

function Get-PrivacyReport {
    <#
    .SYNOPSIS
        Generates a summary report of privacy actions.
    .DESCRIPTION
        Reads the audit file and returns the statistics.
    .EXAMPLE
        Get-PrivacyReport
    #>
    Initialize-PrivacyGuard
    if (Test-Path $script:PrivacyAuditFile) {
        $audit = Get-Content $script:PrivacyAuditFile -Raw | ConvertFrom-Json
        return $audit
    }
    return $null
}

function Update-PrivacyBlocklist {
    <#
    .SYNOPSIS
        Allows users to add custom sensitive patterns to the blocklist.
    .DESCRIPTION
        Appends new patterns to the custom blocklist file.
    .PARAMETER Pattern
        The custom sensitive pattern or keyword to block.
    .EXAMPLE
        Update-PrivacyBlocklist -Pattern "ProjectX"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Pattern
    )
    
    Initialize-PrivacyGuard
    try {
        Add-Content -Path $script:PrivacyBlocklistFile -Value $Pattern -Encoding UTF8
        Write-LogMessage -Message "Added pattern to privacy blocklist: $Pattern" -Level "Info"
        Write-Host "Successfully added pattern to privacy blocklist." -ForegroundColor Green
    } catch {
        Write-LogMessage -Message "Failed to update privacy blocklist: $_" -Level "Error"
        throw
    }
}

function Show-PrivacyStatus {
    <#
    .SYNOPSIS
        Displays current privacy settings, mode, blocklist status, and audit summary.
    .DESCRIPTION
        Formats and prints a comprehensive view of the Privacy Guard status to the console.
    .EXAMPLE
        Show-PrivacyStatus
    #>
    Initialize-PrivacyGuard
    $mode = Get-PrivacyMode
    $audit = Get-PrivacyReport
    
    $blocklistCount = 0
    if (Test-Path $script:PrivacyBlocklistFile) {
        $blocklistCount = @(Get-Content $script:PrivacyBlocklistFile | Where-Object { $_ -notmatch '^\s*#' -and $_.Trim() -ne '' }).Count
    }
    
    Write-Host "`n===============================================" -ForegroundColor Cyan
    Write-Host "         LocalLLM Data Privacy Guard           " -ForegroundColor White
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host "Current Mode   : " -NoNewline; Write-Host $mode -ForegroundColor Yellow
    Write-Host "Blocklist Rules: $blocklistCount custom rules loaded"
    
    if ($audit) {
        Write-Host "`n--- Audit Summary ---" -ForegroundColor Cyan
        Write-Host "Total Requests Processed : $($audit.TotalRequests)"
        Write-Host "Local-Only Processing    : $($audit.LocalRequests)" -ForegroundColor Green
        Write-Host "Cloud Requests Allowed   : $($audit.CloudRequests)" -ForegroundColor Yellow
        Write-Host "Cloud Requests Blocked   : $($audit.BlockedDataEvents)" -ForegroundColor Red
        Write-Host "Estimated Tokens Saved   : $($audit.TokensSaved)"
        Write-Host "Estimated Cost Saved     : `$ $($audit.CostSaved)"
        
        if ($audit.Detections -and $audit.Detections.PSObject.Properties.Count -gt 0) {
            Write-Host "`n--- Sensitive Detections ---" -ForegroundColor Cyan
            foreach ($prop in $audit.Detections.PSObject.Properties) {
                Write-Host "$($prop.Name): $($prop.Value)" -ForegroundColor Magenta
            }
        }
    }
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host ""
}
