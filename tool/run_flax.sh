#!/usr/bin/env bash
# Rebuild + relaunch flax (macOS / Linux) so on-screen state always matches the code.
#
#   tool/run_flax.sh            # kill → build (debug) → launch
#   tool/run_flax.sh --release  # build a release bundle instead
#   tool/run_flax.sh --no-build # just kill → relaunch the existing bundle
#   tool/run_flax.sh --probe    # + instrument track boundaries (gapless)
#
# Flutter hot reload is deliberately NOT used here: a full kill + rebuild is the
# only way to guarantee the window you are looking at reflects the current tree.
set -euo pipefail
cd "$(dirname "$0")/.."

# Ensure flutter and toolchain binaries are in PATH if available
export PATH="/home/mike/development/flutter/bin:/home/mike/.local/bin:$PATH"

MODE="debug"
BUILD=1
ROUTE=""
PROBE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --release) MODE="release" ;;
    --no-build) BUILD=0 ;;
    # Open straight onto a screen instead of home, e.g.
    #   tool/run_flax.sh --route /artists/ar-123
    # Debug builds only; the router ignores it in release. Lets a screen buried
    # behind navigation be screenshotted, which is otherwise impossible because
    # synthetic clicks do not reach a Flutter window.
    --route) shift; ROUTE="${1:-}" ;;
    # Log what happens between two tracks: the measured gap, whether mpv's
    # prefetch was consumed, the output buffer, and whether the device was
    # reopened. Also raises mpv's own log level to debug. Off by default
    # because that log is far too chatty to live with.
    --probe) PROBE=1 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done

OS_TYPE="$(uname -s)"
if [ "$OS_TYPE" = "Darwin" ]; then
  PLATFORM="macos"
  APP="build/macos/Build/Products/$([ "$MODE" = release ] && echo Release || echo Debug)/flax.app"
  KILL_PATTERN="flax.app/Contents/MacOS/flax"
else
  PLATFORM="linux"
  APP="build/linux/x64/$MODE/bundle/flax"
  KILL_PATTERN="build/linux/x64/.*/bundle/flax"
fi

echo "==> Killing any running flax…"
pkill -f "$KILL_PATTERN" 2>/dev/null || true
# Wait for the process to actually exit so the new launch is the only instance.
for _ in $(seq 1 20); do pgrep -f "$KILL_PATTERN" >/dev/null || break; sleep 0.2; done

if [ "$BUILD" = 1 ]; then
  # Stamp the version the same way tool/release.sh does. Without this a local
  # build reports pubspec's 0.1.0 forever, so Settings -> About cannot tell you
  # which code you are looking at — and a stale bundle here has already been
  # mistaken for an installed release. Debug builds also carry the DEBUG ribbon
  # and say "debug build" in About.
  VERSION="$(git describe --tags --abbrev=0 --match 'v*' 2>/dev/null | sed 's/^v//' || true)"
  [ -n "$VERSION" ] || VERSION="0.1.0"
  BUILD_NUMBER="$(git rev-list --count HEAD)"
  # Braces are required: an unbraced $BUILD_NUMBER runs into the following
  # multibyte ellipsis and bash takes it as part of the variable name, which
  # under `set -u` aborts the script.
  echo "==> Building flax ($MODE) ${VERSION}+${BUILD_NUMBER}…"
  DEFINES=()
  [ -n "$ROUTE" ] && DEFINES+=(--dart-define=FLAX_ROUTE="$ROUTE")
  [ "$PROBE" = "1" ] && DEFINES+=(--dart-define=FLAX_GAPLESS_PROBE=true)
  flutter build "$PLATFORM" --"$MODE" \
    --build-name="$VERSION" --build-number="$BUILD_NUMBER" \
    "${DEFINES[@]+"${DEFINES[@]}"}"
fi

if [ "$PLATFORM" = "macos" ] && [ ! -d "$APP" ]; then
  echo "error: $APP not found (build first without --no-build)" >&2
  exit 1
elif [ "$PLATFORM" = "linux" ] && [ ! -f "$APP" ]; then
  echo "error: $APP not found (build first without --no-build)" >&2
  exit 1
fi

echo "==> Launching $APP"
if [ "$PLATFORM" = "macos" ]; then
  open "$APP"
else
  export DISPLAY="${DISPLAY:-:0}"
  export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
  APP_ABS="$(cd "$(dirname "$APP")" && pwd)/$(basename "$APP")"
  setsid "$APP_ABS" </dev/null >/tmp/flax.log 2>&1 &
  sleep 1
fi
echo "==> flax launched. Give it a second to connect to the server."
