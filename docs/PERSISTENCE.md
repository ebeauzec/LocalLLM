# Persistence and Session Management

This document details how LocalLLM handles persistence, session memory, and graceful lifecycle management.

## Session Lifecycle

The following diagram illustrates the lifecycle of a LocalLLM session:

```mermaid
flowchart TD
    Start[Start Command `.\start.ps1`] --> HealthCheck[Health Check]
    HealthCheck --> Resume[Resume Previous State from Named Volumes]
    Resume --> OpenBrowser[Open Browser on Port 3100]
    OpenBrowser --> UserWorks[User Works & Chats]
    UserWorks --> Stop[Stop Command `.\stop.ps1`]
    Stop --> Graceful[Graceful Shutdown]
    Graceful --> SaveState[Save State & Flush DB]
    SaveState --> ReturnRes[Return Resources (RAM/VRAM)]
```

## Named Docker Volumes

LocalLLM has transitioned away from legacy host bind mounts to **Named Docker Volumes**. This significantly improves reliability, especially when the repository is located in a synced folder like Google Drive, OneDrive, or Dropbox.

| Volume Name | Purpose | Persists Across |
|:---|:---|:---|
| `localllm-webui-data` | Chat history (SQLite), uploaded docs, RAG vector store, settings | Restarts, Updates, Reboots |
| `localllm-ollama-data` | AI model weights (GGUF), model configurations | Restarts, Updates |
| `localllm-litellm-config` | Generated API routing configurations via Init Container | Restarts |
| `localllm-searxng-config` | Search engine configurations via Init Container | Restarts |

## Memory and Context

The system "remembers" your data to provide a seamless continuous experience:
- **Full Conversation History:** Open WebUI maintains your complete chat history securely in `localllm-webui-data`.
- **Knowledge Retention:** Document collections for Retrieval-Augmented Generation (RAG) persist automatically.

## Graceful Shutdown Workflow (`stop.ps1`)

To ensure no data corruption occurs, you must use the newly introduced `stop.ps1` script to shut down the environment. 

When you run `.\stop.ps1`:
1. **Database Flush:** Open WebUI flushes any pending writes to its SQLite database.
2. **Model State:** Ollama safely saves the current model state.
3. **Container Teardown:** Docker containers are instructed to stop gracefully using SIGTERM timeouts.
4. **Memory Deallocation:** System memory and GPU VRAM are completely released.
5. **Port Unbinding:** All network ports (e.g., 3100) are unbound.

## Graceful Startup Workflow (`start.ps1`)

When you are ready to use LocalLLM again, run `.\start.ps1`:
1. **Container Resume:** Docker containers resume, attaching the persistent named volumes.
2. **Init Containers:** LiteLLM and SearXNG init containers dynamically unpack configurations from base64 environment variables into their respective volumes.
3. **Health Verification:** System health checks run.
4. **Browser Launch:** Opens your browser directly to `http://localhost:3100`.

## Backup and Restore

You can back up your named volumes using standard Docker volume backup techniques. Because the data is stored in volumes rather than bind mounts, it is insulated from accidental deletion of the project folder.

---
Copyright (c) 2025-2026 Eugene Beauzec. All Rights Reserved.
