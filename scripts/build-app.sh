#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
development=false
if [[ "${1:-}" == "--allow-dirty-engine" && $# == 1 ]]; then
    development=true
elif [[ $# != 0 ]]; then
    echo "Usage: $0 [--allow-dirty-engine]" >&2
    exit 2
fi
[[ "$(uname -m)" == arm64 ]] || { echo "This prototype requires an arm64 Mac." >&2; exit 1; }
revision=$(git -C vendor/paneru rev-parse HEAD)
pin=$(git ls-files --stage vendor/paneru | awk '{print $2}')
[[ "$revision" == "$pin" ]] || { echo "Engine HEAD differs from the recorded submodule pin." >&2; exit 1; }
git -C vendor/paneru merge-base --is-ancestor b1b6abbd3f1a4be138152b6f0389c9ff1b27a269 HEAD || {
    echo "The engine must descend from the required v0.5.2 base (b1b6abbd3f1a4be138152b6f0389c9ff1b27a269)." >&2
    exit 1
}
if [[ -n "$(git -C vendor/paneru status --porcelain)" ]]; then
    $development || { echo "The engine checkout is dirty. Commit and pin the patch first." >&2; exit 1; }
    revision="${revision}-dirty"
fi
# The linker reads the SDK version only from -isysroot or SDKROOT, and swift build passes neither to it.
# Without -isysroot it records the minimum macOS version as the SDK, and newer macOS then runs Miri in a compatibility mode.
sdk=$(xcrun --sdk macosx --show-sdk-path)
swift build -Xswiftc -Xclang-linker -Xswiftc -isysroot -Xswiftc -Xclang-linker -Xswiftc "$sdk"
env -u CARGO_BUILD_TARGET cargo build --manifest-path vendor/paneru/Cargo.toml \
    --target-dir "$PWD/vendor/paneru/target" --locked --bin paneru --no-default-features --features miri-developer
bin=$(swift build --show-bin-path)
bundle="$PWD/.build/app/Miri Developer.app"
rm -rf "$bundle"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Helpers" "$bundle/Contents/Resources"
iconset="$PWD/.build/app/AppIcon.iconset"
icon="$PWD/.build/app/AppIcon.svg"
rm -rf "$iconset"
mkdir "$iconset"
# Miri Developer draws the mark in yellow so it never passes for the released Miri, which keeps the blue icon.svg.
# Each yellow sits 35% of the way from its blue's OKLCH lightness to white, which keeps the gradients visible.
# Pale yellow rear windows blend together on the white tile, so the taller one gets lighter and the shorter one more solid.
cp assets/icon.svg "$icon"
while read -r from to; do
    grep -q "$from" "$icon" || { echo "assets/icon.svg no longer contains $from. Update the Developer icon swaps in $0." >&2; exit 1; }
    sed -i '' "s/$from/$to/g" "$icon"
done <<'SWAPS'
#A9D0FF #ECE191
#5F95FA #DEB70B
#5A63F2 #D69A09
#C4DCFF #F4E8B1
#B7B1F6 #FFC68A
#3446C8 #B68806
opacity="0.62" opacity="0.4"
opacity="0.5" opacity="0.9"
SWAPS
for size in 16 32 128 256 512; do
    sips -s format png -z "$size" "$size" "$icon" --out "$iconset/icon_${size}x${size}.png" >/dev/null
    sips -s format png -z $((size * 2)) $((size * 2)) "$icon" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o "$bundle/Contents/Resources/AppIcon.icns"
rm -rf "$iconset" "$icon"
cp assets/menubar-icon.svg assets/menubar-icon-stopped.svg "$bundle/Contents/Resources/"
cp "$bin/Miri" "$bundle/Contents/MacOS/Miri"
cp vendor/paneru/target/debug/paneru "$bundle/Contents/Helpers/miri-engine"
[[ "$(lipo -archs "$bundle/Contents/MacOS/Miri")" == arm64 ]]
[[ "$(lipo -archs "$bundle/Contents/Helpers/miri-engine")" == arm64 ]]
linked_sdk=$(vtool -show-build "$bundle/Contents/MacOS/Miri" | awk '$1 == "sdk" {print $2}')
[[ "$linked_sdk" == "$(xcrun --sdk macosx --show-sdk-version)" ]] || {
    echo "Miri records SDK $linked_sdk, not the installed SDK. Check the -isysroot linker flag above." >&2
    exit 1
}
cp LICENSE "$bundle/Contents/Resources/Miri-GPL-3.0.txt"
cp vendor/paneru/LICENSE.txt "$bundle/Contents/Resources/Paneru-MIT.txt"
printf '%s\n' "$revision" > "$bundle/Contents/Resources/engine-revision.txt"
# The string catalog becomes one .lproj folder per language. English needs only the plural forms,
# because each English string is its own key.
xcrun xcstringstool compile Localization/Localizable.xcstrings --output-directory "$bundle/Contents/Resources"
# macOS shows a translation only for a language that Info.plist lists, so list every language the catalog holds.
localizations=$(python3 - <<'PY'
import json
catalog = json.load(open("Localization/Localizable.xcstrings", encoding="utf-8"))
languages = {"en"} | {language for entry in catalog["strings"].values() for language in entry.get("localizations", {})}
print("".join(f"<string>{language}</string>" for language in sorted(languages)))
PY
)
cat > "$bundle/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>io.github.samanyudas.miri.dev</string>
<key>CFBundleName</key><string>Miri Developer</string>
<key>CFBundleDisplayName</key><string>Miri Developer</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleExecutable</key><string>Miri</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>0.0.1</string>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleLocalizations</key><array>$localizations</array>
<key>LSMinimumSystemVersion</key><string>15.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>LSUIElement</key><true/>
</dict></plist>
PLIST
# A stable identity keeps the Accessibility grant across rebuilds. Without one, ad-hoc signing still works.
identity=-
if security unlock-keychain -p miri-developer-signing "$HOME/Library/Keychains/miri-developer-signing.keychain-db" 2>/dev/null \
    && security find-identity -p codesigning | grep -q '"Miri Developer Local Signing"'; then
    identity="Miri Developer Local Signing"
fi
codesign --force --sign "$identity" --identifier io.github.samanyudas.miri.dev.engine "$bundle/Contents/Helpers/miri-engine"
codesign --force --sign "$identity" "$bundle"
codesign --verify --strict "$bundle/Contents/Helpers/miri-engine"
codesign --verify --strict "$bundle"
[[ "$identity" == - ]] && echo "Signed ad-hoc. Run scripts/setup-signing.sh to keep the Accessibility grant across rebuilds."
printf 'Built %s\nEngine source %s\nSigned with %s\n' "$bundle" "$revision" "$identity"
