#!/usr/bin/env bash
#
# flax — standalone installer for macOS and Linux
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/neckbeard-io/flax/main/tool/install.sh | bash
#
# Options (via environment or arguments):
#   --version <v>     Install a specific version (e.g. 0.5.0)
#   --dir <path>      Custom install directory
#   --no-launch       Do not launch Flax after installation
#   --verbose         Enable verbose output
#   --help, -h        Show help message
#
# This script installs Flax as a standalone application rather than through
# package managers, enabling direct in-app self-updating via the update pill.

set -euo pipefail

# ── Formatting & Colors ───────────────────────────────────────────────

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  BOLD=$'\033[1m'
  DIM=$'\033[2m'
  BLUE=$'\033[0;34m'
  GREEN=$'\033[0;32m'
  YELLOW=$'\033[0;33m'
  RED=$'\033[0;31m'
  CYAN=$'\033[0;36m'
  NC=$'\033[0m' # No Color
else
  BOLD=""
  DIM=""
  BLUE=""
  GREEN=""
  YELLOW=""
  RED=""
  CYAN=""
  NC=""
fi

info() {
  printf "${BLUE}${BOLD}==>${NC} %s\n" "$*"
}

step() {
  printf "  ${CYAN}•${NC} %s\n" "$*"
}

success() {
  printf "${GREEN}${BOLD}✓${NC} %s\n" "$*"
}

warn() {
  printf "${YELLOW}${BOLD}!${NC} %s\n" "$*"
}

error() {
  printf "${RED}${BOLD}✗ Error:${NC} %s\n" "$*" >&2
}

# ── Global State & Cleanup Trap ───────────────────────────────────────

TMP_DIR=""
MOUNT_POINT=""

cleanup() {
  local exit_code=$?
  if [ -n "$MOUNT_POINT" ] && [ -d "$MOUNT_POINT" ]; then
    hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
  fi
  if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
    rm -rf "$TMP_DIR"
  fi
  exit "$exit_code"
}

trap cleanup EXIT INT TERM

# ── Argument Parsing ──────────────────────────────────────────────────

show_help() {
  cat <<EOF
${BOLD}flax installer${NC}
High-fidelity music player for Subsonic / Navidrome servers.

${BOLD}USAGE:${NC}
  curl -fsSL https://raw.githubusercontent.com/neckbeard-io/flax/main/tool/install.sh | bash
  ./tool/install.sh [OPTIONS]

${BOLD}OPTIONS:${NC}
  --version <v>   Install a specific release version (default: latest)
  --dir <path>    Custom destination directory
  --no-launch     Do not launch Flax after installation
  --verbose       Show verbose download output
  --uninstall     Uninstall standalone Flax installation
  -h, --help      Show this help message

EOF
  exit 0
}

# ── Uninstallation Logic ───────────────────────────────────────────────

do_uninstall() {
  info "${BOLD}Flax Uninstaller${NC}"
  local os
  os="$(uname -s)"

  if [ "$os" = "Darwin" ]; then
    local target_app="/Applications/flax.app"
    [ -d "$HOME/Applications/flax.app" ] && target_app="$HOME/Applications/flax.app"
    if [ -d "$target_app" ]; then
      step "Removing ${target_app}..."
      rm -rf "$target_app"
      success "Flax removed successfully."
    else
      warn "Flax application was not found in /Applications or ~/Applications."
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
  exit 0
}

# ── Version Resolution ────────────────────────────────────────────────

resolve_latest_version() {
  local tag=""

  # GitHub's /releases/latest only returns non-prerelease releases.
  # All flax builds are marked pre-release, so we use /releases?per_page=1
  # which returns all releases (newest first) regardless of pre-release flag.
  tag=$(curl -sSL -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/neckbeard-io/flax/releases?per_page=1" 2>/dev/null \
    | grep -m1 '"tag_name":' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/' || true)

  # Fallback: resolve via the tags page redirect (works without API access)
  if [ -z "$tag" ] || ! echo "$tag" | grep -qE '^v?[0-9]+\.[0-9]+'; then
    tag=$(curl -sSI "https://github.com/neckbeard-io/flax/releases/tag/latest" 2>/dev/null \
      | grep -i '^location:' \
      | grep '/tag/' \
      | sed -E 's|.*/tag/([^\r\n/]+).*|\1|' \
      | tr -d '[:space:]' \
      | head -n 1 || true)
  fi

  # Validate — must look like a version number
  if [ -z "$tag" ] || ! echo "$tag" | grep -qE '^v?[0-9]+\.[0-9]+'; then
    error "Could not determine the latest Flax release. Use --version <v> to specify one."
    exit 1
  fi

  # Strip leading 'v'
  echo "${tag#v}"
}

# ── Main Installation Logic ───────────────────────────────────────────

main() {
  local version=""
  local custom_dir=""
  local no_launch=0
  local verbose=0

  while [ $# -gt 0 ]; do
    case "$1" in
      --version)
        shift
        version="${1:-}"
        ;;
      --dir)
        shift
        custom_dir="${1:-}"
        ;;
      --no-launch)
        no_launch=1
        ;;
      --verbose)
        verbose=1
        ;;
      --uninstall)
        do_uninstall
        ;;
      -h|--help)
        show_help
        ;;
      *)
        warn "Unknown argument: $1"
        ;;
    esac
    shift || true
  done

  info "${BOLD}Flax Installer${NC}"

  # Detect OS & Architecture
  local os
  local arch
  os="$(uname -s)"
  arch="$(uname -m)"

  case "$os" in
    Darwin)
      step "Detected platform: ${BOLD}macOS ($arch)${NC} (Universal binary)"
      ;;
    Linux)
      if [ "$arch" != "x86_64" ] && [ "$arch" != "amd64" ]; then
        error "Flax Linux pre-built packages currently support x86_64. Detected: $arch"
        exit 1
      fi
      step "Detected platform: ${BOLD}Linux ($arch)${NC}"
      ;;
    CYGWIN*|MINGW*|MSYS*|Windows_NT)
      error "Windows detected. For Windows, download and run the installer: https://github.com/neckbeard-io/flax/releases/latest"
      exit 1
      ;;
    *)
      error "Unsupported operating system: $os"
      exit 1
      ;;
  esac

  # Resolve target version
  if [ -z "$version" ]; then
    step "Checking latest release..."
    version=$(resolve_latest_version)
  fi
  version="${version#v}" # normalize

  step "Selected version: ${BOLD}v${version}${NC}"

  # Create temp workspace
  TMP_DIR=$(mktemp -d /tmp/flax-installer.XXXXXX)

  # Download progress settings
  local curl_opts=(-fL)
  if [ "$verbose" = 1 ]; then
    curl_opts+=(-v)
  elif [ -t 1 ]; then
    curl_opts+=(--progress-bar)
  else
    curl_opts+=(-sS)
  fi

  if [ "$os" = "Darwin" ]; then
    install_macos "$version" "$custom_dir" "$no_launch" "${curl_opts[@]}"
  elif [ "$os" = "Linux" ]; then
    install_linux "$version" "$custom_dir" "$no_launch" "${curl_opts[@]}"
  fi
}

# ── macOS Installer ───────────────────────────────────────────────────

install_macos() {
  local version="$1"
  local custom_dir="$2"
  local no_launch="$3"
  shift 3
  local curl_opts=("$@")

  local dmg_name="flax-${version}-macos-universal.dmg"
  local dmg_url="https://github.com/neckbeard-io/flax/releases/download/v${version}/${dmg_name}"
  local dmg_path="${TMP_DIR}/${dmg_name}"

  info "Downloading Flax ${BOLD}v${version}${NC} for macOS..."
  if ! curl "${curl_opts[@]}" "$dmg_url" -o "$dmg_path"; then
    error "Failed to download ${dmg_url}"
    exit 1
  fi

  # Determine target directory
  local target_dir="/Applications"
  if [ -n "$custom_dir" ]; then
    target_dir="$custom_dir"
  elif [ ! -w "/Applications" ]; then
    target_dir="$HOME/Applications"
  fi
  mkdir -p "$target_dir"

  local target_app="${target_dir}/flax.app"

  info "Mounting disk image..."
  MOUNT_POINT="${TMP_DIR}/mnt"
  mkdir -p "$MOUNT_POINT"
  hdiutil attach "$dmg_path" -nobrowse -readonly -mountpoint "$MOUNT_POINT" -quiet

  if [ ! -d "${MOUNT_POINT}/flax.app" ]; then
    error "flax.app not found inside DMG"
    exit 1
  fi

  info "Installing to ${BOLD}${target_app}${NC}..."
  rm -rf "$target_app"
  cp -R "${MOUNT_POINT}/flax.app" "$target_dir/"

  # Detach mountpoint
  hdiutil detach "$MOUNT_POINT" -quiet
  MOUNT_POINT=""

  step "Clearing macOS quarantine attribute..."
  xattr -dr com.apple.quarantine "$target_app" 2>/dev/null || true

  success "Flax v${version} installed successfully to ${target_app}"
  printf "\n"
  printf "  ${DIM}Flax is installed as a standalone app and will self-update via the in-app update pill.${NC}\n"
  printf "\n"

  if [ "$no_launch" = 0 ] && [ -t 1 ]; then
    step "Launching Flax..."
    open "$target_app"
  fi
}

# ── Linux Installer ───────────────────────────────────────────────────

install_linux() {
  local version="$1"
  local custom_dir="$2"
  local no_launch="$3"
  shift 3
  local curl_opts=("$@")

  local tar_name="flax-${version}-linux-x64.tar.gz"
  local tar_url="https://github.com/neckbeard-io/flax/releases/download/v${version}/${tar_name}"
  local tar_path="${TMP_DIR}/${tar_name}"

  info "Downloading Flax ${BOLD}v${version}${NC} for Linux (x86_64)..."
  if ! curl "${curl_opts[@]}" "$tar_url" -o "$tar_path"; then
    error "Failed to download ${tar_url}"
    exit 1
  fi

  # Determine target directory
  local target_dir="${HOME}/.local/share/flax"
  if [ -n "$custom_dir" ]; then
    target_dir="$custom_dir"
  fi

  local bin_dir="${HOME}/.local/bin"
  local desktop_dir="${HOME}/.local/share/applications"
  local icons_dir="${HOME}/.local/share/icons/hicolor/512x512/apps"
  local pixmaps_dir="${HOME}/.local/share/pixmaps"
  mkdir -p "$target_dir" "$bin_dir" "$desktop_dir" "$icons_dir" "$pixmaps_dir"

  info "Extracting to ${BOLD}${target_dir}${NC}..."
  # Clean old binary contents if upgrading
  find "$target_dir" -mindepth 1 -delete 2>/dev/null || true
  tar -xzf "$tar_path" -C "$target_dir"

  # Ensure executable permission
  chmod +x "$target_dir/flax"

  # Create symlink in ~/.local/bin
  info "Linking executable to ${BOLD}${bin_dir}/flax${NC}..."
  ln -sf "$target_dir/flax" "$bin_dir/flax"

  # Extract and place application icon if present in bundle
  local icon_source=""
  if [ -f "$target_dir/flax.png" ]; then
    icon_source="$target_dir/flax.png"
  elif [ -f "$target_dir/data/flutter_assets/assets/flax.png" ]; then
    icon_source="$target_dir/data/flutter_assets/assets/flax.png"
  elif [ -f "$target_dir/data/flutter_assets/assets/flax_logo.svg" ]; then
    icon_source="$target_dir/data/flutter_assets/assets/flax_logo.svg"
  fi

  if [ -n "$icon_source" ]; then
    cp -f "$icon_source" "$icons_dir/flax.png" 2>/dev/null || true
    cp -f "$icon_source" "$pixmaps_dir/flax.png" 2>/dev/null || true
  fi

  # Create desktop launcher
  info "Creating desktop entry..."
  cat > "$desktop_dir/flax.desktop" <<EOF
[Desktop Entry]
Name=Flax
GenericName=Music Player
Comment=High-fidelity Subsonic and Navidrome music player
Exec=${bin_dir}/flax %U
Icon=flax
Terminal=false
Type=Application
Categories=AudioVideo;Audio;Player;Music;
Keywords=music;player;subsonic;navidrome;audio;flac;mpv;
StartupWMClass=flax
EOF
  chmod +x "$desktop_dir/flax.desktop"

  # Update desktop and icon databases if tools are available
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$desktop_dir" >/dev/null 2>&1 || true
  fi
  if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f -t "${HOME}/.local/share/icons/hicolor" >/dev/null 2>&1 || true
  fi

  # Check libmpv dependency
  check_linux_dependencies

  success "Flax v${version} installed successfully!"
  printf "\n"
  printf "  ${DIM}Flax is installed to ${target_dir} and available at ${bin_dir}/flax${NC}\n"
  printf "  ${DIM}It will self-update via the in-app update pill when new releases are available.${NC}\n"
  printf "\n"

  # PATH guidance
  case ":${PATH}:" in
    *:"${bin_dir}":*) ;;
    *)
      warn "${bin_dir} is not in your \$PATH."
      printf "  Add it to your shell configuration (e.g. ~/.bashrc or ~/.zshrc):\n"
      printf "    ${BOLD}export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}\n\n"
      ;;
  esac

  if [ "$no_launch" = 0 ] && [ -t 1 ] && [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
    step "Launching Flax..."
    "$bin_dir/flax" >/dev/null 2>&1 &
  fi
}

check_linux_dependencies() {
  local has_mpv=0

  # Check ldconfig for libmpv.so.2 or libmpv.so.1
  if command -v ldconfig >/dev/null 2>&1; then
    if ldconfig -p 2>/dev/null | grep -qE 'libmpv\.so\.[12]'; then
      has_mpv=1
    fi
  fi

  # Check common library paths
  if [ "$has_mpv" = 0 ]; then
    for path in /usr/lib/libmpv.so* /usr/lib64/libmpv.so* /usr/lib/x86_64-linux-gnu/libmpv.so* /usr/local/lib/libmpv.so* "$HOME/.local/usr/lib/x86_64-linux-gnu/libmpv.so*"; do
      if [ -e "$path" ]; then
        has_mpv=1
        break
      fi
    done
  fi

  local has_keybinder=0
  if command -v ldconfig >/dev/null 2>&1; then
    if ldconfig -p 2>/dev/null | grep -qE 'libkeybinder-3\.0'; then
      has_keybinder=1
    fi
  fi
  if [ "$has_keybinder" = 0 ]; then
    for path in /usr/lib/libkeybinder-3.0* /usr/lib64/libkeybinder-3.0* /usr/lib/x86_64-linux-gnu/libkeybinder-3.0* /usr/local/lib/libkeybinder-3.0* "$HOME/.local/usr/lib/x86_64-linux-gnu/libkeybinder-3.0*"; do
      if [ -e "$path" ]; then
        has_keybinder=1
        break
      fi
    done
  fi

  if [ "$has_mpv" = 1 ] && [ "$has_keybinder" = 1 ]; then
    return 0
  fi

  local deb_pkgs=()
  local rpm_pkgs=()
  local arch_pkgs=()
  local zypp_pkgs=()

  if [ "$has_mpv" = 0 ]; then
    deb_pkgs+=("libmpv2")
    rpm_pkgs+=("mpv-libs")
    arch_pkgs+=("mpv")
    zypp_pkgs+=("libmpv2")
  fi

  if [ "$has_keybinder" = 0 ]; then
    deb_pkgs+=("libkeybinder-3.0-0")
    rpm_pkgs+=("keybinder3")
    arch_pkgs+=("keybinder3")
    zypp_pkgs+=("libkeybinder-3_0-0")
  fi

  local install_cmd=""
  if [ -f /etc/debian_version ] || [ -f /etc/lsb-release ] || [ -f /etc/os-release ]; then
    if command -v apt >/dev/null 2>&1; then
      install_cmd="sudo apt update && sudo apt install -y ${deb_pkgs[*]}"
    fi
  fi
  if [ -z "$install_cmd" ] && ([ -f /etc/fedora-release ] || [ -f /etc/redhat-release ]); then
    if command -v dnf >/dev/null 2>&1; then
      install_cmd="sudo dnf install -y ${rpm_pkgs[*]}"
    fi
  fi
  if [ -z "$install_cmd" ] && [ -f /etc/arch-release ]; then
    if command -v pacman >/dev/null 2>&1; then
      install_cmd="sudo pacman -S --noconfirm ${arch_pkgs[*]}"
    fi
  fi
  if [ -z "$install_cmd" ] && [ -f /etc/zypp/zypp.conf ]; then
    if command -v zypper >/dev/null 2>&1; then
      install_cmd="sudo zypper install -y ${zypp_pkgs[*]}"
    fi
  fi

  local did_install=0
  if [ -n "$install_cmd" ] && [ -w /dev/tty ] && command -v sudo >/dev/null 2>&1; then
    warn "Missing system dependencies detected:"
    [ "$has_mpv" = 0 ] && printf "  ${CYAN}•${NC} %s (audio playback)\n" "${deb_pkgs[0]:-libmpv}"
    [ "$has_keybinder" = 0 ] && printf "  ${CYAN}•${NC} %s (global media hotkeys)\n" "${deb_pkgs[1]:-libkeybinder-3.0}"
    printf "\n"
    printf "  Would you like to install them automatically? [Y/n] "
    local reply=""
    read -r reply </dev/tty || reply="n"
    if [ -z "$reply" ] || [ "$reply" = "y" ] || [ "$reply" = "Y" ]; then
      info "Installing dependencies via package manager..."
      if sh -c "$install_cmd"; then
        did_install=1
        success "Dependencies installed successfully."
      else
        warn "Automatic package installation was not completed."
      fi
    fi
  fi

  if [ "$did_install" = 0 ]; then
    [ "$has_mpv" = 0 ] && warn "libmpv was not detected (required for audio playback)."
    [ "$has_keybinder" = 0 ] && warn "libkeybinder-3.0 was not detected (required for global media hotkeys)."
    if [ -n "$install_cmd" ]; then
      printf "  Install them with your package manager:\n"
      printf "    ${BOLD}%s${NC}\n\n" "$install_cmd"
    fi
  fi
}

# ── Execute ───────────────────────────────────────────────────────────

if [ "${FLAX_TEST:-0}" != "1" ]; then
  main "$@"
fi
