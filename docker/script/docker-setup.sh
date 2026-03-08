#!/usr/bin/env bash
# OpenClaw Docker One-Click Setup
# Usage: ./docker/docker-setup.sh
#
# Environment variables:
#   OPENCLAW_IMAGE           - Use remote image instead of building (e.g. ghcr.io/openclaw/openclaw:latest)
#   OPENCLAW_GATEWAY_PORT    - Gateway port (default: 18789)
#   OPENCLAW_GATEWAY_BIND    - Bind mode: lan/loopback (default: lan)
#   OPENCLAW_CONFIG_DIR      - Config directory (default: ~/.openclaw)
#   OPENCLAW_WORKSPACE_DIR   - Workspace directory (default: ~/.openclaw/workspace)

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$ROOT_DIR/docker-compose.yml"
IMAGE_NAME="${OPENCLAW_IMAGE:-openclaw:local}"

echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           OpenClaw Docker One-Click Setup                    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check dependencies
require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo -e "${RED}ERROR: $1 is required but not installed.${NC}" >&2
    exit 1
  fi
}

require_cmd docker
if ! docker compose version >/dev/null 2>&1; then
  echo -e "${RED}ERROR: Docker Compose v2 not available.${NC}" >&2
  echo "Try: docker compose version" >&2
  exit 1
fi

# Configuration
export OPENCLAW_CONFIG_DIR="${OPENCLAW_CONFIG_DIR:-$HOME/.openclaw}"
export OPENCLAW_WORKSPACE_DIR="${OPENCLAW_WORKSPACE_DIR:-$HOME/.openclaw/workspace}"
export OPENCLAW_GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-18789}"
export OPENCLAW_BRIDGE_PORT="${OPENCLAW_BRIDGE_PORT:-18790}"
export OPENCLAW_GATEWAY_BIND="${OPENCLAW_GATEWAY_BIND:-lan}"
export OPENCLAW_IMAGE="$IMAGE_NAME"

# Generate token if not set
if [[ -z "${OPENCLAW_GATEWAY_TOKEN:-}" ]]; then
  # Try to read from existing config
  config_file="$OPENCLAW_CONFIG_DIR/openclaw.json"
  if [[ -f "$config_file" ]] && command -v python3 >/dev/null 2>&1; then
    existing_token=$(python3 -c "
import json
try:
    with open('$config_file') as f:
        cfg = json.load(f)
    token = cfg.get('gateway', {}).get('auth', {}).get('token', '')
    if token:
        print(token)
except:
    pass
" 2>/dev/null || true)
    if [[ -n "$existing_token" ]]; then
      OPENCLAW_GATEWAY_TOKEN="$existing_token"
      echo -e "${GREEN}Reusing gateway token from config${NC}"
    fi
  fi
  
  # Generate new token if still not set
  if [[ -z "${OPENCLAW_GATEWAY_TOKEN:-}" ]]; then
    if command -v openssl >/dev/null 2>&1; then
      OPENCLAW_GATEWAY_TOKEN="$(openssl rand -hex 32)"
    else
      OPENCLAW_GATEWAY_TOKEN="$(python3 -c 'import secrets; print(secrets.token_hex(32))')"
    fi
    echo -e "${GREEN}Generated new gateway token${NC}"
  fi
fi
export OPENCLAW_GATEWAY_TOKEN

# Create directories
echo -e "${YELLOW}Creating directories...${NC}"
mkdir -p "$OPENCLAW_CONFIG_DIR"
mkdir -p "$OPENCLAW_WORKSPACE_DIR"
mkdir -p "$OPENCLAW_CONFIG_DIR/identity"
mkdir -p "$OPENCLAW_CONFIG_DIR/agents/main/agent"
mkdir -p "$OPENCLAW_CONFIG_DIR/agents/main/sessions"
mkdir -p "$OPENCLAW_CONFIG_DIR/logs"

# Write .env file
ENV_FILE="$ROOT_DIR/.env"
echo -e "${YELLOW}Writing .env file...${NC}"
cat > "$ENV_FILE" << EOF
OPENCLAW_CONFIG_DIR=$OPENCLAW_CONFIG_DIR
OPENCLAW_WORKSPACE_DIR=$OPENCLAW_WORKSPACE_DIR
OPENCLAW_GATEWAY_PORT=$OPENCLAW_GATEWAY_PORT
OPENCLAW_BRIDGE_PORT=$OPENCLAW_BRIDGE_PORT
OPENCLAW_GATEWAY_BIND=$OPENCLAW_GATEWAY_BIND
OPENCLAW_GATEWAY_TOKEN=$OPENCLAW_GATEWAY_TOKEN
OPENCLAW_IMAGE=$OPENCLAW_IMAGE
EOF

# Build or pull image
if [[ "$IMAGE_NAME" == "openclaw:local" ]]; then
  echo -e "${YELLOW}Building Docker image: $IMAGE_NAME${NC}"
  docker build -t "$IMAGE_NAME" -f "$ROOT_DIR/Dockerfile" "$ROOT_DIR"
else
  echo -e "${YELLOW}Pulling Docker image: $IMAGE_NAME${NC}"
  docker pull "$IMAGE_NAME"
fi

# Fix permissions
echo -e "${YELLOW}Fixing permissions...${NC}"
docker compose -f "$COMPOSE_FILE" run --rm --user root --entrypoint sh openclaw-gateway -c \
  'chown -R node:node /home/node/.openclaw 2>/dev/null || true'

# Run onboarding
echo ""
echo -e "${CYAN}==> Running onboarding (interactive)${NC}"
docker compose -f "$COMPOSE_FILE" --profile cli run --rm openclaw-cli onboard --mode local --no-install-daemon

# Start gateway
echo ""
echo -e "${CYAN}==> Starting gateway${NC}"
docker compose -f "$COMPOSE_FILE" up -d openclaw-gateway

# Summary
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    Setup Complete!                            ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Gateway URL:   ${CYAN}http://127.0.0.1:$OPENCLAW_GATEWAY_PORT${NC}"
echo -e "Config:        ${CYAN}$OPENCLAW_CONFIG_DIR${NC}"
echo -e "Workspace:     ${CYAN}$OPENCLAW_WORKSPACE_DIR${NC}"
echo -e "Token:         ${CYAN}$OPENCLAW_GATEWAY_TOKEN${NC}"
echo ""
echo -e "${YELLOW}Commands:${NC}"
echo "  docker compose logs -f openclaw-gateway     # View logs"
echo "  docker compose stop openclaw-gateway        # Stop gateway"
echo "  docker compose start openclaw-gateway       # Start gateway"
echo "  docker compose down                         # Remove containers"
echo ""
