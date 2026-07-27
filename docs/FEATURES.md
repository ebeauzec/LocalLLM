# LocalLLM Features Reference

> **Copyright (c) 2025-2026 Eugene Beauzec. All Rights Reserved.**
> GitHub: [LocalLLM](https://github.com/ebeauzec/LocalLLM)

This document provides a comprehensive reference for all enterprise features available in the LocalLLM platform.

---

## AI Assistant Profiles

LocalLLM comes pre-configured with six specialized model profiles designed for specific workflows.

| Profile | Description | Best Use Cases | Key Parameters |
| :--- | :--- | :--- | :--- |
| **General Assistant** | All-purpose chat, Q&A, and summarization. | Daily inquiries, brainstorming, drafting emails. | Balanced temperature (0.7), medium context. |
| **Reasoning Engine** | Deep thinking with visible chain-of-thought. | Complex problem solving, logic puzzles, multi-step planning. | Low temperature (0.1), large context, CoT enabled. |
| **Code Developer** | Software engineering with code gen, review, debugging. | Writing scripts, reviewing pull requests, architecture design. | Low temperature (0.2), strict system prompt, large context. |
| **Data Analyst** | Statistics, data manipulation, visualization. | Data cleaning, SQL generation, charting insights. | Balanced temperature (0.5), access to tools. |
| **Creative Writer** | Content creation, copywriting, storytelling. | Blog posts, marketing copy, creative writing. | High temperature (0.9), high presence penalty. |
| **Security Analyst** | Cybersecurity auditing, threat modeling. | Code security review, architecture threat modeling. | Low temperature (0.1), specialized security context. |

## Built-in Tools

LocalLLM includes an integrated suite of tools that the models can use autonomously to accomplish complex tasks.

| Tool | Description |
| :--- | :--- |
| **Code Executor** | Run Python code in a secure sandboxed environment. |
| **Web Page Reader** | Fetch, parse, and analyze web page contents. |
| **Local File Manager** | Read, write, and search files on the local filesystem. |
| **Calculator** | Perform complex mathematical computations and unit conversions. |
| **DateTime Tool** | Date/time calculations and timezone conversions. |
| **System Info** | Monitor system resources and running processes. |
| **JSON/YAML Tool** | Parse, convert, and query structured data formats. |
| **Document Parser** | Parse 100+ document formats via Apache Tika (PDF, Word, Excel, PPT, images, HTML, EPUB, email, archives). Local OCR via Tesseract. |
| **Image Analyzer** | Analyze images, diagrams, and charts using local LLaVA vision model. Privacy-aware cloud fallback with full audit logging. |
| **Privacy Dashboard** | View real-time privacy reports, cloud usage logs, and sensitive data detection summaries directly in chat. |
| **Analytics Dashboard** | Cost savings reports, model usage breakdown, efficiency scores, daily trends, and cost projections — all in chat. |

## RAG (Document Intelligence)

Retrieval-Augmented Generation (RAG) allows you to chat with your documents.

*   **Supported Formats:** 100+ formats via Apache Tika — PDF, DOCX, XLSX, PPTX, HTML, EPUB, EML, CSV, images (with OCR), and more.
*   **OCR Engine:** Tesseract-powered OCR for scanned documents and images via the `apache/tika:latest-full` Docker image.
*   **Vision Analysis:** LLaVA 7B for local image understanding — diagrams, charts, photos analyzed without cloud APIs.
*   **Knowledge Base Management:** Upload and manage collections of documents in workspaces.
*   **Hybrid Search:** Combines semantic vector search with exact keyword matching for optimal retrieval.
*   **Referencing:** Type `#` in the chat to instantly reference and include specific files or knowledge bases in your prompt.

## Analytics & Cost Savings

LocalLLM tracks every request to measure the efficacy of local processing and calculate real cost savings.

### In-Chat Analytics (Privacy Dashboard Tool)
Ask the AI to show analytics directly in chat:
*   **Savings Report:** Total saved, cloud spend, cost per query, efficiency score.
*   **Model Usage:** Breakdown by model with request counts, tokens, and costs.
*   **Efficiency Report:** Processing distribution, cloud fallback reasons, privacy score.
*   **Cost Projection:** Project future costs by week, month, or year.
*   **Cloud Usage Log:** Detailed audit trail of every cloud API call.

### Terminal Analytics
```bash
./localllm.sh analytics    # Linux/macOS
.\localllm.ps1 analytics   # Windows
```
Displays a formatted dashboard with overall stats, cost analysis, efficiency bar, model breakdown, daily trends, and privacy summary.

### What's Tracked
| Metric | Description |
|:---|:---|
| Request count | Total, local, cloud (with percentages) |
| Token usage | Input/output tokens per request |
| Cost savings | Estimated $ saved by processing locally |
| Cloud spend | Actual estimated cost of cloud API calls |
| Model usage | Per-model request count, token usage, cost |
| Daily trends | Day-by-day breakdown of all metrics |
| PII detection | Sensitive data found, blocked, redacted |
| Efficiency score | % of requests processed locally |

## Web Search

Integrates SearXNG for private, untracked web search capabilities.

*   **SearXNG Integration:** Self-hosted metasearch engine that aggregates results without tracking.
*   **Context Injection:** Search results are intelligently formatted and injected into the model's context for up-to-date answers.
*   **Configuration:** Configure search engines (Google, DuckDuckGo, Bing) via the Admin Dashboard.

## Thinking & Reasoning

Advanced reasoning capabilities for complex tasks.

*   **Chain-of-Thought (CoT):** Models output their step-by-step reasoning process before providing the final answer.
*   **Collapsible Blocks:** Reasoning steps are displayed in clean, collapsible UI blocks to keep the chat tidy.
*   **Effort Control:** Adjust the "reasoning effort" parameter to control how much time the model spends thinking.
*   **When to use:** Use reasoning models for logic, math, and complex planning. Use general models for simple queries and creative tasks.

## Code Execution

Run Python code directly within the chat interface.

*   **Sandboxed Environment:** Code runs in isolated Docker containers to protect the host system.
*   **Security Constraints:** Network access is restricted, and file system access is limited to a temporary workspace.
*   **Output Formats:** Supports text output, tables, and inline rendering of generated images/charts (e.g., matplotlib).
*   **Data Analysis:** The model can write scripts to analyze CSV data and generate insights automatically.

## Artifacts

Artifacts are standalone, interactive UI elements generated by the model.

*   **What they are:** Substantial pieces of content (code, documents, designs) that deserve a dedicated view.
*   **Supported types:** Code snippets, HTML/React components, Markdown documents, Mermaid diagrams.
*   **Side-Panel Rendering:** Artifacts render in a dedicated side-panel alongside the chat, allowing you to view and interact with them while continuing the conversation.
*   **Editing and Exporting:** Easily edit artifact code directly in the UI or export them to files.

## MCP (Model Context Protocol)

Connect LocalLLM to external tools and data sources.

*   **What is MCP:** A standard protocol for models to interact with local and remote resources.
*   **Supported Connection Types:** stdio (local execution), SSE (remote HTTP).
*   **Adding Servers:** Configure MCP servers in the settings to expose new tools to the models.
*   **Popular Servers:** filesystem (read local files), github (manage repos), postgres (query databases).

## Multi-Model Switching

Seamlessly transition between different models within a single chat.

*   **How to switch:** Use the model selector dropdown at the top of the chat to change the active model mid-conversation.
*   **Model Comparison:** Use the "Compare" feature to send a single prompt to multiple models simultaneously and evaluate their responses side-by-side.
*   **When to use:** Start a complex task with the Reasoning Engine, then switch to the Code Developer to implement the plan.

## Keyboard Shortcuts

| Action | Shortcut |
| :--- | :--- |
| Open New Chat | `Ctrl/Cmd + K` |
| Focus Input | `/` |
| Reference File | `#` |
| Mention Model | `@` |
| Submit Prompt | `Enter` |
| Line Break | `Shift + Enter` |
| Stop Generation | `Esc` |
| Toggle Sidebar | `Ctrl/Cmd + B` |

## Prompt Library

Pre-built prompt templates to kickstart your workflows.

1.  **Code Reviewer:** Analyzes provided code for bugs, security vulnerabilities, and style improvements.
2.  **Unit Test Generator:** Generates comprehensive unit tests for a given function or class.
3.  **Documentation Writer:** Drafts technical documentation based on code or specifications.
4.  **Meeting Summarizer:** Extracts action items and key decisions from meeting transcripts.
5.  **Data Extraction:** Pulls structured JSON data from unstructured text.
6.  **ELI5 (Explain Like I'm 5):** Breaks down complex concepts into simple analogies.
7.  **UX Researcher:** Critiques UI designs and suggests usability improvements.
8.  **SQL Expert:** Generates optimized SQL queries based on natural language requests.
9.  **Language Translator:** Translates text idiomatically, preserving tone and context.
10. **Brainstorming Partner:** Generates creative ideas and lateral thinking exercises.

## Admin Dashboard

Comprehensive control over the LocalLLM instance.

*   **User Management:** Create users, manage roles (Admin/User), and handle password resets.
*   **Usage Analytics:** Monitor token consumption, active users, and model popularity.
*   **Model Management:** Download new models from Ollama, configure API keys for cloud fallbacks (LiteLLM).
*   **System Settings:** Configure RAG chunking parameters, Web Search limits, and default models.

## API Access

Integrate LocalLLM into your existing tools and scripts.

*   **Endpoint:** Exposes a fully OpenAI-compatible API endpoint.
*   **Authentication:** Generate API keys via the user settings page.
*   **Example (cURL):**
```bash
curl http://localhost:3000/api/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -d '{
    "model": "llama3",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```
*   **Example (Python):** Use the standard `openai` python package by pointing the `base_url` to `http://localhost:3000/api`.
