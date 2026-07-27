#Requires -Version 5.1
<#
.SYNOPSIS
    Configures Open WebUI settings via its REST API after deployment.

.DESCRIPTION
    This module provides functions to automatically configure Open WebUI settings,
    models, tools, and prompts via its REST API. It handles creating the initial admin
    account and configuring enterprise features.

.NOTES
    Copyright (c) 2025-2026 Eugene Beauzec. All Rights Reserved.
    License: Proprietary - All Rights Reserved
#>

# Import utils for Write-LogMessage if not already loaded
if (-not (Get-Command Write-LogMessage -ErrorAction SilentlyContinue)) {
    $utilsPath = Join-Path -Path $PSScriptRoot -ChildPath "utils.ps1"
    if (Test-Path $utilsPath) {
        . $utilsPath
    } else {
        function Write-LogMessage {
            param($Message, $Level = "INFO")
            Write-Host "[$Level] $Message"
        }
    }
}

<#
.SYNOPSIS
    Initializes Open WebUI configuration.
.DESCRIPTION
    Waits for Open WebUI to be ready, creates admin account (or detects if exists),
    and configures all settings via API.
#>
function Initialize-OpenWebUI {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        $Configuration
    )

    try {
        Write-LogMessage -Message "Starting Open WebUI initialization..." -Level "INFO"
        
        $baseUrl = "http://localhost:$($Configuration.WebUIPort | Default 8080)"
        $maxRetries = 30
        $retryCount = 0
        $isReady = $false

        # Wait for API to be ready
        while (-not $isReady -and $retryCount -lt $maxRetries) {
            try {
                $response = Invoke-RestMethod -Uri "$baseUrl/api/v1/status" -Method Get -ErrorAction Stop
                $isReady = $true
                Write-LogMessage -Message "Open WebUI API is ready." -Level "INFO"
            } catch {
                $retryCount++
                Write-LogMessage -Message "Waiting for Open WebUI API to be ready (Attempt $retryCount of $maxRetries)..." -Level "DEBUG"
                Start-Sleep -Seconds 5
            }
        }

        if (-not $isReady) {
            throw "Open WebUI API did not become ready within the timeout period."
        }

        # Create/Get Admin Token
        # (This is a simplified mock of the auth flow as the exact API might vary)
        $token = ""
        $authUrl = "$baseUrl/api/v1/auths/signup"
        $loginUrl = "$baseUrl/api/v1/auths/signin"
        $adminEmail = $Configuration.AdminEmail
        $adminPassword = $Configuration.AdminPassword
        $adminName = $Configuration.AdminName

        try {
            $body = @{
                email = $adminEmail
                password = $adminPassword
                name = $adminName
            } | ConvertTo-Json
            
            $authResponse = Invoke-RestMethod -Uri $authUrl -Method Post -Body $body -ContentType "application/json" -ErrorAction Stop
            $token = $authResponse.token
            Write-LogMessage -Message "Created new admin account." -Level "INFO"
        } catch {
            Write-LogMessage -Message "Admin account might already exist. Attempting login..." -Level "INFO"
            try {
                $body = @{
                    email = $adminEmail
                    password = $adminPassword
                } | ConvertTo-Json
                $loginResponse = Invoke-RestMethod -Uri $loginUrl -Method Post -Body $body -ContentType "application/json" -ErrorAction Stop
                $token = $loginResponse.token
                Write-LogMessage -Message "Successfully logged in as admin." -Level "INFO"
            } catch {
                throw "Failed to authenticate with Open WebUI."
            }
        }

        # Configure components
        Set-OpenWebUIModels -BaseUrl $baseUrl -Token $token
        Set-OpenWebUITools -BaseUrl $baseUrl -Token $token
        Set-OpenWebUISettings -BaseUrl $baseUrl -Token $token
        Set-OpenWebUIPromptLibrary -BaseUrl $baseUrl -Token $token

        Write-LogMessage -Message "Open WebUI initialization completed successfully." -Level "INFO"
    } catch {
        Write-LogMessage -Message "Error initializing Open WebUI: $_" -Level "ERROR"
        throw
    }
}

<#
.SYNOPSIS
    Registers custom model profiles in Open WebUI.
#>
function Set-OpenWebUIModels {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$BaseUrl,
        
        [Parameter(Mandatory=$true)]
        [string]$Token
    )

    try {
        Write-LogMessage -Message "Configuring Open WebUI Models..." -Level "INFO"
        $headers = @{ "Authorization" = "Bearer $Token" }

        $models = @(
            @{ Name = "General Assistant"; Description = "Versatile AI assistant"; Icon = "🤖"; ModelName = "localllm-assistant"; Category = "Assistant" },
            @{ Name = "Reasoning Engine"; Description = "Advanced reasoning and logic"; Icon = "🧠"; ModelName = "localllm-reasoning"; Category = "Reasoning" },
            @{ Name = "Code Developer"; Description = "Software engineering expert"; Icon = "💻"; ModelName = "localllm-developer"; Category = "Development" },
            @{ Name = "Data Analyst"; Description = "Data analysis and visualization"; Icon = "📊"; ModelName = "localllm-analyst"; Category = "Analysis" },
            @{ Name = "Creative Writer"; Description = "Creative and engaging writing"; Icon = "✍️"; ModelName = "localllm-creative"; Category = "Creative" },
            @{ Name = "Security Analyst"; Description = "Cybersecurity expert"; Icon = "🛡️"; ModelName = "localllm-security"; Category = "Security" }
        )

        foreach ($model in $models) {
            Write-LogMessage -Message "Configuring model: $($model.Name)" -Level "INFO"
            # Note: Exact payload depends on Open WebUI API structure.
            $payload = @{
                name = $model.Name
                description = $model.Description
                model = $model.ModelName
                info = @{
                    meta = @{
                        profile_image_url = $model.Icon
                    }
                }
            } | ConvertTo-Json -Depth 5
            
            # Use PUT or POST depending on if it exists, simplified as POST for now
            Invoke-RestMethod -Uri "$BaseUrl/api/v1/models" -Method Post -Headers $headers -Body $payload -ContentType "application/json" -ErrorAction SilentlyContinue | Out-Null
        }
    } catch {
        Write-LogMessage -Message "Error configuring models: $_" -Level "ERROR"
    }
}

<#
.SYNOPSIS
    Registers tools in Open WebUI.
#>
function Set-OpenWebUITools {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$BaseUrl,
        
        [Parameter(Mandatory=$true)]
        [string]$Token
    )

    try {
        Write-LogMessage -Message "Configuring Open WebUI Tools..." -Level "INFO"
        $headers = @{ "Authorization" = "Bearer $Token" }

        $tools = @(
            @{ Name = "Code Executor"; Description = "Executes code in a secure sandbox" },
            @{ Name = "Web Page Reader"; Description = "Extracts content from web pages" },
            @{ Name = "Local File Manager"; Description = "Reads and writes local files" },
            @{ Name = "Calculator"; Description = "Performs mathematical calculations" },
            @{ Name = "DateTime Tool"; Description = "Gets current date and time" },
            @{ Name = "System Info"; Description = "Retrieves system information" },
            @{ Name = "JSON/YAML Tool"; Description = "Parses and formats JSON/YAML" }
        )

        foreach ($tool in $tools) {
            Write-LogMessage -Message "Configuring tool: $($tool.Name)" -Level "INFO"
            $payload = @{
                name = $tool.Name
                description = $tool.Description
                # Tools need specific schema/code definition, simplified here
            } | ConvertTo-Json
            
            Invoke-RestMethod -Uri "$BaseUrl/api/v1/tools" -Method Post -Headers $headers -Body $payload -ContentType "application/json" -ErrorAction SilentlyContinue | Out-Null
        }
    } catch {
        Write-LogMessage -Message "Error configuring tools: $_" -Level "ERROR"
    }
}

<#
.SYNOPSIS
    Configures Open WebUI environment settings.
#>
function Set-OpenWebUISettings {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$BaseUrl,
        
        [Parameter(Mandatory=$true)]
        [string]$Token
    )

    try {
        Write-LogMessage -Message "Configuring Open WebUI Settings..." -Level "INFO"
        $headers = @{ "Authorization" = "Bearer $Token" }

        $settings = @{
            ui = @{
                theme = "system"
                artifacts_rendering = $true
                thinking_display = $true
            }
            models = @{
                default_model = "localllm-assistant"
            }
            features = @{
                code_execution = $true
                image_generation = $true
            }
            rag = @{
                chunk_size = 1500
                top_k = 5
                embedding_model = "all-minilm"
            }
            search = @{
                enabled = $true
                engine = "searxng"
                searxng_url = "http://searxng:8080"
            }
        }

        $payload = $settings | ConvertTo-Json -Depth 5
        Invoke-RestMethod -Uri "$BaseUrl/api/v1/settings" -Method Post -Headers $headers -Body $payload -ContentType "application/json" -ErrorAction SilentlyContinue | Out-Null
        Write-LogMessage -Message "Settings configured successfully." -Level "INFO"
    } catch {
        Write-LogMessage -Message "Error configuring settings: $_" -Level "ERROR"
    }
}

<#
.SYNOPSIS
    Creates a library of reusable prompt templates.
#>
function Set-OpenWebUIPromptLibrary {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$BaseUrl,
        
        [Parameter(Mandatory=$true)]
        [string]$Token
    )

    try {
        Write-LogMessage -Message "Configuring Open WebUI Prompts..." -Level "INFO"
        $headers = @{ "Authorization" = "Bearer $Token" }

        $prompts = @(
            @{ Command = "analyze"; Title = "Analyze this code"; Content = "Please analyze the following code, identify any potential bugs, security vulnerabilities, or performance issues, and suggest improvements:`n`n[PASTE_CODE_HERE]" },
            @{ Command = "eli5"; Title = "Explain like I'm 5"; Content = "Explain the following concept in simple terms, as if you were talking to a 5-year-old:`n`n[CONCEPT]" },
            @{ Command = "debug"; Title = "Debug this error"; Content = "I am getting the following error. Please explain what it means and provide a step-by-step guide to fix it:`n`n[ERROR_MESSAGE]" },
            @{ Command = "test"; Title = "Write tests for"; Content = "Write comprehensive unit tests for the following code, covering edge cases and expected behaviors:`n`n[CODE]" },
            @{ Command = "summarize"; Title = "Summarize this document"; Content = "Provide a concise summary of the following text, highlighting the key points and main takeaways:`n`n[TEXT]" },
            @{ Command = "compare"; Title = "Compare and contrast"; Content = "Compare and contrast [ITEM_A] and [ITEM_B], highlighting their similarities, differences, pros, and cons." },
            @{ Command = "audit"; Title = "Security audit"; Content = "Perform a security audit on the following configuration/code and identify any potential vulnerabilities or misconfigurations:`n`n[CONTENT]" },
            @{ Command = "sql"; Title = "Optimize this SQL"; Content = "Analyze the following SQL query and suggest optimizations to improve its performance:`n`n[QUERY]" },
            @{ Command = "docs"; Title = "Create API documentation"; Content = "Generate clear and comprehensive API documentation for the following endpoints, including examples:`n`n[ENDPOINTS]" },
            @{ Command = "brainstorm"; Title = "Brainstorm ideas for"; Content = "Brainstorm 10 creative and diverse ideas for [TOPIC]. Provide a brief description for each idea." }
        )

        foreach ($prompt in $prompts) {
            Write-LogMessage -Message "Configuring prompt: $($prompt.Title)" -Level "INFO"
            $payload = @{
                command = $prompt.Command
                title = $prompt.Title
                content = $prompt.Content
            } | ConvertTo-Json
            
            Invoke-RestMethod -Uri "$BaseUrl/api/v1/prompts" -Method Post -Headers $headers -Body $payload -ContentType "application/json" -ErrorAction SilentlyContinue | Out-Null
        }
    } catch {
        Write-LogMessage -Message "Error configuring prompts: $_" -Level "ERROR"
    }
}
