#!/usr/bin/env bash
#
# Regenerate the menu bar PNGs from the SVG sources.
#
# The 144 DPI tag is the important part: SwiftBar renders an `image=` payload
# at one point per pixel, so a 44px icon would be twice too tall for the menu
# bar. Tagging it 144 DPI makes NSImage treat it as @2x — 44 pixels drawn at
# 22 points, keeping Retina sharpness at the correct size.
#
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
[ -x "$CHROME" ] || { echo "Google Chrome is required to rasterise the SVGs." >&2; exit 1; }
for n in busy sleep warn; do
  "$CHROME" --headless --disable-gpu --screenshot="$n.png" \
    --window-size=44,44 --default-background-color=00000000 "$n.svg" >/dev/null 2>&1
  sips -s dpiWidth 144 -s dpiHeight 144 "$n.png" >/dev/null
  printf 'built %s.png\n' "$n"
done
