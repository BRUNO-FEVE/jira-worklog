#!/bin/sh
# Packages WorklogBar.app into a drag-to-install DMG.
set -e
cd "$(dirname "$0")"

VERSION=0.1.1
./make_app.sh

DMG="build/WorklogBar-$VERSION.dmg"
STAGE="build/dmg-stage"
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R build/WorklogBar.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "WorklogBar" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
rm -rf "$STAGE"
echo "Created $DMG"
