#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
PROJECT_DIR="$PWD"
APP_DIR="$PROJECT_DIR/build/Vinyl.app"
if [[ ! -d "$APP_DIR" ]]; then
    echo "Build Vinyl first: VINYL_UNIVERSAL=1 Scripts/build.sh" >&2
    exit 1
fi
codesign --verify --deep --strict "$APP_DIR"
python3 Scripts/check-app-privacy.py "$APP_DIR"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP_DIR/Contents/Info.plist")
STAGING=$(mktemp -d "$PROJECT_DIR/build/dmg-stage.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT
ditto "$APP_DIR" "$STAGING/Vinyl.app"
ln -s /Applications "$STAGING/Applications"
cp LICENSE "$STAGING/Vinyl-LICENSE.txt"
cat > "$STAGING/Read Me.txt" <<'TEXT'
Vinyl

Drag Vinyl.app into Applications, eject this disk, then open Vinyl from Applications.
Look for the optical-disc icon in the menu bar; Vinyl has no Dock window.
Start music in Yandex Music, Spotify, or Apple Music.

Requires macOS 14 or later. Universal builds contain Apple Silicon and Intel code.
This development build is ad-hoc signed and is not notarized by Apple.
If macOS blocks opening your trusted copy, follow Apple's Privacy & Security
instructions: https://support.apple.com/102445

Yandex desktop playback needs no browser extension. Browser playback requires
the companion extension and native host setup supplied in the source project.
The optional High-Resolution Yandex Covers menu setting sends title and artist
to Yandex's catalogue. It is off by default on a new Mac.
TEXT
mkdir -p "$PROJECT_DIR/dist"
OUTPUT="$PROJECT_DIR/dist/Vinyl-$VERSION.dmg"
hdiutil create -volname Vinyl -srcfolder "$STAGING" -format UDZO -ov "$OUTPUT"
hdiutil verify "$OUTPUT"
(cd "$PROJECT_DIR/dist" && shasum -a 256 "$(basename "$OUTPUT")" > "$(basename "$OUTPUT").sha256")
echo "Created: $OUTPUT"
