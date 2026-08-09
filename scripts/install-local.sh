#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILT_APP="$($ROOT/scripts/build-app.sh | /usr/bin/tail -n 1)"
DESTINATION="/Applications/LidGuard.app"

COMMAND="/usr/bin/ditto '$BUILT_APP' '$DESTINATION' && /bin/bash '$DESTINATION/Contents/Resources/install-helper.sh' '$DESTINATION'"
ESCAPED_COMMAND="${COMMAND//\\/\\\\}"
ESCAPED_COMMAND="${ESCAPED_COMMAND//\"/\\\"}"
/usr/bin/osascript -e "do shell script \"$ESCAPED_COMMAND\" with administrator privileges"

/usr/bin/open "$DESTINATION"
echo "Installed $DESTINATION"
