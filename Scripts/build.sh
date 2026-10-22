#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
PROJECT_DIR="$PWD"
arch_args=()
swift_arch_args=()
if [[ "${VINYL_UNIVERSAL:-0}" == "1" ]]; then
    arch_args=(-arch arm64 -arch x86_64)
    swift_arch_args=(--arch arm64 --arch x86_64)
fi
export CLANG_MODULE_CACHE_PATH="$PROJECT_DIR/.build/module-cache/clang"
export SWIFT_MODULECACHE_PATH="$PROJECT_DIR/.build/module-cache/swift"
APP_DIR="$PROJECT_DIR/build/Vinyl.app"
FRAMEWORK_DIR="$APP_DIR/Contents/Frameworks/MediaRemoteAdapter.framework"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$FRAMEWORK_DIR"

# Build the adapter from its vendored source; CMake is not required.
adapter_sources=()
while IFS= read -r path; do adapter_sources+=("$path"); done < <(find Vendor/mediaremote-adapter/src/adapter Vendor/mediaremote-adapter/src/private Vendor/mediaremote-adapter/src/utility -name '*.m' | sort)
xcrun clang "${arch_args[@]}" -dynamiclib -fobjc-arc -fvisibility=default -mmacosx-version-min=14.0 "-ffile-prefix-map=$PROJECT_DIR=/Vinyl" \
    -Wl,-install_name,@rpath/MediaRemoteAdapter.framework/MediaRemoteAdapter \
    -I Vendor/mediaremote-adapter/include -I Vendor/mediaremote-adapter/src \
    -framework Foundation -framework AppKit -framework UniformTypeIdentifiers \
    "${adapter_sources[@]}" -o "$FRAMEWORK_DIR/MediaRemoteAdapter"
cat > "$FRAMEWORK_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>local.sidea.MediaRemoteAdapter</string>
<key>CFBundleExecutable</key><string>MediaRemoteAdapter</string>
<key>CFBundlePackageType</key><string>FMWK</string>
</dict></plist>
PLIST
xcrun strip -S -x "$FRAMEWORK_DIR/MediaRemoteAdapter"
codesign --force --sign - "$FRAMEWORK_DIR"
swift_build_args=(--disable-sandbox --build-system native -c release --scratch-path "$PROJECT_DIR/.build" --cache-path "$PROJECT_DIR/.build/cache" --config-path "$PROJECT_DIR/.build/config" --security-path "$PROJECT_DIR/.build/security" -Xswiftc -debug-prefix-map -Xswiftc "$PROJECT_DIR=/Vinyl" -Xswiftc -file-prefix-map -Xswiftc "$PROJECT_DIR=/Vinyl")
swift build "${swift_arch_args[@]}" "${swift_build_args[@]}"
BIN_DIR=$(swift build "${swift_arch_args[@]}" "${swift_build_args[@]}" --show-bin-path)
cp "$BIN_DIR/SideA" "$APP_DIR/Contents/MacOS/Vinyl"
xcrun strip -S -x "$APP_DIR/Contents/MacOS/Vinyl"
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP_DIR/Contents/Resources/AppIcon.icns"
mkdir -p "$APP_DIR/Contents/Resources/Scenes"
cp Resources/Scenes/*.png "$APP_DIR/Contents/Resources/Scenes/"
cp Vendor/mediaremote-adapter/bin/mediaremote-adapter.pl "$APP_DIR/Contents/Resources/"
cp Vendor/mediaremote-adapter/LICENSE "$APP_DIR/Contents/Resources/MediaRemoteAdapter-LICENSE"
codesign --force --deep --sign - "$APP_DIR"
echo "Built: $APP_DIR"
