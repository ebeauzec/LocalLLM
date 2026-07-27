#!/usr/bin/env bash
# Copyright (c) 2025-2026 Eugene Beauzec. All Rights Reserved.
# LocalLLM Uninstaller Script

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}WARNING: This will remove LocalLLM services, containers, and optionally data.${NC}"
echo "This will NOT remove Docker or system dependencies."
echo ""

read -p "Type 'UNINSTALL' to confirm: " CONFIRM

if [ "$CONFIRM" != "UNINSTALL" ]; then
    echo "Uninstall cancelled."
    exit 0
fi

read -p "Remove all downloaded models and chat history? (y/N): " REMOVE_DATA

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

if command_exists docker-compose; then
    DOCKER_COMPOSE="docker-compose"
elif docker compose version >/dev/null 2>&1; then
    DOCKER_COMPOSE="docker compose"
else
    DOCKER_COMPOSE=""
fi

if [ -n "$DOCKER_COMPOSE" ] && [ -f docker-compose.yml ]; then
    echo "Stopping and removing containers..."
    sudo $DOCKER_COMPOSE down -v
fi

if [[ "$REMOVE_DATA" =~ ^[Yy]$ ]]; then
    echo "Removing data directories..."
    sudo rm -rf ./data ./logs
    echo "Data removed."
else
    echo "Data preserved."
fi

echo -e "${GREEN}LocalLLM uninstalled successfully.${NC}"
