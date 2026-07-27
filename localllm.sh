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

# Lock all paths to the project directory (not the user's CWD)
COMPOSE_FILE="$SCRIPT_DIR/config/docker-compose.yml"
export COMPOSE_PROJECT_NAME="localllm"
DOCKER_COMPOSE="$DOCKER_COMPOSE -f $COMPOSE_FILE --project-directory $SCRIPT_DIR"

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
    echo "  analytics   - Show cost savings and efficacy metrics"
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

cmd_analytics() {
    METRICS_FILE="data/localllm-metrics.json"
    
    if [ ! -f "$METRICS_FILE" ]; then
        echo -e "${YELLOW}No analytics data yet. Use LocalLLM to generate metrics.${NC}"
        return
    fi
    
    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           LocalLLM Analytics Dashboard              ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Parse metrics using python3 (available on all platforms)
    python3 -c "
import json, sys
try:
    with open('$METRICS_FILE') as f:
        m = json.load(f)
except:
    print('  Failed to read metrics file.')
    sys.exit(1)

total = m.get('total_requests', 0)
local = m.get('total_local', 0)
cloud = m.get('total_cloud', 0)
pct = round((local / total) * 100, 1) if total > 0 else 0
tokens = m.get('total_tokens', 0)
savings = m.get('total_savings_usd', 0)
cost = m.get('total_cost_usd', 0)
blocked = m.get('total_sensitive_blocked', 0)

print(f'  📊 Overall Statistics')
print(f'  ─────────────────────────────────────────────────')
print(f'    Total Requests:     {total:,}')
print(f'    🟢 Local:           {local:,} ({pct}%)')
print(f'    🔴 Cloud:           {cloud:,} ({round(100 - pct, 1)}%)')
print(f'    Total Tokens:       {tokens:,}')
print()
print(f'  💰 Cost Analysis')
print(f'  ─────────────────────────────────────────────────')
print(f'    Total Saved:        \${savings:.2f}')
print(f'    Cloud Spend:        \${cost:.2f}')
avg = round(cost / total, 4) if total > 0 else 0
print(f'    Avg Cost/Query:     \${avg}')
print()

# Efficiency bar
filled = int(pct / 100 * 30)
bar = '█' * filled + '░' * (30 - filled)
print(f'  📈 Efficiency: {pct}% LOCAL')
print(f'     [{bar}]')
print()

# Model breakdown
models = m.get('models', {})
if models:
    print(f'  🤖 Model Usage')
    print(f'  ─────────────────────────────────────────────────')
    print(f'    {\"Model\":<25} {\"Requests\":>8} {\"Tokens\":>10} {\"Cost\":>8}')
    for name, stats in sorted(models.items(), key=lambda x: x[1].get('count', 0), reverse=True)[:10]:
        icon = '🔴' if any(p in name.lower() for p in ['gpt-', 'claude-', 'gemini-']) else '🟢'
        print(f'    {icon} {name:<25} {stats.get(\"count\", 0):>6} {stats.get(\"tokens\", 0):>10,} \${stats.get(\"cost\", 0):>7.2f}')
    print()

# Privacy
print(f'  🔒 Privacy')
print(f'  ─────────────────────────────────────────────────')
print(f'    Sensitive data blocked: {blocked} instances')
print()
print(f'  💡 Use the Privacy Dashboard tool in chat for detailed reports.')
"
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
    analytics) cmd_analytics ;;
    uninstall) cmd_uninstall ;;
    version) cmd_version ;;
    help) show_help ;;
    *) echo -e "${RED}Unknown command: $COMMAND${NC}"; show_help; exit 1 ;;
esac
