#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILT_APP="$($ROOT/scripts/build-app.sh | /usr/bin/tail -n 1)"
DESTINATION="/Applications/LidGuard.app"

/usr/bin/pkill -x LidGuardApp >/dev/null 2>&1 || true
/usr/bin/ditto "$BUILT_APP" "$DESTINATION"

COMMAND="/bin/bash '$DESTINATION/Contents/Resources/install-helper.sh' '$DESTINATION'"
ESCAPED_COMMAND="${COMMAND//\\/\\\\}"
ESCAPED_COMMAND="${ESCAPED_COMMAND//\"/\\\"}"
if ! /usr/bin/osascript -e "do shell script \"$ESCAPED_COMMAND\" with administrator privileges"; then
    /usr/bin/open "$DESTINATION"
    exit 1
fi

/usr/bin/open "$DESTINATION"
echo "Installed $DESTINATION"
