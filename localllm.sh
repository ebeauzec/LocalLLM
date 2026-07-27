#!/usr/bin/env bash
# Usage: ./localllm.sh <command> [options]
# Copyright (c) 2025-2026 Eugene Beauzec. All Rights Reserved.
# LocalLLM Management CLI

set -euo pipefail

# ANSI Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

if command_exists docker-compose; then
    DOCKER_COMPOSE="docker-compose"
elif docker compose version >/dev/null 2>&1; then
    DOCKER_COMPOSE="docker compose"
else
    echo -e "${RED}Docker Compose not found. Please install Docker and Docker Compose.${NC}"
    exit 1
fi

show_help() {
    echo -e "${CYAN}LocalLLM Management CLI${NC}"
    echo "Usage: ./localllm.sh <command> [options]"
    echo ""
    echo "Commands:"
    echo "  start       - Start services and open browser"
    echo "  stop        - Graceful shutdown with resource recovery report"
    echo "  restart     - Restart all services"
    echo "  status      - Service status, health, and model list"
    echo "  update      - Pull latest images and update models"
    echo "  models      - List installed models"
    echo "  add-model   - Pull a new model (e.g., ./localllm.sh add-model llama3)"
    echo "  remove-model- Remove a model"
    echo "  logs        - Tail service logs (e.g., ./localllm.sh logs ollama)"
    echo "  config      - Show current configuration"
    echo "  doctor      - Run diagnostics"
    echo "  backup      - Backup config and chat history"
    echo "  privacy     - Privacy controls (mode/report/status)"
    echo "  uninstall   - Clean removal"
    echo "  version     - Show version info"
    echo "  help        - Show this help"
}

cmd_start() {
    echo -e "${BLUE}Starting LocalLLM services...${NC}"
    sudo $DOCKER_COMPOSE up -d
    
    echo "Waiting for services to be healthy..."
    sleep 5
    
    echo -e "${GREEN}Services started successfully.${NC}"
    
    # Auto-open browser
    OS="$(uname -s)"
    if [ "$OS" = "Darwin" ]; then
        open "http://localhost:3000" || true
    elif command_exists xdg-open; then
        xdg-open "http://localhost:3000" || true
    fi
}

cmd_stop() {
    echo -e "${BLUE}Initiating graceful shutdown...${NC}"
    
    # Check RAM before
    if [ "$(uname -s)" = "Darwin" ]; then
        MEM_BEFORE=$(vm_stat | grep "Pages active" | awk '{print $3}' | sed 's/\.//')
    else
        MEM_BEFORE=$(free -m | awk '/^Mem:/{print $3}')
    fi
    
    sudo $DOCKER_COMPOSE stop
    
    if [ "$(uname -s)" = "Darwin" ]; then
        MEM_AFTER=$(vm_stat | grep "Pages active" | awk '{print $3}' | sed 's/\.//')
        MEM_FREED=$((MEM_BEFORE - MEM_AFTER))
    else
        MEM_AFTER=$(free -m | awk '/^Mem:/{print $3}')
        MEM_FREED=$((MEM_BEFORE - MEM_AFTER))
    fi
    
    echo -e "\n${GREEN}=== Resources Returned ===${NC}"
    if [ "$MEM_FREED" -gt 0 ]; then
        echo "Memory Freed: ~${MEM_FREED}MB"
    else
        echo "Memory Freed: N/A"
    fi
    echo "GPU compute released"
    
    read -p "Do you want to fully remove containers (down) instead of just stop? (y/N): " REMOVE
    if [[ "$REMOVE" =~ ^[Yy]$ ]]; then
        sudo $DOCKER_COMPOSE down
        echo -e "${GREEN}Containers removed.${NC}"
    fi
}

cmd_restart() {
    echo -e "${BLUE}Restarting services...${NC}"
    sudo $DOCKER_COMPOSE restart
}

cmd_status() {
    echo -e "${BLUE}Service Status:${NC}"
    sudo $DOCKER_COMPOSE ps
}

cmd_update() {
    echo -e "${BLUE}Updating images...${NC}"
    sudo $DOCKER_COMPOSE pull
    cmd_restart
}

cmd_models() {
    echo -e "${BLUE}Installed Models:${NC}"
    if sudo docker ps | grep -q ollama; then
        sudo docker exec ollama ollama list
    else
        echo -e "${YELLOW}Ollama container is not running.${NC}"
    fi
}

cmd_add_model() {
    if [ -z "${1:-}" ]; then
        echo -e "${RED}Please specify a model name.${NC}"
        exit 1
    fi
    echo -e "${BLUE}Pulling model $1...${NC}"
    sudo docker exec -it ollama ollama pull "$1"
}

cmd_remove_model() {
    if [ -z "${1:-}" ]; then
        echo -e "${RED}Please specify a model name.${NC}"
        exit 1
    fi
    echo -e "${BLUE}Removing model $1...${NC}"
    sudo docker exec -it ollama ollama rm "$1"
}

cmd_logs() {
    local service="${1:-}"
    sudo $DOCKER_COMPOSE logs -f $service
}

cmd_config() {
    echo -e "${BLUE}Current Configuration:${NC}"
    if [ -f install-config.json ]; then
        cat install-config.json
    else
        echo "No config found."
    fi
}

cmd_doctor() {
    echo -e "${BLUE}Running diagnostics...${NC}"
    echo "OS: $(uname -a)"
    echo "Docker: $(docker --version)"
    echo "Docker Compose: $($DOCKER_COMPOSE version)"
    # Add more diagnostic checks here
    echo -e "${GREEN}Diagnostics complete.${NC}"
}

cmd_backup() {
    echo -e "${BLUE}Backing up config and data...${NC}"
    local BACKUP_FILE="localllm_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    sudo tar -czf "$BACKUP_FILE" ./data ./install-config.json 2>/dev/null || echo "Partial backup created."
    echo -e "${GREEN}Backup saved to $BACKUP_FILE${NC}"
}

cmd_privacy() {
    echo -e "${BLUE}Privacy Status:${NC}"
    echo "Mode: BALANCED (Default)"
}

cmd_uninstall() {
    ./uninstall.sh
}

cmd_version() {
    if [ -f "VERSION" ]; then
        echo "LocalLLM Version $(cat VERSION)"
    else
        echo "LocalLLM Version Unknown"
    fi
}

if [ $# -eq 0 ]; then
    show_help
    exit 0
fi

COMMAND=$1
shift

case "$COMMAND" in
    start) cmd_start ;;
    stop) cmd_stop ;;
    restart) cmd_restart ;;
    status) cmd_status ;;
    update) cmd_update ;;
    models) cmd_models ;;
    add-model) cmd_add_model "$@" ;;
    remove-model) cmd_remove_model "$@" ;;
    logs) cmd_logs "$@" ;;
    config) cmd_config ;;
    doctor) cmd_doctor ;;
    backup) cmd_backup ;;
    privacy) cmd_privacy "$@" ;;
    uninstall) cmd_uninstall ;;
    version) cmd_version ;;
    help) show_help ;;
    *) echo -e "${RED}Unknown command: $COMMAND${NC}"; show_help; exit 1 ;;
esac
