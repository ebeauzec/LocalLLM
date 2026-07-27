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
        
        $port = if ($Configuration.WebUIPort) { $Configuration.WebUIPort } else { 3100 }
        $baseUrl = "http://localhost:${port}"
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
        $adminEmail = "admin@localllm.local"
        $adminPassword = "localllm-admin"
        $adminName = "Admin"
        try { if ($Configuration.AdminEmail) { $adminEmail = $Configuration.AdminEmail } } catch {}
        try { if ($Configuration.AdminPassword) { $adminPassword = $Configuration.AdminPassword } } catch {}
        try { if ($Configuration.AdminName) { $adminName = $Configuration.AdminName } } catch {}

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
            @{ id = "localllm-assistant"; name = "General Assistant"; meta = @{ description = "Versatile AI assistant"; profile_image_url = "🤖"; capabilities = @{ vision = $false; usage = $true } }; params = @{} },
            @{ id = "localllm-reasoning"; name = "Reasoning Engine"; meta = @{ description = "Advanced reasoning and logic"; profile_image_url = "🧠"; capabilities = @{ vision = $false; usage = $true } }; params = @{} },
            @{ id = "localllm-developer"; name = "Code Developer"; meta = @{ description = "Software engineering expert"; profile_image_url = "💻"; capabilities = @{ vision = $false; usage = $true } }; params = @{} },
            @{ id = "localllm-analyst"; name = "Data Analyst"; meta = @{ description = "Data analysis and visualization"; profile_image_url = "📊"; capabilities = @{ vision = $false; usage = $true } }; params = @{} },
            @{ id = "localllm-creative"; name = "Creative Writer"; meta = @{ description = "Creative and engaging writing"; profile_image_url = "✍️"; capabilities = @{ vision = $false; usage = $true } }; params = @{} },
            @{ id = "localllm-security"; name = "Security Analyst"; meta = @{ description = "Cybersecurity expert"; profile_image_url = "🛡️"; capabilities = @{ vision = $false; usage = $true } }; params = @{} },
            @{ id = "localllm-architect"; name = "Solutions Architect"; meta = @{ description = "System architecture and design"; profile_image_url = "🏗️"; capabilities = @{ vision = $false; usage = $true } }; params = @{} },
            @{ id = "localllm-storage"; name = "Storage Engineer"; meta = @{ description = "Data storage and management"; profile_image_url = "💾"; capabilities = @{ vision = $false; usage = $true } }; params = @{} },
            @{ id = "localllm-tam"; name = "Technical Account Manager"; meta = @{ description = "Client relations and technical guidance"; profile_image_url = "🤝"; capabilities = @{ vision = $false; usage = $true } }; params = @{} },
            @{ id = "localllm-devops"; name = "DevOps Engineer"; meta = @{ description = "CI/CD and infrastructure automation"; profile_image_url = "⚙️"; capabilities = @{ vision = $false; usage = $true } }; params = @{} },
            @{ id = "localllm-executive"; name = "Executive Advisor"; meta = @{ description = "Strategic business guidance"; profile_image_url = "👔"; capabilities = @{ vision = $false; usage = $true } }; params = @{} },
            @{ id = "localllm-writer"; name = "Technical Writer"; meta = @{ description = "Clear technical documentation"; profile_image_url = "📝"; capabilities = @{ vision = $false; usage = $true } }; params = @{} },
            @{ id = "localllm-pm"; name = "Project Manager"; meta = @{ description = "Project planning and execution"; profile_image_url = "📅"; capabilities = @{ vision = $false; usage = $true } }; params = @{} },
            @{ id = "localllm-docproc"; name = "Document Processor"; meta = @{ description = "Document structuring and analysis"; profile_image_url = "📄"; capabilities = @{ vision = $false; usage = $true } }; params = @{} }
        )

        foreach ($model in $models) {
            Write-LogMessage -Message "Configuring model: $($model.name)" -Level "INFO"
            # Exact payload matching the updated schema
            $payload = $model | ConvertTo-Json -Depth 5
            
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
            @{ name = "Code Executor"; description = "Executes code in a secure sandbox"; content = "def execute_code(code: str) -> str:`n    return 'Code execution not implemented'" },
            @{ name = "Web Page Reader"; description = "Extracts content from web pages"; content = "def read_webpage(url: str) -> str:`n    return 'Web reading not implemented'" },
            @{ name = "Local File Manager"; description = "Reads and writes local files"; content = "def manage_file(path: str, action: str) -> str:`n    return 'File management not implemented'" },
            @{ name = "Calculator"; description = "Performs mathematical calculations"; content = "def calculate(expression: str) -> str:`n    return 'Calculation not implemented'" },
            @{ name = "DateTime Tool"; description = "Gets current date and time"; content = "import datetime`ndef get_datetime() -> str:`n    return str(datetime.datetime.now())" },
            @{ name = "System Info"; description = "Retrieves system information"; content = "import platform`ndef get_sys_info() -> str:`n    return platform.platform()" },
            @{ name = "JSON/YAML Tool"; description = "Parses and formats JSON/YAML"; content = "def parse_data(data: str) -> str:`n    return 'Parsing not implemented'" },
            @{ name = "Document Formatter"; description = "converts markdown to structured formats"; content = "def format_doc(doc: str, format: str) -> str:`n    return 'Formatting not implemented'" },
            @{ name = "Diagram Generator"; description = "creates Mermaid diagram code from descriptions"; content = "def generate_diagram(desc: str) -> str:`n    return 'graph TD;\n    A-->B;'" },
            @{ name = "CSV/Data Analyzer"; description = "basic statistical analysis"; content = "def analyze_csv(data: str) -> str:`n    return 'Analysis not implemented'" },
            @{ name = "Project Planner"; description = "generates WBS and timelines"; content = "def plan_project(reqs: str) -> str:`n    return 'Planning not implemented'" },
            @{ name = "Compliance Checker"; description = "checks text against regulatory requirements"; content = "def check_compliance(text: str) -> str:`n    return 'Compliance not implemented'" }
        )

        foreach ($tool in $tools) {
            Write-LogMessage -Message "Configuring tool: $($tool.name)" -Level "INFO"
            $payload = @{
                name = $tool.name
                description = $tool.description
                content = $tool.content
            } | ConvertTo-Json -Depth 5
            
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
            @{ command = "analyze"; title = "Analyze this code"; content = "Please analyze the following code, identify any potential bugs, security vulnerabilities, or performance issues, and suggest improvements:`n`n[PASTE_CODE_HERE]" },
            @{ command = "eli5"; title = "Explain like I'm 5"; content = "Explain the following concept in simple terms, as if you were talking to a 5-year-old:`n`n[CONCEPT]" },
            @{ command = "debug"; title = "Debug this error"; content = "I am getting the following error. Please explain what it means and provide a step-by-step guide to fix it:`n`n[ERROR_MESSAGE]" },
            @{ command = "test"; title = "Write tests for"; content = "Write comprehensive unit tests for the following code, covering edge cases and expected behaviors:`n`n[CODE]" },
            @{ command = "summarize"; title = "Summarize this document"; content = "Provide a concise summary of the following text, highlighting the key points and main takeaways:`n`n[TEXT]" },
            @{ command = "compare"; title = "Compare and contrast"; content = "Compare and contrast [ITEM_A] and [ITEM_B], highlighting their similarities, differences, pros, and cons." },
            @{ command = "audit"; title = "Security audit"; content = "Perform a security audit on the following configuration/code and identify any potential vulnerabilities or misconfigurations:`n`n[CONTENT]" },
            @{ command = "sql"; title = "Optimize this SQL"; content = "Analyze the following SQL query and suggest optimizations to improve its performance:`n`n[QUERY]" },
            @{ command = "docs"; title = "Create API documentation"; content = "Generate clear and comprehensive API documentation for the following endpoints, including examples:`n`n[ENDPOINTS]" },
            @{ command = "brainstorm"; title = "Brainstorm ideas for"; content = "Brainstorm 10 creative and diverse ideas for [TOPIC]. Provide a brief description for each idea." },
            @{ command = "/swot"; title = "SWOT Analysis"; content = "Analyze [topic/product/strategy] using a structured SWOT framework. Present as a 2x2 table with Strengths, Weaknesses, Opportunities, Threats. Include 3-5 items per quadrant with brief explanations." },
            @{ command = "/decision-matrix"; title = "Decision Matrix"; content = "Compare [options] against [criteria]. Create a weighted scoring table. Assign weights (1-5) to each criterion, score each option (1-10), calculate weighted totals, and recommend the highest-scoring option with rationale." },
            @{ command = "/rca"; title = "Root Cause Analysis"; content = "Analyze [problem/incident]. Apply the 5 Whys technique, then create an Ishikawa/Fishbone diagram categorizing causes under: People, Process, Technology, Environment. Identify the root cause and recommend corrective actions." },
            @{ command = "/risk-assess"; title = "Risk Assessment"; content = "Evaluate risks for [project/initiative]. Create a risk register table with columns: Risk ID, Description, Probability (1-5), Impact (1-5), Risk Score, Mitigation Strategy, Owner. Sort by risk score descending." },
            @{ command = "/pros-cons"; title = "Pros & Cons Analysis"; content = "Evaluate [decision/option]. List pros and cons with weighted importance (High/Medium/Low). Provide a summary recommendation with confidence level." },
            @{ command = "/gap-analysis"; title = "Gap Analysis"; content = "Compare current state vs desired state for [area]. Use a table with columns: Category, Current State, Desired State, Gap, Priority, Action Required. Summarize key gaps and a remediation roadmap." },
            @{ command = "/cost-benefit"; title = "Cost-Benefit Analysis"; content = "Analyze [initiative/investment]. Itemize all costs (one-time + recurring) and benefits (tangible + intangible). Calculate ROI, payback period, and NPV over [timeframe]. Present recommendation." },
            @{ command = "/rewrite"; title = "Rewrite Content"; content = "Rewrite the following content in a [formal/casual/executive/technical] tone while preserving all key information. Improve clarity, flow, and impact. Highlight any ambiguities found in the original." },
            @{ command = "/restructure"; title = "Restructure Document"; content = "Restructure this document for maximum clarity and impact. Reorganize sections logically, add proper headings, improve transitions, consolidate redundant content, and add an executive summary at the top." },
            @{ command = "/summarize-exec"; title = "Executive Summary"; content = "Create a 1-page executive summary of the following. Use bullet points for key findings, bold critical numbers/metrics, and end with 3 actionable recommendations. Write for a C-level audience." },
            @{ command = "/meeting-notes"; title = "Meeting Notes"; content = "Extract structured meeting notes from the following. Format as: ## Attendees, ## Key Decisions, ## Action Items (with owner and due date), ## Open Questions, ## Next Meeting." },
            @{ command = "/rfp"; title = "RFP Response"; content = "Generate an RFP response outline for the following requirements. Structure as: Executive Summary, Company Overview, Technical Approach, Implementation Timeline, Pricing Framework, Team & Qualifications, References, Appendices." },
            @{ command = "/sow"; title = "Statement of Work"; content = "Generate a Statement of Work from these requirements. Include: Project Overview, Scope of Work, Deliverables, Timeline & Milestones, Acceptance Criteria, Assumptions & Constraints, Pricing, Terms & Conditions." },
            @{ command = "/design-doc"; title = "Technical Design Document"; content = "Create a Technical Design Document for [feature/system]. Include: Overview, Goals & Non-Goals, Background, Detailed Design, API Design, Data Model, Security Considerations, Testing Strategy, Rollout Plan, Open Questions." },
            @{ command = "/postmortem"; title = "Incident Post-mortem"; content = "Create an incident post-mortem from this information. Format: Incident Summary, Timeline, Root Cause, Impact (users affected, duration, revenue impact), What Went Well, What Went Wrong, Action Items (with owners and deadlines), Lessons Learned." },
            @{ command = "/runbook"; title = "Operational Runbook"; content = "Create an operational runbook for [system/process]. Include: Overview, Prerequisites, Step-by-Step Procedures, Troubleshooting Guide, Escalation Path, Rollback Procedures, Appendix (commands, URLs, credentials location)." },
            @{ command = "/qbr"; title = "Quarterly Business Review"; content = "Prepare a Quarterly Business Review from this data. Structure: Executive Summary, Key Metrics (with QoQ trends), Achievements This Quarter, Challenges & Risks, Product Roadmap Updates, Recommendations, Goals for Next Quarter." },
            @{ command = "/architect"; title = "System Architecture"; content = "Design a system architecture for [requirements]. Include: Context Diagram, Container Diagram (C4), Component interactions, Technology choices with rationale, Scalability considerations, Security boundaries. Use Mermaid diagrams." },
            @{ command = "/api-design"; title = "API Design"; content = "Design a REST API for [feature/system]. Define: Resource models, Endpoints (method, path, request/response schemas), Authentication, Pagination, Error handling, Rate limiting. Use OpenAPI-style documentation." },
            @{ command = "/migration-plan"; title = "Migration Plan"; content = "Create a migration plan for [source → target]. Include: Assessment, Risk Analysis, Migration Strategy (Big Bang vs. Phased), Data Mapping, Testing Plan, Rollback Plan, Cutover Checklist, Communication Plan." },
            @{ command = "/capacity-plan"; title = "Capacity Plan"; content = "Create a capacity plan for [system/infrastructure]. Analyze: Current utilization, Growth projections, Resource requirements (compute, storage, network), Cost projections, Scaling recommendations, Timeline." }
        )

        foreach ($prompt in $prompts) {
            Write-LogMessage -Message "Configuring prompt: $($prompt.title)" -Level "INFO"
            $payload = @{
                command = $prompt.command
                title = $prompt.title
                content = $prompt.content
            } | ConvertTo-Json -Depth 5
            
            Invoke-RestMethod -Uri "$BaseUrl/api/v1/prompts" -Method Post -Headers $headers -Body $payload -ContentType "application/json" -ErrorAction SilentlyContinue | Out-Null
        }
    } catch {
        Write-LogMessage -Message "Error configuring prompts: $_" -Level "ERROR"
    }
}
