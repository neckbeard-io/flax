#!/usr/bin/env bash
#
# flax — standalone uninstaller for macOS and Linux
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/neckbeard-io/flax/main/tool/uninstall.sh | bash
#   ./tool/uninstall.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"

if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/install.sh" ]; then
  exec "$SCRIPT_DIR/install.sh" --uninstall "$@"
fi

# Fallback standalone uninstaller logic if executed via curl pipe
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  BOLD=$'\033[1m'
  BLUE=$'\033[0;34m'
  GREEN=$'\033[0;32m'
  YELLOW=$'\033[0;33m'
  CYAN=$'\033[0;36m'
  RED=$'\033[0;31m'
  NC=$'\033[0m'
else
  BOLD=""
  BLUE=""
  GREEN=""
  YELLOW=""
  CYAN=""
  RED=""
  NC=""
fi

info() { printf "${BLUE}${BOLD}==>${NC} %s\n" "$*"; }
step() { printf "  ${CYAN}•${NC} %s\n" "$*"; }
success() { printf "${GREEN}${BOLD}✓${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}${BOLD}!${NC} %s\n" "$*"; }
error() { printf "${RED}${BOLD}✗ Error:${NC} %s\n" "$*" >&2; }

info "${BOLD}Flax Uninstaller${NC}"

os="$(uname -s)"
if [ "$os" = "Darwin" ]; then
  removed=0
  for app in "/Applications/flax.app" "${HOME}/Applications/flax.app"; do
    if [ -d "$app" ]; then
      step "Removing ${app}..."
      if [ -w "$app" ] || [ -w "$(dirname "$app")" ]; then
        rm -rf "$app"
      else
        sudo rm -rf "$app"
      fi
      removed=1
    fi
  done

  if [ "$removed" = 1 ]; then
    success "Flax application removed successfully."
  else
    warn "Flax was not found in /Applications or ~/Applications."
  fi
elif [ "$os" = "Linux" ]; then
  step "Removing standalone Flax installation..."
  rm -rf "${HOME}/.local/share/flax" \
         "${HOME}/.local/bin/flax" \
         "${HOME}/.local/share/applications/flax.desktop" \
         "${HOME}/.local/share/icons/hicolor/512x512/apps/flax.png" \
         "${HOME}/.local/share/pixmaps/flax.png"
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "${HOME}/.local/share/applications" >/dev/null 2>&1 || true
  fi
  success "Flax standalone installation removed successfully."
else
  error "Unsupported operating system: $os"
  exit 1
fi
