#!/bin/bash
set -euo pipefail

# Generate all macOS app icon sizes from a 1024x1024 source PNG.
# Usage: ./scripts/generate-icons.sh path/to/icon-1024.png

SOURCE="${1:?Usage: $0 <path-to-1024x1024-png>}"
DEST="Waymark/Assets.xcassets/AppIcon.appiconset"

if [ ! -f "$SOURCE" ]; then
    echo "Error: Source file not found: $SOURCE"
    exit 1
fi

# Verify dimensions
WIDTH=$(sips -g pixelWidth "$SOURCE" 2>/dev/null | tail -1 | awk '{print $2}')
HEIGHT=$(sips -g pixelHeight "$SOURCE" 2>/dev/null | tail -1 | awk '{print $2}')

if [ "$WIDTH" != "1024" ] || [ "$HEIGHT" != "1024" ]; then
    echo "Error: Source image must be 1024x1024 (got ${WIDTH}x${HEIGHT})"
    exit 1
fi

# macOS icon sizes: base_size:scale:output_pixels
SIZES=(
    "16:1:16"
    "16:2:32"
    "32:1:32"
    "32:2:64"
    "128:1:128"
    "128:2:256"
    "256:1:256"
    "256:2:512"
    "512:1:512"
    "512:2:1024"
)

for entry in "${SIZES[@]}"; do
    IFS=':' read -r base scale pixels <<< "$entry"

    if [ "$scale" -eq 1 ]; then
        FILENAME="icon_${base}x${base}.png"
    else
        FILENAME="icon_${base}x${base}@2x.png"
    fi

    if [ "$pixels" -eq 1024 ]; then
        cp "$SOURCE" "$DEST/$FILENAME"
    else
        sips -z "$pixels" "$pixels" "$SOURCE" --out "$DEST/$FILENAME" >/dev/null 2>&1
    fi
    echo "Generated: $FILENAME (${pixels}px)"
done

echo ""
echo "Done. Icon files written to $DEST/"
echo "Run 'xcodegen generate' to pick up the changes."
