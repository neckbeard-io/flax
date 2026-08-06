#!/usr/bin/env bash
# Drive the mouse pointer against the running flax window, so hover states and
# click-through flows can actually be verified and screenshotted.
#
#   tool/pointer.sh move  <x> <y>     # put the pointer there and leave it
#   tool/pointer.sh click <x> <y>     # move, then left click
#   tool/pointer.sh park              # move the pointer out of the window
#
# Coordinates are screen points. Add -w to give them relative to the flax
# window's top-left instead, which is what you get from a screenshot:
#
#   tool/pointer.sh -w move 865 891
#
# Turning screenshot pixels into window points: tool/screenshot.sh captures at
# the display's backing scale, so divide by (image width / window width in
# points) — 2 on a Retina Mac.
#
# Events are posted to the HID event tap, which is where real hardware delivers
# them, so a Flutter window handles them exactly like a physical mouse. This
# needs the same Accessibility grant tool/screenshot.sh already relies on.
set -euo pipefail

WINDOW_RELATIVE=0
if [[ "${1:-}" == "-w" ]]; then
  WINDOW_RELATIVE=1
  shift
fi

CMD="${1:-}"

window_origin() {
  osascript -e 'tell application "System Events" to tell process "flax" to get position of window 1' 2>/dev/null
}

case "$CMD" in
  move|click)
    X="${2:?usage: tool/pointer.sh [-w] $CMD <x> <y>}"
    Y="${3:?usage: tool/pointer.sh [-w] $CMD <x> <y>}"
    ;;
  park)
    X=5; Y=5
    WINDOW_RELATIVE=0
    ;;
  *)
    echo "usage: tool/pointer.sh [-w] {move|click|park} [<x> <y>]" >&2
    exit 2
    ;;
esac

if [[ "$WINDOW_RELATIVE" == "1" ]]; then
  ORIGIN="$(window_origin)"
  if [[ ! "$ORIGIN" =~ ^([0-9-]+),\ *([0-9-]+)$ ]]; then
    echo "error: could not read the flax window position — is it running?" >&2
    echo "       (a sleeping display also reports no windows; see CLAUDE.md)" >&2
    exit 1
  fi
  X=$(( X + BASH_REMATCH[1] ))
  Y=$(( Y + BASH_REMATCH[2] ))
fi

SRC="$(mktemp -t flaxpointer).swift"
trap 'rm -f "$SRC"' EXIT
cat > "$SRC" <<'SWIFT'
import CoreGraphics
import Foundation

let x = Double(CommandLine.arguments[1])!
let y = Double(CommandLine.arguments[2])!
let click = CommandLine.arguments[3] == "click"
let point = CGPoint(x: x, y: y)

CGWarpMouseCursorPosition(point)
CGAssociateMouseAndMouseCursorPosition(1)

func post(_ type: CGEventType) {
  CGEvent(
    mouseEventSource: nil,
    mouseType: type,
    mouseCursorPosition: point,
    mouseButton: .left
  )?.post(tap: .cghidEventTap)
}

post(.mouseMoved)
if click {
  usleep(80_000)
  post(.leftMouseDown)
  usleep(60_000)
  post(.leftMouseUp)
}
SWIFT

swift "$SRC" "$X" "$Y" "$CMD"
echo "==> pointer ${CMD} at ${X},${Y}"
