#!/bin/bash
set -e
cd "$(dirname "$0")"

APP="Vigil.app"
DMG="Vigil.dmg"

[ -d "$APP" ] || ./build.sh

echo "▸ Building $DMG…"
rm -f "$DMG"
STAGING="$(mktemp -d)"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create -volname "Vigil" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGING"

echo "✓ Built ./$DMG  (drag Vigil into Applications)"
