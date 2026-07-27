# Persistence and Session Management

This document details how LocalLLM handles persistence, session memory, and graceful lifecycle management. Because LocalLLM runs locally on your own hardware, you have complete control over your data, how it is stored, and when it is removed.

## Session Lifecycle

The following diagram illustrates the lifecycle of a LocalLLM session, demonstrating how state is preserved between uses.

```mermaid
flowchart TD
    Start[Start Command `localllm start`] --> HealthCheck[Health Check]
    HealthCheck --> Resume[Resume Previous State]
    Resume --> OpenBrowser[Open Browser]
    OpenBrowser --> UserWorks[User Works & Chats]
    UserWorks --> Stop[Stop Command `localllm stop`]
    Stop --> Graceful[Graceful Shutdown]
    Graceful --> SaveState[Save State & Flush DB]
    SaveState --> ReturnRes[Return Resources (RAM/VRAM)]
```

## What Is Persisted

LocalLLM is designed to remember your interactions, settings, and models across restarts and reboots. 

| Data | Storage Location | Persists Across | Format |
|:---|:---|:---|:---|
| Conversation History | `data/open-webui/webui.db` | Restarts, Updates, Reboots | SQLite DB |
| Uploaded Documents | `data/uploads/` | Restarts, Updates | Original files |
| RAG Vector Store | `data/open-webui/` | Restarts | Chroma/FAISS |
| AI Model Weights | `data/ollama/` | Restarts, Updates | GGUF binary |
| Custom Model Profiles | Ollama registry | Restarts | Modelfile |
| User Settings | `data/open-webui/webui.db` | Restarts | SQLite DB |
| Chat Bookmarks/Tags | `data/open-webui/webui.db` | Restarts | SQLite DB |
| Tool Configurations | `data/open-webui/webui.db` | Restarts | SQLite DB |
| Privacy Settings | `config/` | Restarts | JSON |
| Cloud API Keys | `config/.env` | Restarts | Env vars |
| Install State | `.localllm-install-state.json` | Reboots | JSON |
| Privacy Audit Log | `data/privacy-audit.json` | Restarts | JSON |

## Memory and Context

The LocalLLM system "remembers" your data to provide a seamless continuous experience:

- **Full Conversation History:** Open WebUI maintains your complete chat history securely in a local SQLite database.
- **Continuous Sessions:** When you restart the system or your machine, all previous conversations remain available.
- **Advanced Management:** You can search, continue, branch, tag, and export past conversations at any time.
- **Knowledge Retention:** Document collections for Retrieval-Augmented Generation (RAG) persist, so you don't need to re-upload reference materials.
- **Personalized Environment:** Model parameters, tool configurations, privacy settings, and active blocklists are preserved exactly as you left them.

## Graceful Shutdown

When you run `localllm stop`, the system initiates a structured shutdown sequence to ensure no data is lost:

1. **Database Flush:** Open WebUI flushes any pending writes to its SQLite database.
2. **Model State:** Ollama safely saves the current model state and configurations.
3. **Container Teardown:** Docker containers are instructed to stop gracefully (sending SIGTERM, waiting, then SIGKILL if necessary).
4. **Memory Deallocation:** System memory (RAM) is freed and returned to the OS.
5. **VRAM Release:** GPU VRAM is completely released, making your GPU fully available for other tasks (gaming, rendering, etc.).
6. **Port Unbinding:** All network ports (e.g., 8080, 11434, 8081) are unbound.
7. **Resource Summary:** A resource recovery summary is displayed, confirming a successful shutdown.

## Graceful Startup / Resume

When you are ready to use LocalLLM again, running `localllm start` restores your environment:

1. **Container Resume:** Docker containers resume from their preserved data volumes.
2. **History Loading:** Open WebUI connects to the SQLite database and loads your workspace, including conversation history.
3. **Model Readiness:** Ollama prepares to load your last-used models into memory (or lazy-loads them upon first request, depending on configuration).
4. **Health Verification:** System health checks run to verify that all necessary services are online and communicating.
5. **Browser Launch:** The system automatically opens your default browser directly to the web UI.
6. **Seamless Continuation:** You can pick up any conversation or project exactly where you left off.

## Backup and Restore

Protecting your local data is a priority. LocalLLM provides simple tools to safeguard your entire setup.

### Creating a Backup
Use the CLI to create a complete snapshot of your configuration and data:
```bash
localllm backup
```
This command generates a timestamped archive containing:
- `config/` (Settings, `.env`, privacy configurations)
- `data/open-webui/webui.db` (Chat history, settings, RAG data)
- `data/uploads/` (Uploaded files and documents)
*(Note: Model weights in `data/ollama/` are usually excluded by default due to size, but can be re-downloaded.)*

### Restoring a Backup
To restore a previous state or migrate to a new machine, use the restore command:
```bash
localllm restore ./backups/localllm_backup_20231025.zip
```
This is particularly useful for migrating your entire local AI setup between workstations.

## Unattended / Headless Installation

For automated deployments across fleets or CI/CD environments, LocalLLM supports unattended installations via the `install-config.json` file.

### What is `install-config.json`?
It is a declarative configuration file that allows you to specify all installation choices upfront, bypassing interactive prompts. 

### Example Configurations

**Corporate Deployment (STRICT Privacy, Local Only):**
```json
{
  "privacyLevel": "STRICT",
  "enableCloudFallback": false,
  "defaultModel": "llama3",
  "port": 8080,
  "createDesktopShortcut": true
}
```

**Developer Workstation (BALANCED, All Features):**
```json
{
  "privacyLevel": "BALANCED",
  "enableCloudFallback": true,
  "openaiKey": "sk-...",
  "anthropicKey": "sk-ant-...",
  "defaultModel": "llama3",
  "port": 8080,
  "createDesktopShortcut": true
}
```

**CI/CD Testing Environment:**
```json
{
  "privacyLevel": "STRICT",
  "enableCloudFallback": false,
  "defaultModel": "phi3",
  "port": 9090,
  "createDesktopShortcut": false
}
```

## Multi-Platform Support

LocalLLM manages persistence uniformly, but the underlying mechanisms interface with different platform requirements.

| Platform | Installer | CLI | Prerequisites |
|:---|:---|:---|:---|
| **Windows** | `install.ps1` | `localllm.ps1` | WSL2, Docker Desktop |
| **macOS** | `install.sh` | `localllm.sh` | Homebrew, Docker Desktop |
| **Ubuntu/Debian** | `install.sh` | `localllm.sh` | Docker CE, `nvidia-container-toolkit` |
| **Fedora/RHEL** | `install.sh` | `localllm.sh` | Docker CE, `nvidia-container-toolkit` |
| **Arch Linux** | `install.sh` | `localllm.sh` | Docker, `nvidia-container-toolkit` |

## Version Management

LocalLLM tracks its own state and versioning cleanly to ensure updates do not break your persistence layer.

- **`VERSION` File:** The project root contains a `VERSION` file which acts as the single source of truth for the currently installed build.
- **Check Version:** Run `localllm version` to see your current version and if updates are available.
- **Bump Version (Devs):** Developers can use `localllm bump-version [major|minor|patch]` to increment the project version systematically.
- **Commit & Push:** Use `localllm push "Commit message"` to bundle your changes, commit them to git, and push them to the remote repository. Version bumps automatically trigger a git push if configured.

---
*Copyright © Eugene Beauzec (ebeauzec). Proprietary software. All rights reserved.*
