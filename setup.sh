#!/usr/bin/env bash
# =============================================================================
# setup.sh — Media Stack bootstrap script (Linux / macOS)
# =============================================================================
# Usage: chmod +x setup.sh && ./setup.sh
# =============================================================================
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warning() { echo -e "${YELLOW}[WARN]${NC}  $*"; }

# -----------------------------------------------------------------------------
# 1. Create directory structure
# -----------------------------------------------------------------------------
info "Creating directory structure..."

dirs=(
  "config/gluetun"
  "config/qbittorrent"
  "config/prowlarr"
  "config/radarr"
  "config/sonarr"
  "config/jellyseerr"
  "config/jellyfin"
  "config/recommendarr"
  "media/movies"
  "media/tv"
  "media/downloads/complete"
  "media/downloads/incomplete"
)

for dir in "${dirs[@]}"; do
  mkdir -p "$dir"
  info "  Created: $dir"
done

# -----------------------------------------------------------------------------
# 2. Copy .env.example → .env
# -----------------------------------------------------------------------------
if [ ! -f ".env" ]; then
  cp .env.example .env
  info ".env created — open it and fill in your VPN credentials and paths."
else
  warning ".env already exists, skipping copy."
fi

# -----------------------------------------------------------------------------
# 3. Set permissions on media dirs (Linux only)
# -----------------------------------------------------------------------------
if [[ "$(uname)" != "Darwin" ]]; then
  PUID_VAL=$(grep -E "^PUID=" .env | cut -d= -f2)
  PGID_VAL=$(grep -E "^PGID=" .env | cut -d= -f2)
  if [ -n "$PUID_VAL" ] && [ -n "$PGID_VAL" ]; then
    info "Setting ownership of media/ and config/ to $PUID_VAL:$PGID_VAL ..."
    chown -R "${PUID_VAL}:${PGID_VAL}" media/ config/ 2>/dev/null || \
      warning "Could not chown directories. Run manually: sudo chown -R $PUID_VAL:$PGID_VAL media/ config/"
  fi
fi

# -----------------------------------------------------------------------------
# 4. Check Docker is available
# -----------------------------------------------------------------------------
if ! command -v docker &>/dev/null; then
  warning "Docker not found. Install Docker Desktop: https://docs.docker.com/get-docker/"
fi

if ! docker compose version &>/dev/null 2>&1; then
  warning "Docker Compose plugin not found. Update Docker Desktop or install the plugin."
fi

# -----------------------------------------------------------------------------
echo ""
info "Setup complete!"
echo ""
echo "  Next steps:"
echo "  1. Edit .env  — add your VPN credentials and adjust paths/ports"
echo "  2. docker compose up -d   — start all services"
echo "  3. Open the service URLs listed in README.md"
echo ""
