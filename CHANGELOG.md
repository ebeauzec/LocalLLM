# Changelog

All notable changes to this project will be documented in this file.

## [v0.6.1] - 2026-07-27

### Added — Adaptive Hardware Optimization
- **TITAN tier** (64GB+ RAM): Flagship 70B models — near GPT-4 quality running 100% locally
- **Smart model selection**: Automatically picks the BEST model per category (General, Code, Reasoning, Vision, Embedding) for the detected hardware
- **Integrated GPU handling**: AMD APUs and Intel iGPUs with shared memory are now properly classified using RAM-based effective VRAM estimation
- **Vision models**: LLaVA 7B/13B auto-included based on tier (MEDIUM+/HIGH+)
- **Embedding model**: `nomic-embed-text` always included for local RAG/search
- **Disk space safety**: Automatically drops largest models if insufficient disk space
- **Enhanced system report**: Tier badges, accelerator config display, tool capability descriptions

### Changed
- Hardware tier thresholds simplified: LOW (<8GB), MEDIUM (8-16GB), HIGH (16-32GB), ULTRA (32-64GB), TITAN (64GB+)
- Model catalog expanded from 10 to 17 models across 5 categories and 5 tiers
- System report now shows full Ollama tuning parameters (threads, parallelism, KV cache, FlashAttention, keep-alive)

## [v0.6.0] - 2026-07-27

### Added — GPU/NPU Detection & Hardware Acceleration
- **GPU Auto-Detection**: NVIDIA (CUDA), AMD (ROCm), Intel (Arc), Apple (Metal)
- **NPU Detection**: AMD XDNA, Intel AI Boost, Apple Neural Engine
- **AMD ROCm Support**: Auto-selects `ollama/ollama:rocm` image, configures `/dev/kfd` + `/dev/dri` device passthrough, sets `HSA_OVERRIDE_GFX_VERSION` for RDNA3
- **CPU Optimization**: Auto-configures `OLLAMA_NUM_THREADS` (physical cores), `OLLAMA_NUM_PARALLEL` (cores/4), `OLLAMA_MAX_LOADED_MODELS` (RAM/16GB)
- **FlashAttention**: Enabled by default for faster inference and lower VRAM usage
- **KV Cache Tuning**: `q8_0` for ≥64GB RAM, `q4_0` for ≥32GB, `f16` otherwise
- **Model Keep-Alive**: 24h default to avoid reload latency
- **Docker Compose Template**: Flexible `{{OLLAMA_IMAGE}}`, `{{ACCELERATOR_BLOCK}}`, `{{OLLAMA_ENV_VARS}}` placeholders replace hardcoded NVIDIA-only config
- **Bash Installer**: Full GPU/NPU/CPU detection for Linux and macOS (rocm-smi, lspci, system_profiler)
- **FEATURES.md**: New Hardware Acceleration section with GPU, NPU, and CPU tuning reference tables

### Fixed
- `install.ps1`: Admin elevation now uses `pwsh` (PS7) instead of `powershell.exe` (PS5.1) — fixes `??` operator parse errors
- `uninstall.ps1`: Same pwsh elevation fix

## [v0.5.2] - 2026-07-27

### Fixed — Complete Deployment Folder Isolation
- **All Docker Compose calls** now use `--project-directory` to lock volume resolution to the deployment folder
- **localllm.ps1**: New `Invoke-DockerCompose` wrapper function guarantees `--project-directory $ProjectRoot` on every call
- **localllm.sh**: `DOCKER_COMPOSE` variable now includes `-f $COMPOSE_FILE --project-directory $SCRIPT_DIR`
- **deploy.ps1**: Compose launch uses `--project-directory` alongside `Push-Location`
- **health-check.ps1**: Container health checks and auto-repair use project-directory-scoped compose calls
- **start.ps1 / start.sh**: Running-detection compose calls scoped to project root
- **COMPOSE_PROJECT_NAME**: Set to `localllm` to isolate Docker resources from other projects
- All data (`data/`), config (`config/`), logs, metrics, and audit files remain within the deployment folder
- Safe to run from any working directory — paths never leak outside the project

## [v0.5.1] - 2026-07-27

### Added — One-Click Launcher & Persistence
- **start.ps1**: One-click Windows launcher — auto-detects first run (install) vs subsequent (start)
- **start.sh**: One-click macOS/Linux launcher with browser auto-open
- Smart detection: Already running? Just opens the browser. Not installed? Runs full installer.
- Persistence clearly documented: conversations, uploads, models, settings, RAG, analytics all survive restarts
- Quick action flags: `-Stop`, `-Status`, `-Analytics`, `--stop`, `--status`, `--analytics`

### Changed
- README Quick Start: Now leads with `start.ps1`/`start.sh` as the primary entry point
- README: Added persistence section explaining exactly what persists between sessions
- VERSION bumped to 0.5.1

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
