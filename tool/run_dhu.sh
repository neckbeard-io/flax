#!/usr/bin/env bash
set -euo pipefail

# Desktop Head Unit (DHU) launcher for Android Auto in-car testing.
# Performs a full kill-restart cycle so the head unit always picks up
# the latest build: kills the old DHU, force-stops Flax, restarts Flax,
# waits for its media session to register, then launches the DHU.

DHU_PATH="$HOME/Library/Android/sdk/extras/google/auto/desktop-head-unit"
CONFIG_PATH="$HOME/Library/Android/sdk/extras/google/auto/config/ev6_ultrawide.ini"
SERIAL="58210DLCQ00BVT"
PKG="com.flaxplayer.flax"

ADB="adb -s $SERIAL"

if [[ ! -f "$DHU_PATH" ]]; then
  echo "Error: DHU executable not found at $DHU_PATH"
  exit 1
fi

# ── 1. Kill any running DHU ──────────────────────────────────────────
echo "⏹  Killing existing DHU..."
pkill -f desktop-head-unit 2>/dev/null || true
sleep 1

# ── 2. Force-stop Flax ──────────────────────────────────────────────
echo "⏹  Force-stopping Flax..."
$ADB shell am force-stop "$PKG"
sleep 1

# ── 3. Restart Flax ─────────────────────────────────────────────────
echo "▶  Starting Flax..."
$ADB shell am start -n "$PKG/.MainActivity"
sleep 1

# ── 4. Wait for media session ───────────────────────────────────────
echo "⏳ Waiting for Flax media session..."
for i in $(seq 1 15); do
  if $ADB shell dumpsys media_session 2>/dev/null | grep -q "$PKG/media-session"; then
    echo "✓  Media session active"
    break
  fi
  if [[ $i -eq 15 ]]; then
    echo "⚠  Media session not found after 15s — launching DHU anyway"
  fi
  sleep 1
done

# ── 5. Set up port forwarding and launch DHU ────────────────────────
echo "🔌 Setting up ADB port forwarding (tcp:5277)..."
$ADB forward tcp:5277 tcp:5277

echo "🚗 Launching Android Auto Desktop Head Unit (Kia EV6 1920×720 ultrawide)..."
"$DHU_PATH" -c "$CONFIG_PATH"
