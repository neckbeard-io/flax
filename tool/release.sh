#!/usr/bin/env bash
# Build distributable test artifacts locally, into dist/.
#
#   tool/release.sh                     # macOS .dmg + Android .apk
#   tool/release.sh --mac               # macOS .dmg only
#   tool/release.sh --android           # Android .apk only
#   tool/release.sh --version 0.1.1     # override the version name
#
# Windows is deliberately absent: it cannot be cross-compiled from macOS. Push a
# tag and let .github/workflows/release.yml build it on a Windows runner.
#
# The macOS .dmg is ad-hoc signed, so Gatekeeper quarantines it on any other
# Mac. After copying flax.app to /Applications there, run once:
#   xattr -dr com.apple.quarantine /Applications/flax.app
set -euo pipefail
cd "$(dirname "$0")/.."

DO_MAC=0
DO_ANDROID=0
VERSION=""

while [ $# -gt 0 ]; do
  case "$1" in
    --mac) DO_MAC=1 ;;
    --android) DO_ANDROID=1 ;;
    --version) shift; VERSION="${1:-}" ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done

# Default to everything buildable on this host.
if [ "$DO_MAC" = 0 ] && [ "$DO_ANDROID" = 0 ]; then
  DO_MAC=1
  DO_ANDROID=1
fi

# Version name from the latest v* tag unless overridden; build number from the
# commit count so two builds of the same version are still distinguishable
# on-device (Android refuses to downgrade versionCode, and macOS uses it to
# decide whether a bundle is newer).
if [ -z "$VERSION" ]; then
  VERSION="$(git describe --tags --abbrev=0 --match 'v*' 2>/dev/null | sed 's/^v//' || true)"
  [ -n "$VERSION" ] || VERSION="0.1.0"
fi
BUILD_NUMBER="$(git rev-list --count HEAD)"

echo "==> flax $VERSION+$BUILD_NUMBER"
mkdir -p dist

if [ "$DO_MAC" = 1 ]; then
  echo "==> Building macOS release…"
  flutter build macos --release \
    --build-name="$VERSION" --build-number="$BUILD_NUMBER"

  # Flutter emits a universal binary (x86_64 + arm64), so this one .dmg covers
  # Apple Silicon and Intel Macs both.
  DMG="dist/flax-$VERSION-macos-universal.dmg"
  STAGING="$(mktemp -d)"
  # Symlink /Applications into the volume so the drag-to-install target is
  # right there in the mounted window.
  cp -R "build/macos/Build/Products/Release/flax.app" "$STAGING/"
  ln -s /Applications "$STAGING/Applications"
  rm -f "$DMG"
  hdiutil create -volname "flax" -srcfolder "$STAGING" \
    -ov -format UDZO "$DMG" >/dev/null
  rm -rf "$STAGING"
  echo "==> $DMG"
fi

if [ "$DO_ANDROID" = 1 ]; then
  if [ ! -f android/key.properties ]; then
    echo "error: android/key.properties is missing — the APK would be signed" >&2
    echo "       with this machine's debug key and testers could not upgrade" >&2
    echo "       in place. Restore it from your password manager." >&2
    exit 1
  fi
  echo "==> Building Android release APK…"
  flutter build apk --release \
    --build-name="$VERSION" --build-number="$BUILD_NUMBER"

  APK="dist/flax-$VERSION-android-universal.apk"
  cp build/app/outputs/flutter-apk/app-release.apk "$APK"
  echo "==> $APK"
fi

echo
echo "==> Artifacts in dist/:"
ls -lh dist/
