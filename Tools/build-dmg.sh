#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT_DIR/CleanSpace.xcodeproj"
SCHEME="CleanSpaceDirect"
DERIVED_DATA="$ROOT_DIR/.build/dmg-derived-data"
WORK_DIR="$ROOT_DIR/.build/dmg-work"
DIST_DIR="$ROOT_DIR/dist"
VOLUME_NAME="CleanSpace Installer"
RW_DMG="$WORK_DIR/CleanSpace-rw.dmg"
STAGE_DIR="$WORK_DIR/stage"
DEVICE=""

cleanup() {
    if [[ -n "$DEVICE" ]]; then
        hdiutil detach "$DEVICE" -quiet || true
    fi
}
trap cleanup EXIT

rm -rf "$DERIVED_DATA" "$WORK_DIR"
mkdir -p "$STAGE_DIR" "$DIST_DIR"

echo "Building CleanSpace Direct (Release)…"
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGNING_ALLOWED=NO \
    clean build

BUILT_APP="$DERIVED_DATA/Build/Products/Release/CleanSpace.app"
STAGED_APP="$STAGE_DIR/CleanSpace.app"
[[ -d "$BUILT_APP" ]] || { echo "Release application was not produced." >&2; exit 1; }
ditto "$BUILT_APP" "$STAGED_APP"

IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | awk -F '"' '/Developer ID Application/ { print $2; exit }')"
if [[ -n "$IDENTITY" ]]; then
    echo "Signing application with $IDENTITY…"
    codesign --force --deep --sign "$IDENTITY" --options runtime --timestamp \
        --entitlements "$ROOT_DIR/Configurations/CleanSpaceDirect.entitlements" "$STAGED_APP"
    SIGNING_STATUS="Developer ID signed"
else
    echo "No Developer ID Application certificate found; applying a stable ad-hoc local signature."
    codesign --force --deep --sign - --options runtime \
        --requirements '=designated => identifier "com.cleanspace.direct"' \
        --entitlements "$ROOT_DIR/Configurations/CleanSpaceDirect.entitlements" "$STAGED_APP"
    SIGNING_STATUS="ad-hoc signed (local installation only)"
fi

codesign --verify --deep --strict --verbose=2 "$STAGED_APP"
ln -s /Applications "$STAGE_DIR/Applications"
touch "$STAGE_DIR/.metadata_never_index"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$STAGED_APP/Contents/Info.plist")"
OUTPUT_DMG="$DIST_DIR/CleanSpace-${VERSION}.dmg"
rm -f "$OUTPUT_DMG" "$OUTPUT_DMG.sha256"

hdiutil create -srcfolder "$STAGE_DIR" -fs HFS+ -volname "$VOLUME_NAME" -format UDRW "$RW_DMG" -quiet

ATTACH_OUTPUT="$(hdiutil attach -readwrite -noverify -noautoopen "$RW_DMG")"
DEVICE="$(printf '%s\n' "$ATTACH_OUTPUT" | awk '/Apple_HFS/ { print $1; exit }')"
MOUNT_DIR="$(printf '%s\n' "$ATTACH_OUTPUT" | sed -n 's/^.*Apple_HFS[[:space:]]*//p' | head -1)"
[[ -n "$DEVICE" && -d "$MOUNT_DIR" ]] || { echo "Could not mount working disk image." >&2; exit 1; }

cp "$STAGED_APP/Contents/Resources/AppIcon.icns" "$MOUNT_DIR/.VolumeIcon.icns"
SetFile -a C "$MOUNT_DIR"

osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set pathbar visible of container window to false
        set bounds of container window to {200, 180, 800, 560}
        set arrangement of icon view options of container window to not arranged
        set icon size of icon view options of container window to 128
        set text size of icon view options of container window to 13
        set position of item "CleanSpace.app" of container window to {165, 190}
        set position of item "Applications" of container window to {435, 190}
        update without registering applications
        delay 1
        close container window
    end tell
end tell
APPLESCRIPT

sync
hdiutil detach "$DEVICE" -quiet
DEVICE=""
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$OUTPUT_DMG" -quiet

if [[ -n "$IDENTITY" ]]; then
    codesign --force --sign "$IDENTITY" --timestamp "$OUTPUT_DMG"
    if [[ -n "${NOTARY_PROFILE:-}" ]]; then
        echo "Submitting disk image for notarization…"
        xcrun notarytool submit "$OUTPUT_DMG" --keychain-profile "$NOTARY_PROFILE" --wait
        xcrun stapler staple "$OUTPUT_DMG"
        SIGNING_STATUS="$SIGNING_STATUS and notarized"
    fi
fi

hdiutil verify "$OUTPUT_DMG" -quiet
shasum -a 256 "$OUTPUT_DMG" > "$OUTPUT_DMG.sha256"

echo
echo "Created: $OUTPUT_DMG"
echo "Signing: $SIGNING_STATUS"
echo "Checksum: $OUTPUT_DMG.sha256"
