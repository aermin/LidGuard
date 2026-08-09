#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-debug}"
DIST_DIRECTORY="$ROOT/dist"
APP_BUNDLE="$DIST_DIRECTORY/LidGuard.app"

cd "$ROOT"
/usr/bin/swift build -c "$CONFIGURATION" --product LidGuardHelper
/usr/bin/swift build -c "$CONFIGURATION" --product lidguard
/usr/bin/swift build -c "$CONFIGURATION" --product LidGuardApp

BIN_DIRECTORY="$(/usr/bin/swift build -c "$CONFIGURATION" --show-bin-path)"

/bin/mkdir -p \
    "$APP_BUNDLE/Contents/MacOS" \
    "$APP_BUNDLE/Contents/Resources" \
    "$APP_BUNDLE/Contents/Library/HelperTools" \
    "$APP_BUNDLE/Contents/Library/LaunchDaemons"

/usr/bin/ditto "$ROOT/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
/usr/bin/ditto "$BIN_DIRECTORY/LidGuardApp" "$APP_BUNDLE/Contents/MacOS/LidGuardApp"
/usr/bin/ditto "$BIN_DIRECTORY/lidguard" "$APP_BUNDLE/Contents/MacOS/lidguard"
/usr/bin/ditto "$BIN_DIRECTORY/LidGuardHelper" "$APP_BUNDLE/Contents/Library/HelperTools/local.huangxiaomin.LidGuard.helper"
/usr/bin/ditto "$ROOT/Resources/local.huangxiaomin.LidGuard.helper.plist" "$APP_BUNDLE/Contents/Library/LaunchDaemons/local.huangxiaomin.LidGuard.helper.plist"
/usr/bin/ditto "$ROOT/Resources/install-helper.sh" "$APP_BUNDLE/Contents/Resources/install-helper.sh"
/usr/bin/ditto "$ROOT/Resources/uninstall-helper.sh" "$APP_BUNDLE/Contents/Resources/uninstall-helper.sh"

/bin/chmod 755 \
    "$APP_BUNDLE/Contents/MacOS/LidGuardApp" \
    "$APP_BUNDLE/Contents/MacOS/lidguard" \
    "$APP_BUNDLE/Contents/Library/HelperTools/local.huangxiaomin.LidGuard.helper" \
    "$APP_BUNDLE/Contents/Resources/install-helper.sh" \
    "$APP_BUNDLE/Contents/Resources/uninstall-helper.sh"

/usr/bin/codesign --force --sign - --identifier local.huangxiaomin.LidGuard.cli "$APP_BUNDLE/Contents/MacOS/lidguard"
/usr/bin/codesign --force --sign - --identifier local.huangxiaomin.LidGuard.helper "$APP_BUNDLE/Contents/Library/HelperTools/local.huangxiaomin.LidGuard.helper"
/usr/bin/codesign --force --deep --sign - --identifier local.huangxiaomin.LidGuard "$APP_BUNDLE"
/usr/bin/codesign --verify --deep --strict "$APP_BUNDLE"

echo "$APP_BUNDLE"
