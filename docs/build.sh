#!/usr/bin/env bash
# Regenerate docs/states.png from states.html.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
[ -x "$CHROME" ] || { echo "Google Chrome is required." >&2; exit 1; }
"$CHROME" --headless --disable-gpu --screenshot=states.png \
  --window-size=530,80 --force-device-scale-factor=2 states.html >/dev/null 2>&1
echo "built states.png"
