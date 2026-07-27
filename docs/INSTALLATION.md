# Installation Guide

Welcome to the LocalLLM Installation Guide. This document provides step-by-step instructions to get your local AI platform up and running on Windows.

## Prerequisites

Before starting, ensure your system meets the [System Requirements](../README.md#system-requirements). You will also need:
- Administrator privileges on your Windows machine
- Internet connection (for downloading dependencies and models)

## Step-by-Step Installation

1. **Clone the Repository**
   Open PowerShell and run:
   ```powershell
   git clone https://github.com/ebeauzec/LocalLLM.git
   cd LocalLLM
   ```

2. **Run the Installer**
   Execute the installation script:
   ```powershell
   .\install.ps1
   ```

3. **Follow On-Screen Prompts**
   The installer will transparently perform the following steps:
   - **Environment Check**: Verifies hardware, OS version, and required dependencies.
   - **Docker Setup**: Installs or configures Docker Desktop / WSL2 if necessary.
   - **Hardware Profiling**: Detects your CPU/RAM/GPU and selects the appropriate model tier.
   - **Container Deployment**: Pulls the Docker images for Ollama, LiteLLM, Open WebUI, and SearXNG.
   - **Model Download**: Downloads the optimal base models for your hardware.
   - **Health Verification**: Runs self-diagnostic checks to ensure all services are communicating properly.

### Expected Output
You should see a progress bar and detailed logs of each phase. Upon success, you will receive a URL (typically `http://localhost:3000`) to access the interface.

## GPU Setup for NVIDIA

For optimal performance, an NVIDIA GPU is recommended. The installer automatically configures Docker to use your GPU, but you must ensure you have the latest [NVIDIA Drivers](https://www.nvidia.com/Download/index.aspx) installed.
If Docker fails to utilize your GPU, verify that the NVIDIA Container Toolkit is correctly installed within your WSL2 backend.

## Silent/Unattended Installation

For enterprise or headless deployments, you can run the installer non-interactively:
```powershell
.\install.ps1 -Silent -AcceptEULA -Tier High
```
*(Check `.\install.ps1 -Help` for all available parameters)*

## Upgrading from a Previous Version

To update an existing installation to the latest version without losing your data:
```powershell
localllm update
```

## Uninstallation

To completely remove LocalLLM, including all containers, models, and user data:
```powershell
localllm uninstall
```
*Note: This action is irreversible. Ensure you have backed up any important chats or documents.*

## Troubleshooting Installation Issues

- **Docker Won't Start**: Ensure Virtualization is enabled in your BIOS/UEFI and WSL2 is properly installed.
- **Port Conflicts**: If ports 3000, 11434, 4000, or 8080 are in use, the installer will attempt to find alternative ports. Check the output logs for the assigned URLs.
- **Download Failures**: If model downloads fail, run `localllm repair` to retry.

For more detailed help, see the [Troubleshooting Guide](TROUBLESHOOTING.md).
