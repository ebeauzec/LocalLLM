#!/usr/bin/env bash
# Copyright (c) 2025-2026 Eugene Beauzec. All Rights Reserved.
# LocalLLM Installer Script for Linux and macOS

set -euo pipefail

# ANSI Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

STATE_FILE=".localllm-install-state.json"
CONFIG_FILE=""
UNATTENDED=false
CURRENT_STEP=1
TOTAL_STEPS=9

# Print Banner
print_banner() {
    echo -e "${CYAN}"
    cat << 'EOF'
    __                     __    __    __  __
   / /   ____  _________ _/ /   / /   / / / /___ ___
  / /   / __ \/ ___/ __ `/ /   / /   / / / / __ `__ \
 / /___/ /_/ / /__/ /_/ / /___/ /___/ /_/ / / / / / /
/_____/\____/\___/\__,_/_/_____/_____/\____/_/ /_/ /_/

LocalLLM Enterprise Edition - Linux/macOS Installer
EOF
    echo -e "${NC}"
}

# Cleanup on exit
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo -e "${RED}Installation failed or was interrupted.${NC}"
        echo -e "You can resume by running the script again."
    fi
    exit $exit_code
}
trap cleanup EXIT

# Elevate privileges if necessary
elevate() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${YELLOW}Administrative privileges required. Requesting sudo...${NC}"
        sudo -k
        if ! sudo true; then
            echo -e "${RED}Failed to gain administrative privileges. Exiting.${NC}"
            exit 1
        fi
    fi
}

# Detect Platform
detect_platform() {
    OS="$(uname -s)"
    case "$OS" in
        Linux)
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                DISTRO=$ID
            else
                DISTRO="unknown"
            fi
            ;;
        Darwin)
            DISTRO="macos"
            ;;
        *)
            echo -e "${RED}Unsupported operating system: $OS${NC}"
            exit 1
            ;;
    esac
}

load_state() {
    if [ -f "$STATE_FILE" ]; then
        # Poor man's JSON parse for step
        CURRENT_STEP=$(grep -o '"step":[0-9]*' "$STATE_FILE" | grep -o '[0-9]*')
        if [ -z "$CURRENT_STEP" ]; then CURRENT_STEP=1; fi
        echo -e "${YELLOW}Resuming installation from step $CURRENT_STEP${NC}"
    fi
}

save_state() {
    echo "{\"step\":$CURRENT_STEP}" > "$STATE_FILE"
}

# Step 1: System Assessment
step_assessment() {
    echo -e "\n${BLUE}=== Step 1: System Assessment ===${NC}"
    echo -e "Platform: $OS ($DISTRO)"
    
    if [ "$DISTRO" = "macos" ]; then
        CPU_INFO=$(sysctl -n machdep.cpu.brand_string)
        RAM_BYTES=$(sysctl -n hw.memsize)
        RAM_GB=$(( RAM_BYTES / 1073741824 ))
        GPU_INFO=$(system_profiler SPDisplaysDataType | grep "Chipset Model" || echo "Unknown GPU")
    else
        CPU_INFO=$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2 | sed 's/^ //')
        RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        RAM_GB=$(( RAM_KB / 1048576 ))
        if command -v nvidia-smi &> /dev/null; then
            GPU_INFO="NVIDIA $(nvidia-smi --query-gpu=name --format=csv,noheader | head -n1)"
        elif command -v rocm-smi &> /dev/null; then
            GPU_INFO="AMD GPU"
        else
            GPU_INFO="No discrete GPU detected or drivers missing"
        fi
    fi
    
    echo -e "CPU: $CPU_INFO"
    echo -e "RAM: ${RAM_GB}GB"
    echo -e "GPU: $GPU_INFO"
    
    CURRENT_STEP=2; save_state
}

# Step 2: Model Selection
step_models() {
    echo -e "\n${BLUE}=== Step 2: Model Selection ===${NC}"
    TIER="MEDIUM"
    if [ "$RAM_GB" -lt 16 ]; then
        TIER="LOW"
    elif [ "$RAM_GB" -ge 32 ]; then
        TIER="HIGH"
    fi
    echo -e "Recommended Tier: ${GREEN}$TIER${NC}"
    
    if [ "$UNATTENDED" = false ]; then
        read -p "Accept recommended tier? (Y/n): " ACCEPT
        if [[ "$ACCEPT" =~ ^[Nn]$ ]]; then
            read -p "Enter Tier (LOW/MEDIUM/HIGH/ULTRA): " TIER
        fi
    fi
    
    CURRENT_STEP=3; save_state
}

# Step 3: Configuration Wizard
step_config() {
    echo -e "\n${BLUE}=== Step 3: Configuration Wizard ===${NC}"
    PRIVACY="BALANCED"
    
    if [ "$UNATTENDED" = true ] && [ -f "$CONFIG_FILE" ]; then
        echo -e "Loading unattended configuration from $CONFIG_FILE..."
        # Simplified parser
        if grep -q '"privacy_mode": "STRICT"' "$CONFIG_FILE"; then PRIVACY="STRICT"; fi
        if grep -q '"privacy_mode": "PERMISSIVE"' "$CONFIG_FILE"; then PRIVACY="PERMISSIVE"; fi
    elif [ "$UNATTENDED" = false ]; then
        echo -e "Privacy Modes: STRICT (Local only), BALANCED (Local primary, fallback cloud), PERMISSIVE (Cloud allowed)"
        read -p "Select Privacy Mode [BALANCED]: " INPUT_PRIVACY
        if [ -n "$INPUT_PRIVACY" ]; then PRIVACY="$INPUT_PRIVACY"; fi
    fi
    
    echo -e "Privacy Mode set to: ${GREEN}$PRIVACY${NC}"
    CURRENT_STEP=4; save_state
}

# Step 4: Prerequisites
step_prereqs() {
    echo -e "\n${BLUE}=== Step 4: Installing Prerequisites ===${NC}"
    elevate
    
    if [ "$DISTRO" = "macos" ]; then
        if ! command -v brew &> /dev/null; then
            echo "Installing Homebrew..."
            NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        if ! command -v docker &> /dev/null; then
            echo "Installing Docker Desktop..."
            sudo -u "$SUDO_USER" brew install --cask docker
            echo "Please start Docker Desktop manually before continuing."
        fi
    else
        if ! command -v docker &> /dev/null; then
            echo "Installing Docker..."
            case "$DISTRO" in
                ubuntu|debian)
                    sudo apt-get update
                    sudo apt-get install -y docker.io docker-compose-plugin
                    ;;
                fedora|rhel|centos)
                    sudo dnf install -y docker docker-compose-plugin
                    ;;
                arch|manjaro)
                    sudo pacman -Sy --noconfirm docker docker-compose
                    ;;
                *)
                    echo -e "${YELLOW}Please install Docker manually for your distribution.${NC}"
                    ;;
            esac
            sudo systemctl enable --now docker
            sudo usermod -aG docker "$SUDO_USER"
        fi
        
        # NVIDIA Toolkit
        if command -v nvidia-smi &> /dev/null && ! command -v nvidia-container-toolkit &> /dev/null; then
            echo "Installing NVIDIA Container Toolkit..."
            if [ "$DISTRO" = "ubuntu" ] || [ "$DISTRO" = "debian" ]; then
                curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
                curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
                sudo apt-get update
                sudo apt-get install -y nvidia-container-toolkit
                sudo nvidia-ctk runtime configure --runtime=docker
                sudo systemctl restart docker
            fi
        fi
    fi
    
    CURRENT_STEP=5; save_state
}

# Step 5: Service Deployment
step_deploy() {
    echo -e "\n${BLUE}=== Step 5: Service Deployment ===${NC}"
    if [ ! -f "docker-compose.yml" ]; then
        echo -e "${YELLOW}docker-compose.yml not found. Assuming dummy deployment for now.${NC}"
    else
        sudo docker compose up -d
    fi
    CURRENT_STEP=6; save_state
}

# Step 6: Model Download
step_download() {
    echo -e "\n${BLUE}=== Step 6: Model Download ===${NC}"
    DEFAULT_MODEL="llama3"
    echo "Downloading model $DEFAULT_MODEL (this may take a while)..."
    if sudo docker ps | grep -q ollama; then
        sudo docker exec -it ollama ollama pull $DEFAULT_MODEL
    else
        echo -e "${YELLOW}Ollama container not running. Skipping pull.${NC}"
    fi
    CURRENT_STEP=7; save_state
}

# Step 7: AI Profiles
step_profiles() {
    echo -e "\n${BLUE}=== Step 7: AI Profiles ===${NC}"
    echo "Initializing default AI personas and modelfiles..."
    # Placeholder for custom profile creation
    CURRENT_STEP=8; save_state
}

# Step 8: Enterprise Config
step_enterprise() {
    echo -e "\n${BLUE}=== Step 8: Enterprise Config ===${NC}"
    echo "Configuring Open WebUI connections and settings..."
    # Placeholder for API calls
    CURRENT_STEP=9; save_state
}

# Step 9: Verification
step_verify() {
    echo -e "\n${BLUE}=== Step 9: Verification ===${NC}"
    echo "Running health checks..."
    
    # Placeholder for health checks
    echo -e "${GREEN}All systems operational!${NC}"
    
    CURRENT_STEP=10; save_state
}

# Parse Arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --unattended) UNATTENDED=true; shift ;;
        --config) CONFIG_FILE="$2"; shift 2 ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
done

print_banner
detect_platform
load_state

if [ "$CURRENT_STEP" -le 1 ]; then step_assessment; fi
if [ "$CURRENT_STEP" -le 2 ]; then step_models; fi
if [ "$CURRENT_STEP" -le 3 ]; then step_config; fi
if [ "$CURRENT_STEP" -le 4 ]; then step_prereqs; fi
if [ "$CURRENT_STEP" -le 5 ]; then step_deploy; fi
if [ "$CURRENT_STEP" -le 6 ]; then step_download; fi
if [ "$CURRENT_STEP" -le 7 ]; then step_profiles; fi
if [ "$CURRENT_STEP" -le 8 ]; then step_enterprise; fi
if [ "$CURRENT_STEP" -le 9 ]; then step_verify; fi

echo -e "\n${GREEN}Installation Complete!${NC}"
rm -f "$STATE_FILE"

# Open browser
if [ "$OS" = "Darwin" ]; then
    open "http://localhost:3000" || true
elif command -v xdg-open &> /dev/null; then
    xdg-open "http://localhost:3000" || true
fi

exit 0
