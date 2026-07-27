# Changelog

All notable changes to this project will be documented in this file.

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
