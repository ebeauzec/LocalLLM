# LocalLLM Knowledge Repository

Copyright (c) 2025-2026 Eugene Beauzec. All Rights Reserved.

## 1. Overview
The Knowledge Repository transforms LocalLLM into an enterprise Retrieval-Augmented Generation (RAG) system, similar to NotebookLM. It allows you to securely augment AI responses with your own local documents and data. When the AI uses your knowledge base, it automatically includes source citations in its responses, ensuring accuracy and traceability. The Knowledge Repository seamlessly integrates with all 14 personas, allowing specialized AI agents to reason over your private information.

## 2. Quick Start
Getting started with the Knowledge Repository is easy:
1. Drop your documents and files into the `knowledge/` folder in your LocalLLM installation directory.
2. Run the sync command: `.\localllm.ps1 knowledge sync`
3. In your chat sessions, use `#` to select and attach a specific knowledge collection.
4. Ask questions! The AI will automatically search and utilize your documents to provide informed answers.

## 3. Adding Source Folders
You can include external folders without copying their contents into the `knowledge/` directory. These are treated as read-only source folders.

**Using the CLI:**
```powershell
.\localllm.ps1 knowledge sources add "G:\Customers" --collection customers
```

**Manual Configuration:**
You can also manually edit the `knowledge-sources.json` file to add or modify paths.

*Note: All external source folders are strictly READ-ONLY. LocalLLM tools will never modify, delete, or alter files in your source directories.*

## 4. Directory Structure
The internal `knowledge/` folder uses directories to organize documents into collections:

```
knowledge/
├── customers/
│   ├── acme-corp/
│   └── globex-inc/
├── projects/
├── reference/
└── templates/
```

## 5. Collections
Collections are grouped sets of knowledge bases. The top-level folder names inside your `knowledge/` directory (or defined via source folders) map directly to collection names.

- **Using Collections:** Type `#collection-name` in the chat to scope the AI's search to that specific collection.
- **Multiple Collections:** You can attach multiple collections to a single chat session to allow the AI to cross-reference data from different domains.

## 6. Supported Formats
The Knowledge Repository supports a wide variety of document types:

| Format | Description |
| :--- | :--- |
| `.txt`, `.md`, `.csv` | Plain text, Markdown, and comma-separated values |
| `.pdf` | Portable Document Format (text extraction) |
| `.docx`, `.xlsx`, `.pptx` | Microsoft Office Documents (Word, Excel, PowerPoint) |
| `.json`, `.yaml`, `.xml` | Structured data formats |
| `.html`, `.htm` | Web pages and HTML documents |
| `.py`, `.js`, `.ps1`, etc. | Source code files for technical context |

## 7. Auto-Sync & File Watching
The system includes an auto-watcher that automatically detects file changes in your knowledge folders and updates the index.

- **Manual Sync:** To manually synchronize all files: `.\localllm.ps1 knowledge sync`
- **Force Resync:** To force a complete rebuild of the index (ignoring the cache): `.\localllm.ps1 knowledge sync --force`
- **Detection:** The system uses hash-based change detection to ensure only modified files are processed, keeping syncs fast.

## 8. CLI Reference
Manage your knowledge base using the `localllm.ps1` CLI:

- `knowledge sync` — Sync all configured source folders to the index.
- `knowledge sync --watch` — Start the file watcher for real-time synchronization.
- `knowledge sync --force` — Force a full resync of all documents.
- `knowledge sources` — List all currently configured external source folders.
- `knowledge sources add <path>` — Add a new read-only source folder.
- `knowledge sources remove <path>` — Remove an existing source folder.
- `knowledge list` — List all files currently indexed in the repository.
- `knowledge search "query"` — Perform a semantic search on your knowledge base content.
- `knowledge status` — Display the current synchronization status and index health.

## 9. Persona + Knowledge Workflows
Combining specialized personas with specific knowledge collections unlocks powerful workflows:

- **Storage Engineer + Customer Data:** Analyze historical usage and system logs to perform capacity planning and performance tuning.
- **TAM (Technical Account Manager) + Customer History:** Instantly generate comprehensive QBR (Quarterly Business Review) preparation materials based on past interactions and project status.
- **Security Analyst + Project Docs:** Conduct thorough vulnerability assessments against architectural diagrams and security requirement documents.
- **Solutions Architect + Requirements:** Design robust architectures by cross-referencing customer requirements against best-practice templates and reference materials.

## 10. Privacy & Security
- **Local Data:** All your data, indices, and vector embeddings stay entirely local on your machine.
- **Read-Only Sources:** External source folders are strictly read-only to prevent accidental modification.
- **Privacy Modes:** Your configured privacy modes automatically apply to knowledge retrieval.
- **No Cloud Uploads:** No data from your knowledge base is ever sent to cloud APIs unless you explicitly enable a cloud model and allow it.

## 11. Troubleshooting
- **File not being indexed:** Check if the file format is supported and ensure the file is not corrupted or locked by another application.
- **Collection not appearing:** Verify the folder structure and run `.\localllm.ps1 knowledge sync`.
- **Sync stuck:** Press `Ctrl+C` to cancel the current operation and run `.\localllm.ps1 knowledge sync --force`.
- **Log locations:** Check the detailed logs located in the `logs/` directory of your LocalLLM installation for specific error messages.
