#!/usr/bin/env bash
# ============================================================================
# Copyright (c) 2025-2026 Eugene Beauzec. All Rights Reserved.
# Project: LocalLLM - Self-Contained Local AI Platform
# File:    start.sh - One-Click Launcher
#
# Usage:
#   ./start.sh              Start LocalLLM (install if needed)
#   ./start.sh --stop       Graceful shutdown
#   ./start.sh --status     Check service status
#   ./start.sh --analytics  View cost savings
# ============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/config"
DATA_DIR="$SCRIPT_DIR/data"
COMPOSE_FILE="$CONFIG_DIR/docker-compose.yml"
VERSION_FILE="$SCRIPT_DIR/VERSION"
VERSION="unknown"
[ -f "$VERSION_FILE" ] && VERSION=$(cat "$VERSION_FILE" | tr -d '[:space:]')

# ── Quick actions ──
case "${1:-}" in
    --stop|-s)
        "$SCRIPT_DIR/localllm.sh" stop
        exit 0
        ;;
    --status)
        "$SCRIPT_DIR/localllm.sh" status
        exit 0
        ;;
    --analytics|-a)
        "$SCRIPT_DIR/localllm.sh" analytics
        exit 0
        ;;
    --uninstall)
        "$SCRIPT_DIR/localllm.sh" uninstall
        exit 0
        ;;
    --help|-h)
        echo -e "${CYAN}LocalLLM Launcher${NC}"
        echo ""
        echo "Usage: ./start.sh [option]"
        echo ""
        echo "Options:"
        echo "  (none)        Start LocalLLM (install if first run)"
        echo "  --stop, -s    Graceful shutdown, return resources"
        echo "  --status      Check if services are running"
        echo "  --analytics   View cost savings dashboard"
        echo "  --uninstall   Remove LocalLLM"
        echo "  --help, -h    Show this help"
        exit 0
        ;;
esac

# ── Banner ──
echo ""
echo -e "${CYAN}  ╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}  ║              LocalLLM v${VERSION}                       ║${NC}"
echo -e "${CYAN}  ║       Your Private AI — Running 100% Locally        ║${NC}"
echo -e "${CYAN}  ╚══════════════════════════════════════════════════════╝${NC}"
echo ""

# ── Auto-open browser ──
open_browser() {
    local url="$1"
    if command -v xdg-open &>/dev/null; then
        xdg-open "$url" &>/dev/null &
    elif command -v open &>/dev/null; then
        open "$url" &>/dev/null &
    else
        echo -e "${GRAY}  Open this URL in your browser: $url${NC}"
    fi
}

# ── Decision: Install or Start? ──
if [ ! -f "$COMPOSE_FILE" ] || [ ! -d "$DATA_DIR" ]; then
    # FIRST RUN
    echo -e "${YELLOW}  🔧 First time? Let's set everything up!${NC}"
    echo -e "${GRAY}     This will install Docker, download AI models,${NC}"
    echo -e "${GRAY}     and configure your private AI assistant.${NC}"
    echo ""
    echo -e "${GRAY}     Estimated time: 10-30 minutes (depends on internet speed)${NC}"
    echo ""
    
    read -p "  Press ENTER to start installation (or 'q' to quit): " confirm
    if [ "$confirm" = "q" ]; then
        echo -e "${YELLOW}  Cancelled.${NC}"
        exit 0
    fi
    
    chmod +x "$SCRIPT_DIR/install.sh" 2>/dev/null || true
    "$SCRIPT_DIR/install.sh"
    exit $?
fi

# ALREADY INSTALLED
echo -e "${GREEN}  ✅ LocalLLM is installed. Starting services...${NC}"
echo ""

# Check if already running
if docker compose -f "$COMPOSE_FILE" --project-directory "$SCRIPT_DIR" ps -q 2>/dev/null | grep -q .; then
    if curl -sf http://localhost:3000/health &>/dev/null; then
        echo -e "${GREEN}  🟢 Services are already running!${NC}"
        echo ""
        open_browser "http://localhost:3000"
        echo -e "${CYAN}  🌐 Opened: http://localhost:3000${NC}"
        echo ""
        echo -e "${GRAY}  Your conversations, uploads, and settings are all here.${NC}"
        echo -e "${GRAY}  To stop:       ./start.sh --stop${NC}"
        echo -e "${GRAY}  To analytics:  ./start.sh --analytics${NC}"
        echo ""
        exit 0
    fi
fi

# Start services
chmod +x "$SCRIPT_DIR/localllm.sh" 2>/dev/null || true
"$SCRIPT_DIR/localllm.sh" start

echo ""
echo -e "${GREEN}  ╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}  ║              LocalLLM is Ready!                     ║${NC}"
echo -e "${GREEN}  ╚══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  📝 All your conversations persist between sessions."
echo -e "  📁 Uploaded documents stay in your knowledge base."
echo -e "  🧠 AI picks up exactly where you left off."
echo ""
echo -e "${CYAN}  Quick Commands:${NC}"
echo -e "${GRAY}    ./start.sh              Start & open browser${NC}"
echo -e "${GRAY}    ./start.sh --stop       Graceful shutdown${NC}"
echo -e "${GRAY}    ./start.sh --status     Check service status${NC}"
echo -e "${GRAY}    ./start.sh --analytics  View cost savings${NC}"
echo ""
