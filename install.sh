#!/bin/bash
set -e

SCHEME="DockPin"
PROJECT="DockPin.xcodeproj"
INSTALL_PATH="/Applications/DockPin.app"

echo "Building..."
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release build | tail -3

BUILD_DIR=$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
  -showBuildSettings 2>/dev/null | grep " BUILT_PRODUCTS_DIR" | awk '{print $3}')

# Kill running instance before replacing binary
if pgrep -x DockPin > /dev/null; then
  echo "Stopping DockPin..."
  pkill -x DockPin || true
  sleep 1
fi

echo "Installing to $INSTALL_PATH..."
# Sync contents instead of rm+cp to avoid macOS revoking Accessibility permission
rsync -a --delete "$BUILD_DIR/DockPin.app/" "$INSTALL_PATH/"

# Re-sign in place so the signature stays consistent
codesign --force --deep --sign - "$INSTALL_PATH"

echo "Done. Launching..."
open "$INSTALL_PATH"
