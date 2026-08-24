#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-0.0.0}"
BUNDLE_DIR="build/linux/x64/release/bundle"
DIST_DIR="dist"

mkdir -p "$DIST_DIR"

if [ ! -d "$BUNDLE_DIR" ]; then
  echo "Error: Bundle directory $BUNDLE_DIR does not exist. Run 'flutter build linux --release' first." >&2
  exit 1
fi

echo "==> Packaging Linux artifacts for flax $VERSION"

# 1. Ensure icons and desktop files are inside portable bundle
cp "packaging/linux/flax.png" "$BUNDLE_DIR/"
cp "packaging/linux/flax.desktop" "$BUNDLE_DIR/"

# 2. Package portable tarball
TARBALL="$DIST_DIR/flax-$VERSION-linux-x64.tar.gz"
echo "==> Creating tarball: $TARBALL"
tar -czf "$TARBALL" -C "$BUNDLE_DIR" .

# 3. Package .deb
DEB_STAGING="$(mktemp -d)"
trap 'rm -rf "$DEB_STAGING"' EXIT

echo "==> Staging .deb package structure"
mkdir -p "$DEB_STAGING/DEBIAN"
mkdir -p "$DEB_STAGING/usr/bin"
mkdir -p "$DEB_STAGING/usr/lib/flax"
mkdir -p "$DEB_STAGING/usr/share/applications"
mkdir -p "$DEB_STAGING/usr/share/icons/hicolor/512x512/apps"
mkdir -p "$DEB_STAGING/usr/share/pixmaps"

cat <<CONTROL_EOF > "$DEB_STAGING/DEBIAN/control"
Package: flax
Version: $VERSION
Section: sound
Priority: optional
Architecture: amd64
Maintainer: brutog <brutog@users.noreply.github.com>
Depends: libgtk-3-0, libpulse0, libasound2
Description: High-fidelity music player for Subsonic and Navidrome
 Flax is a high-fidelity client for self-hosted music servers (Navidrome / Subsonic)
 featuring AutoEQ headphone correction and an 18-band parametric-style equalizer.
CONTROL_EOF

cp -r "$BUNDLE_DIR"/* "$DEB_STAGING/usr/lib/flax/"
ln -s "/usr/lib/flax/flax" "$DEB_STAGING/usr/bin/flax"
cp "packaging/linux/flax.desktop" "$DEB_STAGING/usr/share/applications/"
cp "packaging/linux/flax.png" "$DEB_STAGING/usr/share/icons/hicolor/512x512/apps/"
cp "packaging/linux/flax.png" "$DEB_STAGING/usr/share/pixmaps/"

DEB_FILE="$DIST_DIR/flax-$VERSION-linux-amd64.deb"
echo "==> Building .deb: $DEB_FILE"
dpkg-deb --build --root-owner-group "$DEB_STAGING" "$DEB_FILE"

# 3. Package .rpm (using fpm if available)
if command -v fpm >/dev/null 2>&1; then
  RPM_FILE="$DIST_DIR/flax-$VERSION-linux-x86_64.rpm"
  echo "==> Building .rpm with fpm: $RPM_FILE"
  fpm -s dir -t rpm -n flax -v "$VERSION" -a x86_64 \
    --license "GPL-3.0-or-later" \
    --vendor "neckbeard.io" \
    --maintainer "brutog <brutog@users.noreply.github.com>" \
    --description "High-fidelity music player for Subsonic and Navidrome" \
    --url "https://github.com/neckbeard-io/flax" \
    -p "$RPM_FILE" \
    -C "$DEB_STAGING" usr
fi

echo "==> Linux packages built in $DIST_DIR:"
ls -lh "$DIST_DIR"/*linux*
