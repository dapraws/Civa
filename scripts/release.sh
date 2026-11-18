#!/bin/zsh
# Builds Civa for direct download: a Release archive signed with Developer ID, notarized by
# Apple, in a stapled DMG at build/release/Civa-<version>.dmg.
#
# One-time setup:
#   1. A "Developer ID Application" certificate in your keychain
#      (Xcode → Settings → Accounts → Manage Certificates → + → Developer ID Application).
#   2. Notary credentials saved as a keychain profile (use an app-specific password):
#        xcrun notarytool store-credentials civa-notary --apple-id <your Apple ID> --team-id YCNXP6AJT3
#
# Usage: scripts/release.sh            (NOTARY_PROFILE=<name> to use another profile)
set -euo pipefail

TEAM_ID=YCNXP6AJT3
PROFILE=${NOTARY_PROFILE:-civa-notary}
ROOT=${0:A:h:h}
OUT="$ROOT/build/release"

IDENTITY=$(security find-identity -v -p codesigning | grep -o "\"Developer ID Application: [^\"]*($TEAM_ID)\"" | head -1 | tr -d '"') || true
if [[ -z "$IDENTITY" ]]; then
    echo "No Developer ID Application certificate for team $TEAM_ID. See the setup notes at the top of this script." >&2
    exit 1
fi

rm -rf "$OUT"
mkdir -p "$OUT"
cd "$ROOT"

echo "Archiving…"
xcodebuild archive -project Civa.xcodeproj -scheme Civa -configuration Release \
    -destination 'generic/platform=macOS' -archivePath "$OUT/Civa.xcarchive" -quiet

cat > "$OUT/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key><string>developer-id</string>
    <key>teamID</key><string>$TEAM_ID</string>
    <key>signingStyle</key><string>automatic</string>
</dict>
</plist>
PLIST

echo "Exporting with Developer ID…"
xcodebuild -exportArchive -archivePath "$OUT/Civa.xcarchive" \
    -exportOptionsPlist "$OUT/ExportOptions.plist" -exportPath "$OUT/export" -quiet
APP="$OUT/export/Civa.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
DMG="$OUT/Civa-$VERSION.dmg"

echo "Making $DMG…"
# dmgbuild lays out the Finder window (background, icon spots, no toolbar) without scripting Finder.
# It lives in a venv under build/, so nothing is installed system-wide.
VENV="$ROOT/build/dmgbuild-venv"
[[ -x "$VENV/bin/dmgbuild" ]] || { /usr/bin/python3 -m venv "$VENV" && "$VENV/bin/pip" install -q "dmgbuild==1.6.5"; }
"$VENV/bin/dmgbuild" -s "$ROOT/scripts/dmg/settings.py" \
    -D app="$APP" -D icon="$APP/Contents/Resources/AppIcon.icns" \
    -D background="$ROOT/scripts/dmg/background.tiff" "Civa" "$DMG"
codesign --sign "$IDENTITY" --timestamp "$DMG"

echo "Notarizing (this takes a few minutes)…"
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$DMG"

echo "Checking with Gatekeeper…"
spctl --assess --type open --context context:primary-signature --verbose "$DMG"
echo "Done: $DMG"
