#!/usr/bin/env bash
# Screenshot the running flax window for GUI verification.
#
#   tool/screenshot.sh                 # -> /tmp/flax-shots/flax-<timestamp>.png
#   tool/screenshot.sh out.png         # -> out.png
#
# Requires two macOS privacy grants for the terminal/app running this
# (System Settings -> Privacy & Security):
#   * Accessibility   — to read the flax window's position/size via System Events
#   * Screen Recording — for screencapture to produce actual pixels
# Without Screen Recording, screencapture prints "could not create image from
# display" and this script exits non-zero.
set -euo pipefail

OUT="${1:-/tmp/flax-shots/flax-$(date +%Y%m%d-%H%M%S).png}"
mkdir -p "$(dirname "$OUT")"

if ! pgrep -f "flax.app/Contents/MacOS/flax" >/dev/null; then
  echo "error: flax is not running — launch it first (tool/run_flax.sh)" >&2
  exit 1
fi

# Bring flax to the front so nothing overlaps the capture region.
osascript -e 'tell application "System Events" to set frontmost of process "flax" to true' 2>/dev/null || true
sleep 0.4

# Ask System Events for the window rectangle in screen points: "x, y, w, h".
BOUNDS="$(osascript -e 'tell application "System Events" to tell process "flax" to get {position, size} of window 1' 2>/dev/null || true)"

if [[ "$BOUNDS" =~ ^([0-9-]+),\ *([0-9-]+),\ *([0-9]+),\ *([0-9]+)$ ]]; then
  X="${BASH_REMATCH[1]}"; Y="${BASH_REMATCH[2]}"; W="${BASH_REMATCH[3]}"; H="${BASH_REMATCH[4]}"
  echo "==> Capturing flax window at ${X},${Y} ${W}x${H}"
  screencapture -x -o -R"${X},${Y},${W},${H}" "$OUT"
else
  echo "==> Could not read window bounds; capturing full screen instead" >&2
  screencapture -x -o "$OUT"
fi

if [ ! -s "$OUT" ]; then
  echo "error: no image produced — is Screen Recording granted to this terminal?" >&2
  exit 1
fi

echo "$OUT"
sips -g pixelWidth -g pixelHeight "$OUT" 2>/dev/null | tail -2 || true
