#!/bin/zsh
# Builds Civa for direct download: a Release archive signed with Developer ID, notarized by
# Apple, in a stapled DMG at build/release/Civa-<version>.dmg, plus the Sparkle appcast.xml
# that tells installed copies about it.
#
# One-time setup:
#   1. A "Developer ID Application" certificate in your keychain
#      (Xcode → Settings → Accounts → Manage Certificates → + → Developer ID Application).
#   2. Notary credentials saved as a keychain profile (use an app-specific password):
#        xcrun notarytool store-credentials civa-notary --apple-id <your Apple ID> --team-id YCNXP6AJT3
#   3. A Sparkle signing key in your keychain, and its public half in the project:
#        build/release-dd/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys
#      (run this script once first so the tool is downloaded), then put the printed public key in
#      the Civa target's SPARKLE_PUBLIC_KEY build setting. Back up the key with generate_keys -x.
#
# Each release: bump MARKETING_VERSION and CURRENT_PROJECT_VERSION (Sparkle compares the build
# number), and add the version to CHANGELOG.md. The appcast's release notes come from it.
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
DD="$ROOT/build/release-dd"
xcodebuild archive -project Civa.xcodeproj -scheme Civa -configuration Release \
    -destination 'generic/platform=macOS' -archivePath "$OUT/Civa.xcarchive" -derivedDataPath "$DD" -quiet
SPARKLE_BIN="$DD/SourcePackages/artifacts/sparkle/Sparkle/bin"

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
if [[ -z "$(/usr/libexec/PlistBuddy -c "Print SUPublicEDKey" "$APP/Contents/Info.plist" 2>/dev/null)" ]]; then
    echo "SPARKLE_PUBLIC_KEY is empty, so this build couldn't check updates. See step 3 at the top of this script." >&2
    exit 1
fi

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

echo "Writing the appcast…"
# Only the newest version: Sparkle needs nothing older. The DMG goes in the GitHub release v$VERSION.
FEED="$OUT/appcast"
mkdir -p "$FEED"
cp "$DMG" "$FEED/"
"$ROOT/scripts/release-notes.py" "$ROOT/CHANGELOG.md" "$VERSION" > "$FEED/Civa-$VERSION.html"
"$SPARKLE_BIN/generate_appcast" --embed-release-notes \
    --download-url-prefix "https://github.com/dapraws/Civa/releases/download/v$VERSION/" \
    -o "$OUT/appcast.xml" "$FEED"
echo "Done: $DMG and $OUT/appcast.xml. Upload both to the GitHub release v$VERSION of dapraws/Civa."
