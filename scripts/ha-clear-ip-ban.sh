#!/usr/bin/env bash
set -euo pipefail

STACK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$STACK_DIR"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker client is required" >&2
  exit 1
fi

if ! docker compose ps homeassistant >/dev/null 2>&1; then
  echo "homeassistant container is not running. Start the stack first." >&2
  exit 1
fi

if docker compose exec -T homeassistant test -f /config/ip_bans.yaml; then
  docker compose exec -T homeassistant rm /config/ip_bans.yaml
  echo "Removed existing /config/ip_bans.yaml"
else
  echo "No ip_bans.yaml found; nothing to remove."
fi

docker compose exec -T homeassistant ha core restart
