#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SDK="${SDKROOT:-/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk}"
SWIFTC="${SWIFTC:-/Library/Developer/CommandLineTools/usr/bin/swiftc}"
WORK_DIRECTORY="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/LidGuard.icon.XXXXXX")"
ICONSET="$WORK_DIRECTORY/AppIcon.iconset"
SOURCE_PNG="$WORK_DIRECTORY/AppIcon-1024.png"
RENDERER="$WORK_DIRECTORY/render-app-icon"
OUTPUT="$ROOT/Resources/AppIcon.icns"

cleanup() {
    /bin/rm -rf "$WORK_DIRECTORY"
}
trap cleanup EXIT

/bin/mkdir -p "$ICONSET"
"$SWIFTC" -parse-as-library -sdk "$SDK" -target arm64-apple-macosx13.0 \
    "$ROOT/scripts/render-app-icon.swift" -o "$RENDERER"
"$RENDERER" "$SOURCE_PNG"

for SIZE in 16 32 128 256 512; do
    /usr/bin/sips -z "$SIZE" "$SIZE" "$SOURCE_PNG" \
        --out "$ICONSET/icon_${SIZE}x${SIZE}.png" >/dev/null
    DOUBLE_SIZE=$((SIZE * 2))
    /usr/bin/sips -z "$DOUBLE_SIZE" "$DOUBLE_SIZE" "$SOURCE_PNG" \
        --out "$ICONSET/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done

/usr/bin/iconutil --convert icns --output "$OUTPUT" "$ICONSET"
/bin/echo "$OUTPUT"
