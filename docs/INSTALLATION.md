# Installation Guide

Welcome to the LocalLLM Installation Guide. This document provides step-by-step instructions to get your local AI platform up and running.

## Prerequisites

Before starting, ensure your system meets the requirements. You will also need:
- Administrator privileges
- Internet connection (for downloading dependencies and models)
- Docker Desktop or Docker Engine installed

## Google Drive Deployment Notes

LocalLLM now fully supports being installed and run directly from Google Drive folders (e.g., `G:\My Drive\LocalLLM`). 
By utilizing **named Docker volumes** instead of host bind mounts, we avoid file locking and syncing conflicts common with cloud storage providers.

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
   The installer will handle hardware profiling, Docker setup, volume creation, and model downloading.

### Expected Output
Upon success, you will receive a URL (`http://localhost:3100`) to access the interface. The default port is now 3100 to avoid conflicts with other development servers.

## Managing the Deployment

To start the platform for daily use:
```powershell
.\start.ps1
```

**IMPORTANT**: To ensure data consistency, always shut down the platform using the new stop script:
```powershell
.\stop.ps1
```
This script performs a graceful shutdown, flushing databases and releasing resources safely.

## GPU Setup for NVIDIA

For optimal performance, an NVIDIA GPU is recommended. The installer automatically configures Docker to use your GPU. Ensure you have the latest NVIDIA Drivers installed.

## Silent/Unattended Installation

For enterprise or headless deployments:
```powershell
.\install.ps1 -Silent -AcceptEULA -Tier High
```

## Troubleshooting Installation Issues

- **Port Conflicts**: If port 3100 is in use, the installer will attempt to find alternative ports. Check the output logs.
- **Docker Won't Start**: Ensure Virtualization is enabled in your BIOS/UEFI.
- **Drive Sync Errors**: Ensure you are using the latest version of LocalLLM which uses named volumes to avoid these errors.

---
Copyright (c) 2025-2026 Eugene Beauzec. All Rights Reserved.
