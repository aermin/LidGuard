#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-release}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:--}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
VERSION="${VERSION:-$(/usr/bin/plutil -extract CFBundleShortVersionString raw "$ROOT/Resources/Info.plist")}"
ARCHITECTURE="${ARCHITECTURE:-$(/usr/bin/uname -m)}"
DIST_DIRECTORY="$ROOT/dist"
DMG_PATH="$DIST_DIRECTORY/LidGuard-$VERSION-$ARCHITECTURE.dmg"
STAGING_DIRECTORY="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/LidGuard.dmg.XXXXXX")"

cleanup() {
    /bin/rm -rf "$STAGING_DIRECTORY"
}
trap cleanup EXIT

if [[ -n "$NOTARY_PROFILE" && "$SIGNING_IDENTITY" == "-" ]]; then
    echo "Notarization requires a Developer ID Application signing identity" >&2
    exit 1
fi

APP_BUNDLE="$(
    CONFIGURATION="$CONFIGURATION" SIGNING_IDENTITY="$SIGNING_IDENTITY" \
        "$ROOT/scripts/build-app.sh" | /usr/bin/tail -n 1
)"

/bin/mkdir -p "$DIST_DIRECTORY"
/usr/bin/ditto "$APP_BUNDLE" "$STAGING_DIRECTORY/LidGuard.app"
/bin/ln -s /Applications "$STAGING_DIRECTORY/Applications"
/bin/rm -f "$DMG_PATH"

/usr/bin/hdiutil create \
    -volname "LidGuard" \
    -srcfolder "$STAGING_DIRECTORY" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

if [[ "$SIGNING_IDENTITY" != "-" ]]; then
    /usr/bin/codesign --force --sign "$SIGNING_IDENTITY" --timestamp "$DMG_PATH"
    /usr/bin/codesign --verify --strict "$DMG_PATH"
fi

if [[ -n "$NOTARY_PROFILE" ]]; then
    /usr/bin/xcrun notarytool submit "$DMG_PATH" \
        --keychain-profile "$NOTARY_PROFILE" \
        --wait
    /usr/bin/xcrun stapler staple "$DMG_PATH"
    /usr/bin/xcrun stapler validate "$DMG_PATH"
fi

echo "$DMG_PATH"
