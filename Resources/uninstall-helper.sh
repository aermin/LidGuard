#!/bin/bash

set -euo pipefail

LABEL="local.huangxiaomin.LidGuard.helper"
PLIST_PATH="/Library/LaunchDaemons/$LABEL.plist"
HELPER_PATH="/Library/PrivilegedHelperTools/$LABEL"
CLI_PATH="/usr/local/bin/lidguard"
SUPPORT_DIRECTORY="/Library/Application Support/LidGuard"

if [[ "$EUID" -ne 0 ]]; then
    echo "uninstall-helper.sh must run as root" >&2
    exit 1
fi

/usr/bin/pmset -a disablesleep 0
if /usr/bin/pmset -g | /usr/bin/grep -Eq '^ *SleepDisabled +1$'; then
    echo "Failed to restore normal lid sleep" >&2
    exit 1
fi

/bin/launchctl bootout system "$PLIST_PATH" >/dev/null 2>&1 || true
/bin/rm -f "$PLIST_PATH" "$HELPER_PATH" "$CLI_PATH"
/bin/rm -rf "$SUPPORT_DIRECTORY"

echo "LidGuard helper removed; normal lid sleep restored"
