#!/bin/bash
#
# make_dmg.sh APP OUTPUT_DIR
#
# Signs a Release build of Calenbar.app ad hoc and packages it as
# OUTPUT_DIR/Calenbar-<version>.dmg, with an Applications shortcut to drag it
# onto. Prints the DMG's path.
#
# Calenbar has no Developer ID, so the signature is ad hoc and the app isn't
# notarized. It keeps the App Sandbox and MeetingBar's entitlements, except
# time-sensitive notifications: that one needs a provisioning profile, and
# macOS refuses to launch an ad hoc app that claims it.

set -euo pipefail

APP="${1:?usage: make_dmg.sh APP OUTPUT_DIR}"
OUTPUT_DIR="${2:?usage: make_dmg.sh APP OUTPUT_DIR}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENTITLEMENTS="$ROOT/Calenbar/MeetingBar.entitlements"

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

cp "$ENTITLEMENTS" "$WORK/app.entitlements"
/usr/libexec/PlistBuddy -c "Delete :com.apple.developer.usernotifications.time-sensitive" "$WORK/app.entitlements"

cat > "$WORK/helper.entitlements" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.app-sandbox</key>
	<true/>
</dict>
</plist>
EOF

# Sign nested code first, then the app itself.
HELPER="$APP/Contents/Library/LoginItems/LaunchAtLoginHelper.app"
if [ -d "$HELPER" ]; then
    codesign --force --options runtime --entitlements "$WORK/helper.entitlements" --sign - "$HELPER"
fi
codesign --force --options runtime --entitlements "$WORK/app.entitlements" --sign - "$APP"
codesign --verify --deep --strict "$APP"

mkdir -p "$WORK/dmg" "$OUTPUT_DIR"
cp -R "$APP" "$WORK/dmg/"
ln -s /Applications "$WORK/dmg/Applications"

DMG="$OUTPUT_DIR/Calenbar-$VERSION.dmg"
rm -f "$DMG"
hdiutil create -quiet -volname "Calenbar $VERSION" -srcfolder "$WORK/dmg" -fs HFS+ -format UDZO "$DMG"
echo "$DMG"
