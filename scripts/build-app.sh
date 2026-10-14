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
swift build
env -u CARGO_BUILD_TARGET cargo build --manifest-path vendor/paneru/Cargo.toml \
    --target-dir "$PWD/vendor/paneru/target" --locked --bin paneru --no-default-features --features miri-developer
bin=$(swift build --show-bin-path)
bundle="$PWD/.build/app/Miri Developer.app"
rm -rf "$bundle"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Helpers" "$bundle/Contents/Resources"
cp "$bin/Miri" "$bundle/Contents/MacOS/Miri"
cp vendor/paneru/target/debug/paneru "$bundle/Contents/Helpers/miri-engine"
[[ "$(lipo -archs "$bundle/Contents/MacOS/Miri")" == arm64 ]]
[[ "$(lipo -archs "$bundle/Contents/Helpers/miri-engine")" == arm64 ]]
cp LICENSE "$bundle/Contents/Resources/Miri-GPL-3.0.txt"
cp vendor/paneru/LICENSE.txt "$bundle/Contents/Resources/Paneru-MIT.txt"
printf '%s\n' "$revision" > "$bundle/Contents/Resources/engine-revision.txt"
cat > "$bundle/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>io.github.samanyudas.miri.dev</string>
<key>CFBundleName</key><string>Miri Developer</string>
<key>CFBundleDisplayName</key><string>Miri Developer</string>
<key>CFBundleExecutable</key><string>Miri</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>0.0.1</string>
<key>LSMinimumSystemVersion</key><string>27.0</string>
<key>NSHighResolutionCapable</key><true/>
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
