#!/bin/bash
set -e

# Configuration
VERSION="2.0.0"
APP_NAME="x360-tools"
DISPLAY_NAME="x360 Tools v2.0"
BASE_DIR="/home/amplimusic/Documentos/BadStickLinux/v1.1"
BUILD_DIR="$BASE_DIR/x360_tools_flutter/build/linux/x64/release/bundle"
RELEASE_DIR="/home/amplimusic/Documentos/BadStickLinux/v2 final release"
ICON_SRC="$BASE_DIR/assets/x360_tools_icon.png"
APPIMAGETOOL="/home/amplimusic/Documentos/BadStickLinux/appimagetool"

echo "[1/4] Preparing Release Directory..."
mkdir -p "$RELEASE_DIR"
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# ------------------------------------------------------------------------------
# DEB PACKAGE
# ------------------------------------------------------------------------------
echo "[2/4] Building .deb package..."
DEB_ROOT="$TEMP_DIR/deb"
mkdir -p "$DEB_ROOT/usr/bin"
mkdir -p "$DEB_ROOT/usr/lib/$APP_NAME"
mkdir -p "$DEB_ROOT/usr/share/applications"
mkdir -p "$DEB_ROOT/usr/share/icons/hicolor/512x512/apps"
mkdir -p "$DEB_ROOT/DEBIAN"

# Copy Flutter Bundle to /usr/lib/x360-tools
cp -r "$BUILD_DIR/"* "$DEB_ROOT/usr/lib/$APP_NAME/"

# Copy Python Backend to /usr/lib/x360-tools
cp "$BASE_DIR/service_bridge.py" "$DEB_ROOT/usr/lib/$APP_NAME/"
cp -r "$BASE_DIR/core" "$DEB_ROOT/usr/lib/$APP_NAME/"
cp -r "$BASE_DIR/applib" "$DEB_ROOT/usr/lib/$APP_NAME/"
cp -r "$BASE_DIR/assets" "$DEB_ROOT/usr/lib/$APP_NAME/"
cp "$BASE_DIR/titleIDs.db" "$DEB_ROOT/usr/lib/$APP_NAME/" 2>/dev/null || true

# Create Symlink in /usr/bin
ln -s "/usr/lib/$APP_NAME/x360_tools" "$DEB_ROOT/usr/bin/$APP_NAME"

# Icon
cp "$ICON_SRC" "$DEB_ROOT/usr/share/icons/hicolor/512x512/apps/$APP_NAME.png"

# Desktop File
cat <<EOF > "$DEB_ROOT/usr/share/applications/$APP_NAME.desktop"
[Desktop Entry]
Name=$DISPLAY_NAME
Comment=Xbox 360 Tool Suite for Linux
Exec=$APP_NAME
Icon=$APP_NAME
Type=Application
Terminal=false
Categories=Utility;System;
EOF

# Control File
cat <<EOF > "$DEB_ROOT/DEBIAN/control"
Package: $APP_NAME
Version: $VERSION
Section: utils
Priority: optional
Architecture: amd64
Depends: python3, python3-pil, python3-requests, python3-urllib3, aria2, sqlite3, p7zip-full, libfuse2
Maintainer: Antigravity AI <support@antigravity.org>
Description: x360 Tools v2.0 for Linux. A modern suite for Xbox 360 management.
EOF

# Build DEB
dpkg-deb --build "$DEB_ROOT" "$RELEASE_DIR/${APP_NAME}_${VERSION}_amd64.deb"

# ------------------------------------------------------------------------------
# APPIMAGE
# ------------------------------------------------------------------------------
echo "[3/4] Building .AppImage package..."
APPDIR="$TEMP_DIR/AppDir"
mkdir -p "$APPDIR/usr/bin"
mkdir -p "$APPDIR/usr/lib/$APP_NAME"

# Copy same structure to AppDir
cp -r "$DEB_ROOT/usr/lib/$APP_NAME/"* "$APPDIR/usr/lib/$APP_NAME/"

# Icon and Desktop in Root (required for AppImage)
cp "$ICON_SRC" "$APPDIR/$APP_NAME.png"
cp "$DEB_ROOT/usr/share/applications/$APP_NAME.desktop" "$APPDIR/"
ln -s "$APP_NAME.png" "$APPDIR/.DirIcon"

# Create AppRun
cat <<EOF > "$APPDIR/AppRun"
#!/bin/bash
HERE="\$(dirname "\$(readlink -f "\${0}")")"
# Launch Flutter app from its new location
"\$HERE/usr/lib/$APP_NAME/x360_tools" "\$@"
EOF
chmod +x "$APPDIR/AppRun"

# Build AppImage
ARCH=x86_64 "$APPIMAGETOOL" "$APPDIR" "$RELEASE_DIR/${APP_NAME}_v${VERSION}_x86_64.AppImage"

echo "[4/4] Release generated in: $RELEASE_DIR"
ls -lh "$RELEASE_DIR"
