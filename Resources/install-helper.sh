#!/bin/bash

set -euo pipefail

APP_BUNDLE="${1:-/Applications/LidGuard.app}"
LABEL="local.huangxiaomin.LidGuard.helper"
HELPER_SOURCE="$APP_BUNDLE/Contents/Library/HelperTools/$LABEL"
HELPER_DESTINATION="/Library/PrivilegedHelperTools/$LABEL"
PLIST_SOURCE="$APP_BUNDLE/Contents/Library/LaunchDaemons/$LABEL.plist"
PLIST_DESTINATION="/Library/LaunchDaemons/$LABEL.plist"
CLI_SOURCE="$APP_BUNDLE/Contents/MacOS/lidguard"
CLI_DESTINATION="/usr/local/bin/lidguard"
SUPPORT_DIRECTORY="/Library/Application Support/LidGuard"
SECURITY_PATH="$SUPPORT_DIRECTORY/security.json"

if [[ "$EUID" -ne 0 ]]; then
    echo "install-helper.sh must run as root" >&2
    exit 1
fi

for required in "$HELPER_SOURCE" "$PLIST_SOURCE" "$CLI_SOURCE"; do
    if [[ ! -f "$required" ]]; then
        echo "Missing bundle component: $required" >&2
        exit 1
    fi
done

CONSOLE_USER="$(/usr/bin/stat -f '%Su' /dev/console)"
OWNER_UID="$(/usr/bin/id -u "$CONSOLE_USER")"

requirement_for() {
    /usr/bin/codesign -dr - "$1" 2>&1 | /usr/bin/sed -n 's/^.*# designated => //p'
}

APP_REQUIREMENT="$(requirement_for "$APP_BUNDLE")"
CLI_REQUIREMENT="$(requirement_for "$CLI_SOURCE")"
if [[ -z "$APP_REQUIREMENT" || -z "$CLI_REQUIREMENT" ]]; then
    echo "Unable to determine client code signing requirements" >&2
    exit 1
fi
CLIENT_REQUIREMENT="($APP_REQUIREMENT) or ($CLI_REQUIREMENT)"

/bin/mkdir -p "/Library/PrivilegedHelperTools" "/Library/LaunchDaemons" "$SUPPORT_DIRECTORY" "/usr/local/bin"
/bin/chmod 755 "/Library/PrivilegedHelperTools" "/Library/LaunchDaemons" "$SUPPORT_DIRECTORY" "/usr/local/bin"

/bin/launchctl bootout system "$PLIST_DESTINATION" >/dev/null 2>&1 || true

/usr/bin/ditto "$HELPER_SOURCE" "$HELPER_DESTINATION"
/usr/sbin/chown root:wheel "$HELPER_DESTINATION"
/bin/chmod 755 "$HELPER_DESTINATION"

/usr/bin/ditto "$PLIST_SOURCE" "$PLIST_DESTINATION"
/usr/sbin/chown root:wheel "$PLIST_DESTINATION"
/bin/chmod 644 "$PLIST_DESTINATION"

/usr/bin/ditto "$CLI_SOURCE" "$CLI_DESTINATION"
/usr/sbin/chown root:wheel "$CLI_DESTINATION"
/bin/chmod 755 "$CLI_DESTINATION"

/usr/bin/plutil -create xml1 "$SECURITY_PATH"
/usr/bin/plutil -insert schemaVersion -integer 1 "$SECURITY_PATH"
/usr/bin/plutil -insert ownerUID -integer "$OWNER_UID" "$SECURITY_PATH"
/usr/bin/plutil -insert clientRequirement -string "$CLIENT_REQUIREMENT" "$SECURITY_PATH"
/usr/sbin/chown root:wheel "$SECURITY_PATH"
/bin/chmod 644 "$SECURITY_PATH"

/bin/launchctl bootstrap system "$PLIST_DESTINATION"
/bin/launchctl kickstart -k "system/$LABEL"
/bin/launchctl print "system/$LABEL" >/dev/null

echo "LidGuard helper installed for UID $OWNER_UID"
