# 🚀 LocalLLM

> A self-contained, self-healing local AI platform installer for Windows.

![License: Proprietary](https://img.shields.io/badge/License-Proprietary-red.svg)
![Platform: Windows](https://img.shields.io/badge/Platform-Windows-blue.svg)
![Status: Active](https://img.shields.io/badge/Status-Active-success.svg)
![Privacy: Local-First](https://img.shields.io/badge/Privacy-Local--First-brightgreen.svg)
![Cost: Free Local AI](https://img.shields.io/badge/Cost-Free%20Local%20AI-blue.svg)

## 🤖 What is LocalLLM?

LocalLLM is a one-command installer that gives you a local AI assistant comparable to ChatGPT, Claude, or Gemini, running entirely on your machine. It deploys a robust stack via Docker Compose — designed from the ground up to **keep your data private** and **minimize cloud API costs**.

- 🔒 **Privacy First**: Your data NEVER leaves your machine by default. Sensitive data is automatically detected and blocked from cloud APIs.
- 💰 **Zero Cost**: Run powerful open-source models for free — no subscriptions, no per-token charges.
- 🌐 **Works Offline**: Fully functional without internet. All AI processing happens locally.
- ☁️ **Smart Cloud Fallback**: Only routes to cloud APIs as a last resort, with user awareness and data protection.
- 🏢 **Corporate Ready**: STRICT privacy mode for classified data, GDPR/HIPAA compliance, and audit trails.

## ✨ Features

- **🔒 Data Privacy Guard**: Three privacy modes (STRICT/BALANCED/PERMISSIVE) with automatic sensitive data detection — credit cards, SSNs, API keys, passwords, and custom patterns are blocked from cloud APIs.
- **💰 Local-First Cost Optimization**: All requests route to free local models first. Cloud APIs are only used as a last resort, saving you tokens and credits.
- **🔍 Hardware-aware auto-configuration**: Automatically detects your system specs and configures the optimal models.
- **⚡ One-command installation**: Simple PowerShell script to get everything up and running.
- **💬 ChatGPT-like web interface**: Powered by Open WebUI for a familiar, feature-rich experience.
- **📄 RAG (Retrieval-Augmented Generation)**: Upload documents and ask questions — all processed locally.
- **🌐 Private web search**: Secure web search via SearXNG — no tracking, no analytics.
- **🔧 Tool/function calling**: Models can interact with tools for advanced capabilities.
- **🧠 Multi-model support**: Easily switch between local and cloud models.
- **☁️ Intelligent cloud fallback**: Privacy-guarded routing with data scanning and user confirmation.
- **🏥 Self-healing diagnostics**: Built-in health checks and automatic repair.
- **🗑️ Clean install/uninstall**: Leaves no mess behind.
- **📊 Privacy audit trail**: Track what data stays local vs. cloud, with cost savings reporting.
- **🛠️ Management CLI**: Powerful command-line tool for managing your AI environment.

## 🚀 Quick Start

```powershell
git clone https://github.com/ebeauzec/LocalLLM.git
cd LocalLLM
.\install.ps1
```

## 💻 System Requirements

| Specification | Minimum | Recommended |
| ------------- | ------- | ----------- |
| **OS** | Windows 10/11 (64-bit) | Windows 10/11 (64-bit) |
| **RAM** | 8GB | 16GB+ |
| **GPU** | Optional (CPU only works) | NVIDIA GPU (for best performance) |
| **Disk** | 20GB free space | 50GB+ SSD |
| **Internet** | Required for initial setup | Broadband |

## 🏗️ Architecture

```mermaid
graph LR
    User([User]) --> UI[Open WebUI]
    UI --> LL[LiteLLM]
    LL -->|Primary| OL[Ollama]
    LL -.->|Fallback| Cloud[OpenAI / Anthropic / Google]
    UI -.->|Web Search| SX[SearXNG]
```

## 🧠 Hardware Tiers

| Tier | Hardware | Target Models |
| ---- | -------- | ------------- |
| **LOW** | 8GB RAM | Phi-4-mini 3.8B |
| **MEDIUM** | 16GB RAM | Llama 3.3 8B |
| **HIGH** | 32GB RAM | Qwen 3.6 14B + DeepSeek-R1 14B |
| **ULTRA** | 32GB+ RAM / 16GB+ VRAM | Qwen 3.6 27B + DeepSeek-R1 32B |

## 🛠️ Management Commands

| Command | Description |
| ------- | ----------- |
| `localllm start` | Starts all LocalLLM services |
| `localllm stop` | Stops all LocalLLM services |
| `localllm status` | Checks the status and health of the deployment |
| `localllm update` | Updates the models and containers to the latest versions |
| `localllm repair` | Runs self-healing diagnostics to fix common issues |
| `localllm models` | Lists currently installed models |
| `localllm uninstall` | Completely removes LocalLLM and its data |

## 🔒 Data Privacy Modes

| Mode | Privacy Level | Cloud Access | Best For |
|:---|:---|:---|:---|
| **🟢 STRICT** | Maximum | ❌ Completely disabled | Classified data, corporate secrets, GDPR/HIPAA |
| **🟡 BALANCED** | High (default) | ⚠️ With warning + scan | General business use |
| **🔴 PERMISSIVE** | Moderate | ✅ Allowed (auto-redacts) | Development/testing |

The built-in **Privacy Guard** automatically detects sensitive data patterns (credit cards, SSNs, API keys, passwords, internal IPs, database connection strings) and prevents them from being sent to cloud APIs.

```powershell
# Set privacy mode
.\localllm.ps1 privacy strict     # Maximum protection
.\localllm.ps1 privacy balanced   # Smart protection (default)
.\localllm.ps1 privacy report     # View privacy audit
```

> 📖 See [PRIVACY.md](docs/PRIVACY.md) for the comprehensive data security guide.

## 💰 Cost Optimization

LocalLLM is designed to **minimize cloud API spending**:

| | Local Models | Cloud APIs |
|:---|:---|:---|
| **Cost per token** | $0.00 (free) | $0.002–$0.06 |
| **Data privacy** | ✅ Stays on your machine | ⚠️ Sent to provider |
| **Speed** | Depends on hardware | Consistent |
| **Availability** | Always (offline-capable) | Requires internet |

- **Cost-based routing**: LiteLLM always routes to the cheapest option first (local = $0)
- **Cloud is last resort**: Only used when local models fail, error, or are overloaded
- **Budget controls**: Set daily/monthly cloud spending limits
- **Privacy report**: Track exactly how many requests stayed local vs. went to cloud

## 🎯 Use Cases

1. **🏢 Corporate AI** - Keep proprietary data, trade secrets, and IP inside your organization. No data leakage to cloud providers.
2. **🔒 Private AI Assistant** - Chat about personal finances, medical info, or legal matters without data leaving your machine.
3. **📄 Document Analysis** - Upload PDFs, Word documents, or text files and ask questions about them — all processed locally.
4. **💻 Code Assistant** - Get help with code generation, debugging, and code review without exposing proprietary source code.
5. **🔍 Research Tool** - Combine private web search with AI analysis — no tracking or profiling.
6. **✈️ Offline AI** - Stay productive when traveling or disconnected from the internet.
7. **👥 Team AI** - Host a shared instance on a powerful machine for your team with multi-user access control.
8. **🧪 Development/Testing** - Test AI integrations locally without incurring API costs.
9. **💰 Cost Savings** - Reduce expensive cloud API bills by routing routine tasks to free local models.
10. **📋 Compliance** - Meet GDPR, HIPAA, and data residency requirements by keeping AI processing in-jurisdiction.

## 🤝 Contributing

We welcome contributions! Please see our [CONTRIBUTING.md](docs/CONTRIBUTING.md) for details on our code of conduct, bug reporting, and pull request process. Note that all contributions require signing a Contributor License Agreement (CLA).

## 📄 License

This software is proprietary. See the [LICENSE](LICENSE) file for terms.
Copyright (c) 2025-2026 Eugene Beauzec. All Rights Reserved.

## 🙏 Acknowledgments

This project builds upon amazing open-source software:
- [Ollama](https://ollama.ai/)
- [Open WebUI](https://openwebui.com/)
- [LiteLLM](https://litellm.ai/)
- [SearXNG](https://docs.searxng.org/)
- [Docker](https://www.docker.com/)
