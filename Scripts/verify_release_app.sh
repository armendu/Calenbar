#!/bin/bash
#
# verify_release_app.sh APP
#
# Fails when a signed Calenbar.app isn't fit to ship. make_dmg.sh runs it
# before packaging, so `make dmg` and the release workflow stop here instead
# of publishing an app that can't read calendars.
#
# Missing calendar entitlements or usage text don't crash anything: EventKit
# just returns no calendars, and the menu shows an empty agenda.

set -euo pipefail

APP="${1:?usage: verify_release_app.sh APP}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INFO="$APP/Contents/Info.plist"
FAILURES=0

fail() {
    echo "verify_release_app: $1" >&2
    FAILURES=$((FAILURES + 1))
}

plist_value() {
    /usr/libexec/PlistBuddy -c "Print :$2" "$1" 2>/dev/null || true
}

[ -f "$INFO" ] || { echo "verify_release_app: no Info.plist in $APP" >&2; exit 1; }

# Version: the bundle must carry the project's MARKETING_VERSION, which the
# release workflow uses for the tag and the DMG name.
EXPECTED_VERSION=$(sed -nE 's/.*MARKETING_VERSION = ([^;]+);.*/\1/p' "$ROOT/Calenbar.xcodeproj/project.pbxproj" | sort -u)
ACTUAL_VERSION=$(plist_value "$INFO" CFBundleShortVersionString)
[ "$ACTUAL_VERSION" = "$EXPECTED_VERSION" ] \
    || fail "version is '$ACTUAL_VERSION', expected MARKETING_VERSION '$EXPECTED_VERSION'"

# Calendar access needs a usage description, or macOS never shows the prompt.
[ -n "$(plist_value "$INFO" NSCalendarsFullAccessUsageDescription)" ] \
    || fail "Info.plist has no NSCalendarsFullAccessUsageDescription"

# Entitlements of the signed app, not the source file.
ENTITLEMENTS=$(mktemp)
trap 'rm -f "$ENTITLEMENTS"' EXIT
codesign -d --entitlements - --xml "$APP" > "$ENTITLEMENTS" 2>/dev/null \
    || fail "couldn't read the app's entitlements"

for key in \
    com.apple.security.app-sandbox \
    com.apple.security.personal-information.calendars \
    com.apple.security.network.client; do
    [ "$(plist_value "$ENTITLEMENTS" "$key")" = "true" ] || fail "entitlement $key is missing"
done

# macOS refuses to launch an ad hoc app that claims this one.
[ -z "$(plist_value "$ENTITLEMENTS" com.apple.developer.usernotifications.time-sensitive)" ] \
    || fail "entitlement com.apple.developer.usernotifications.time-sensitive needs a provisioning profile"

# Hardened runtime, and a signature that holds across nested code.
codesign -dv "$APP" 2>&1 | grep -q 'flags=.*runtime' || fail "hardened runtime is off"
codesign --verify --deep --strict "$APP" 2>/dev/null || fail "code signature doesn't verify"

# The DMG is universal.
ARCHS=$(lipo -archs "$APP/Contents/MacOS/Calenbar" 2>/dev/null || true)
for arch in arm64 x86_64; do
    case " $ARCHS " in
        *" $arch "*) ;;
        *) fail "executable has no $arch slice (has: ${ARCHS:-none})" ;;
    esac
done

if [ "$FAILURES" -gt 0 ]; then
    echo "verify_release_app: $FAILURES problem(s) in $APP" >&2
    exit 1
fi
echo "verify_release_app: $APP is ready to ship ($ACTUAL_VERSION)"
