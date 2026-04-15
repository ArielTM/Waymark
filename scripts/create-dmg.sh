#!/bin/bash
set -euo pipefail

# Create a DMG from a built Waymark.app
# Usage: ./scripts/create-dmg.sh <path-to-Waymark.app> [version]

APP_PATH="${1:?Usage: $0 <path-to-Waymark.app> [version]}"
VERSION="${2:-dev}"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: App not found: $APP_PATH"
    exit 1
fi

OUTPUT_DIR="build"
mkdir -p "$OUTPUT_DIR"

DMG_NAME="Waymark-${VERSION}-universal.dmg"
DMG_PATH="${OUTPUT_DIR}/${DMG_NAME}"

rm -f "$DMG_PATH"

echo "Creating DMG: $DMG_NAME"

STAGING=$(mktemp -d)
cp -R "$APP_PATH" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create \
    -volname "Waymark" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

rm -rf "$STAGING"

echo ""
echo "DMG created: $DMG_PATH"
echo "SHA256: $(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"
