#!/usr/bin/env bash
# Rebuild + relaunch flax (macOS) so on-screen state always matches the code.
#
#   tool/run_flax.sh            # kill → build (debug) → launch
#   tool/run_flax.sh --release  # build a release bundle instead
#   tool/run_flax.sh --no-build # just kill → relaunch the existing bundle
#
# Flutter hot reload is deliberately NOT used here: a full kill + rebuild is the
# only way to guarantee the window you are looking at reflects the current tree.
set -euo pipefail
cd "$(dirname "$0")/.."

MODE="debug"
BUILD=1
for arg in "$@"; do
  case "$arg" in
    --release) MODE="release" ;;
    --no-build) BUILD=0 ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done

APP="build/macos/Build/Products/$([ "$MODE" = release ] && echo Release || echo Debug)/flax.app"

echo "==> Killing any running flax…"
pkill -f "flax.app/Contents/MacOS/flax" 2>/dev/null || true
# Wait for the process to actually exit so the new launch is the only instance.
for _ in $(seq 1 20); do pgrep -f "flax.app/Contents/MacOS/flax" >/dev/null || break; sleep 0.2; done

if [ "$BUILD" = 1 ]; then
  echo "==> Building flax ($MODE)…"
  flutter build macos --"$MODE"
fi

if [ ! -d "$APP" ]; then
  echo "error: $APP not found (build first without --no-build)" >&2
  exit 1
fi

echo "==> Launching $APP"
open "$APP"
echo "==> flax launched. Give it a second to connect to the server."
