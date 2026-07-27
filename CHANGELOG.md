# Changelog

All notable changes to this project will be documented in this file.

## [v0.5.0] - 2026-07-27

### Added — Document Intelligence & Privacy Pipeline
- **Apache Tika integration**: 100+ document format parsing (PDF, Word, Excel, PPT, images, HTML, EPUB, email, archives)
- **Local OCR**: Tesseract-powered OCR for scanned documents and images via Tika full image
- **Vision model**: LLaVA 7B auto-installed for local image analysis (diagrams, charts, photos)
- **Privacy audit filter pipeline**: Intercepts ALL requests, detects sensitive data, enforces privacy modes
  - STRICT: Blocks all cloud requests
  - BALANCED: Scans for PII, warns before cloud sends
  - PERMISSIVE: Auto-redacts sensitive data before cloud transmission
- **In-chat privacy dashboard**: View cloud usage, sensitive data reports, and data flow summaries directly in chat
- **Document Parser tool**: Universal format parsing via Tika with OCR and metadata extraction
- **Image Analyzer tool**: Local vision analysis with privacy-aware cloud fallback and full audit logging
- **Privacy Dashboard tool**: Real-time privacy reporting in the chat interface
- **Tika Docker service**: Added to Docker Compose with health checks and custom configuration
- **Cloud response notices**: Discreet privacy notices appended to cloud-sourced responses
- **docs/DOCUMENT_PROCESSING.md**: Comprehensive document processing guide
- **tika-config.xml**: OCR-optimized Tika configuration

### Changed
- Docker Compose template: Added Tika service, Tika environment variables
- deploy.ps1: Added Tika placeholder handling and vision model pull
- model-selector.ps1: Auto-includes LLaVA for systems with ≥ 8GB RAM
- VERSION bumped to 0.5.0
- Docker services: now 6 (Ollama, LiteLLM, Open WebUI, Pipelines, Tika, SearXNG)

## [v0.4.0] - 2026-07-27

### Added — Multi-Platform, Lifecycle & Automation
- **Cross-platform support**: Full Linux and macOS installers and management CLIs
  - install.sh: 9-step bash installer with platform auto-detection (Ubuntu/Debian, Fedora/RHEL, Arch, macOS)
  - localllm.sh: Bash management CLI with all commands
  - uninstall.sh: Bash uninstaller with confirmation safeguards
- **Unattended/headless installation**: `-Unattended -ConfigFile install-config.json` for non-interactive deployment
  - install-config.json template with all configurable options
  - Works in CI/CD, Group Policy, remote deployment scenarios
  - Both PowerShell and Bash installers support unattended mode
- **Graceful lifecycle management**:
  - `start`: Auto-opens browser after services are healthy
  - `stop`: Graceful shutdown with resource recovery report (memory freed, GPU released, ports unbound)
  - Full session persistence — pick up where you left off with complete conversation history
- **Version management**:
  - VERSION file as single source of truth
  - `localllm version`: Display current version and system info
  - `localllm bump-version [major|minor|patch]`: Increment version, auto-commit and push
  - `localllm push [message]`: Commit all changes and push to GitHub
- **Persistence documentation**: Comprehensive PERSISTENCE.md covering session lifecycle, data persistence, graceful shutdown/resume, and backup/restore

### Changed
- install.ps1: Added -Unattended and -ConfigFile parameters, Read-HostOrConfig helper, version from VERSION file
- localllm.ps1: Added version, bump-version, push commands; enhanced start (auto-browser) and stop (resource recovery)

## [v0.3.0] - 2026-07-27

### Added — Enterprise Features
- 6 specialized AI assistant profiles (General, Reasoning, Code Developer, Data Analyst, Creative Writer, Security Analyst)
- 7 built-in developer tools (Code Executor, Web Scraper, File Manager, Calculator, DateTime, System Info, JSON/YAML)
- Custom Ollama Modelfiles for each AI profile with tuned parameters
- Open WebUI Pipelines server for custom tool execution
- Automated Open WebUI configuration via REST API (configure-webui.ps1)
- Custom model profile creation from Modelfiles (setup-models.ps1)
- Enterprise Docker Compose template with Pipelines, code execution, artifacts
- Comprehensive FEATURES.md reference document
- DEVELOPER_GUIDE.md for extending LocalLLM with custom tools, models, and pipelines
- 10 pre-built prompt templates for common tasks
- Code execution sandbox (ENABLE_CODE_EXECUTION)
- Artifacts rendering (ENABLE_ARTIFACTS)
- Thinking/reasoning display for chain-of-thought models
- MCP (Model Context Protocol) integration support
- OpenAI-compatible API endpoint for programmatic access
- 9-step installation flow (was 7)

## [v0.2.0] - 2026-07-27

### Added — Privacy & Cost Optimization
- Data Privacy Guard module (privacy-guard.ps1) with three modes: STRICT/BALANCED/PERMISSIVE
- Automatic sensitive data detection (credit cards, SSNs, API keys, passwords, private keys, IPs)
- Privacy audit trail with cost savings reporting
- Custom data blocklist for company-specific patterns
- `privacy` CLI command (strict/balanced/permissive/report/status/blocklist)
- Privacy mode selection as first step in configuration wizard
- STRICT mode auto-disables all cloud API access
- Content redaction engine for cloud-bound requests
- Comprehensive PRIVACY.md documentation
- Cost optimization documentation and local-first routing philosophy
- LiteLLM config template enhanced with cost-based routing documentation

## [v0.1.0] - 2026-07-27

### Added
- Initial release of LocalLLM installer platform.
- Hardware-aware installation script that auto-detects CPU/GPU and RAM tiers.
- Docker Compose deployment architecture.
- Open WebUI integration for a familiar chat interface.
- LiteLLM integration for API routing and cloud fallback capabilities.
- SearXNG metasearch engine integration for secure web search capabilities.
- `localllm` Management CLI for starting, stopping, updating, and repairing the deployment.
- Self-healing diagnostics for auto-recovering from common deployment issues.
