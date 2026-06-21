#!/bin/bash
# Packages the built AverageTouchTool.app into a distributable .dmg with a
# drag-to-Applications layout. Run ./package.sh first (it produces the .app).
#
#   ./make-dmg.sh        -> AverageTouchTool.dmg
#
# The asset name is intentionally unversioned so the website's
# releases/latest/download/AverageTouchTool.dmg link is always stable; the
# version lives in the app's Info.plist and the GitHub release tag/title.
set -euo pipefail
cd "$(dirname "$0")"

APP="AverageTouchTool.app"
VOL="AverageTouchTool"
DMG="AverageTouchTool.dmg"

[ -d "$APP" ] || { echo "ERROR: $APP not found — run ./package.sh first."; exit 1; }

STAGE="$(mktemp -d)/AverageTouchTool"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"   # drag-to-install target

rm -f "$DMG"
hdiutil create -volname "$VOL" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$(dirname "$STAGE")"

echo "Built ./$DMG ($(du -h "$DMG" | cut -f1))"
