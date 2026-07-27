# Troubleshooting Guide

This guide helps you resolve common issues with LocalLLM.

## Common Issues & Solutions

| Issue | Cause | Solution |
| ----- | ----- | -------- |
| **"Connection Refused" when opening UI** | Containers are not running | Run `localllm status`. If stopped, run `localllm start`. |
| **Models respond very slowly** | Model running on CPU instead of GPU | Ensure NVIDIA drivers are installed. Verify Docker is configured to use the GPU. Check `localllm status` to see if GPU is detected. |
| **Out of Memory (OOM) Errors** | Model is too large for your RAM/VRAM | Switch to a smaller model tier. Restart the stack: `localllm stop` then `localllm start`. |
| **Web Search fails** | SearXNG container issue | Check if port 8080 is blocked. Run `localllm repair`. |

## Docker Issues

### Won't Start
- **WSL2 Integration**: If Docker Desktop is stuck starting on Windows, ensure WSL2 is set as the default version (`wsl --set-default-version 2`) and update your Linux kernel.
- **Virtualization**: Ensure Hardware Virtualization is enabled in your BIOS/UEFI.

### GPU Not Detected
- Ensure you have installed the [NVIDIA CUDA Toolkit](https://developer.nvidia.com/cuda-downloads).
- Check if Docker can access the GPU: Run `docker run --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi`.

## Model Issues

### Download Fails
If Ollama fails to pull a model (e.g., connection drop):
1. Run `localllm repair`.
2. Or manually pull: `docker exec -it localllm-ollama ollama pull <model-name>`.

## Network Issues

### Port Conflicts
If you have other services running on ports `3000`, `4000`, `8080`, or `11434`, LocalLLM might fail to start.
**Fix**: Edit the `.env` file in the project root to change the exposed ports, then run `localllm start`.

## Collecting Logs for Bug Reports

If you encounter an issue that requires support, collect the diagnostic logs:
```powershell
localllm logs --export
```
This will generate a `localllm-diagnostics.zip` file which you can attach to your bug report.

## FAQ

**Q: Can I access LocalLLM from another device on my network?**
A: Yes. By default, it binds to `0.0.0.0`. Access it via `http://<YOUR_WINDOWS_IP>:3000` from another device. Ensure your Windows Firewall allows inbound traffic on port 3000.

**Q: How do I completely reset the environment?**
A: Run `localllm uninstall`, then reinstall using `.\install.ps1`.
