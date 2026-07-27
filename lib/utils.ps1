<#
.SYNOPSIS
    Shared utility module for LocalLLM.
.DESCRIPTION
    Provides common functions for logging, UI, path management, and system tasks.
.COPYRIGHT
    (c) 2025-2026 Eugene Beauzec. All Rights Reserved.
    Project: LocalLLM - Self-Contained Local AI Platform
#>
#Requires -Version 5.1

# ── Path functions (must be defined before use) ──
function Get-LocalLLMPath {
    <#
    .SYNOPSIS
        Gets the installation root path.
    #>
    [CmdletBinding()]
    param ()
    return (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

function Get-ConfigPath {
    <#
    .SYNOPSIS
        Gets the config directory path.
    #>
    [CmdletBinding()]
    param ()
    return Join-Path (Get-LocalLLMPath) "config"
}

function Get-DataPath {
    <#
    .SYNOPSIS
        Gets the data directory path.
    #>
    [CmdletBinding()]
    param ()
    return Join-Path (Get-LocalLLMPath) "data"
}

# ── Log file setup ──
$logDir = Join-Path (Get-LocalLLMPath) "logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$global:LogFilePath = Join-Path $logDir "localllm.log"

function Write-LogMessage {
    <#
    .SYNOPSIS
        Logs a message with timestamps to console and log file.
    .PARAMETER Message
        The message to log.
    .PARAMETER Level
        The severity level: Info, Success, Warning, Error, Step.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error', 'Step')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Ensure log directory exists
    $logDir = Split-Path $global:LogFilePath
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    
    # Write to file
    Add-Content -Path $global:LogFilePath -Value $logEntry -ErrorAction SilentlyContinue
    
    # Write to console with color
    switch ($Level) {
        'Info'    { Write-Host $logEntry -ForegroundColor Cyan }
        'Success' { Write-Host $logEntry -ForegroundColor Green }
        'Warning' { Write-Host $logEntry -ForegroundColor Yellow }
        'Error'   { Write-Host $logEntry -ForegroundColor Red }
        'Step'    { Write-Host $logEntry -ForegroundColor Magenta }
    }
}

function Write-Banner {
    <#
    .SYNOPSIS
        Displays the LocalLLM ASCII art banner.
    #>
    [CmdletBinding()]
    param ()
    
    $banner = @"
  _                     _  _    _    __  __ 
 | |                   | || |  | |  |  \/  |
 | |      ___  ___ __ _| || |  | |  | \  / |
 | |     / _ \/ __/ _` | || |  | |  | |\/| |
 | |____| (_) | (_| (_| | || |__| |__| |  | |
 |______|\___/ \___\__,_|_||_____\____/_|  |_|
                                            
"@
    Write-Host $banner -ForegroundColor Cyan
}

function Write-Section {
    <#
    .SYNOPSIS
        Displays a section header.
    .PARAMETER Title
        The section title.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Title
    )
    $line = "=" * 50
    Write-Host "`n$line" -ForegroundColor Cyan
    Write-Host " $Title " -ForegroundColor White -BackgroundColor DarkCyan
    Write-Host "$line`n" -ForegroundColor Cyan
    Write-LogMessage -Message "SECTION: $Title" -Level Info
}

function Write-ProgressStep {
    <#
    .SYNOPSIS
        Displays a progress step.
    .PARAMETER Step
        The step description (e.g. 'Step 3/7: Installing Docker...').
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Step
    )
    Write-LogMessage -Message $Step -Level Step
}

function Test-Administrator {
    <#
    .SYNOPSIS
        Checks if running as admin.
    #>
    [CmdletBinding()]
    param ()
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Request-Administrator {
    <#
    .SYNOPSIS
        Restarts the script as admin if not already running as admin.
    #>
    [CmdletBinding()]
    param ()
    if (-not (Test-Administrator)) {
        Write-LogMessage "Requesting Administrator privileges..." -Level Warning
        $args = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        Start-Process pwsh -ArgumentList $args -Verb RunAs
        Exit
    }
}


function ConvertTo-HumanReadableSize {
    <#
    .SYNOPSIS
        Converts bytes to human-readable size.
    .PARAMETER Bytes
        The size in bytes.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [long]$Bytes
    )
    $units = "B", "KB", "MB", "GB", "TB", "PB"
    $index = 0
    $size = $Bytes
    while ($size -ge 1024 -and $index -lt ($units.Length - 1)) {
        $size /= 1024
        $index++
    }
    return "{0:N2} {1}" -f $size, $units[$index]
}

function Invoke-WithRetry {
    <#
    .SYNOPSIS
        Executes a script block with retry logic.
    .PARAMETER ScriptBlock
        The block to execute.
    .PARAMETER MaxRetries
        Maximum number of retries.
    .PARAMETER DelaySeconds
        Delay between retries.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [scriptblock]$ScriptBlock,
        [int]$MaxRetries = 3,
        [int]$DelaySeconds = 5
    )
    $attempt = 0
    while ($attempt -lt $MaxRetries) {
        try {
            return & $ScriptBlock
        } catch {
            $attempt++
            Write-LogMessage "Attempt $attempt failed: $_" -Level Warning
            if ($attempt -lt $MaxRetries) {
                Start-Sleep -Seconds $DelaySeconds
            } else {
                Write-LogMessage "Max retries reached." -Level Error
                throw $_
            }
        }
    }
}

function Test-PortAvailable {
    <#
    .SYNOPSIS
        Checks if a TCP port is available.
    .PARAMETER Port
        The port number to check.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [int]$Port
    )
    $tcpConnections = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
    return $null -eq $tcpConnections
}

function Wait-ForEndpoint {
    <#
    .SYNOPSIS
        Waits for an HTTP endpoint to respond.
    .PARAMETER Url
        The URL to check.
    .PARAMETER TimeoutSeconds
        Timeout in seconds.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Url,
        [int]$TimeoutSeconds = 30
    )
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    while ($stopwatch.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
        try {
            $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -Method Head -ErrorAction Stop
            if ($response.StatusCode -eq 200) {
                return $true
            }
        } catch {
            # Ignore and retry
        }
        Start-Sleep -Seconds 2
    }
    return $false
}

function Show-CompletionBox {
    <#
    .SYNOPSIS
        Displays a bordered completion message box.
    .PARAMETER Message
        The completion message.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    $border = "*" * ($Message.Length + 4)
    Write-Host "`n$border" -ForegroundColor Green
    Write-Host "* $Message *" -ForegroundColor Green
    Write-Host "$border`n" -ForegroundColor Green
    Write-LogMessage -Message "COMPLETED: $Message" -Level Success
}
Export-ModuleMember -Function *
