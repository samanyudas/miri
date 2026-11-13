#!/bin/bash
# Packages the built prototype into a compressed disk image and checks the mounted copy.
set -euo pipefail
cd "$(dirname "$0")/.."
app="${1:-.build/app/Miri Developer.app}"
name=$(basename "$app" .app)
[[ -d "$app" ]] || { echo "Run scripts/build-app.sh first." >&2; exit 1; }
revision=$(git rev-parse --short HEAD)
dmg=".build/${name// /-}-$revision.dmg"
staging=$(mktemp -d)
mount=$(mktemp -d)
trap 'hdiutil detach -quiet "$mount" 2>/dev/null || true; rm -rf "$staging" "$mount"' EXIT
trap 'echo "package-dmg.sh: line $LINENO failed: $BASH_COMMAND" >&2' ERR

# hdiutil fails intermittently on CI runners, often with "Resource busy",
# while another process still holds the image. Retry, and show each failure.
retry() {
    local attempt
    for attempt in 1 2 3; do
        "$@" && return 0
        echo "package-dmg.sh: attempt $attempt failed: $*" >&2
        sleep 3
    done
    return 1
}
ditto "$app" "$staging/$name.app"
ln -s /Applications "$staging/Applications"
rm -f "$dmg"
retry hdiutil create -quiet -volname "$name" -srcfolder "$staging" -format UDZO -ov "$dmg"
retry hdiutil verify -quiet "$dmg"
retry hdiutil attach -quiet -readonly -nobrowse -mountpoint "$mount" "$dmg"
codesign --verify --strict "$mount/$name.app"
codesign --verify --strict "$mount/$name.app/Contents/Helpers/miri-engine"
cmp "$app/Contents/Resources/engine-revision.txt" "$mount/$name.app/Contents/Resources/engine-revision.txt"
printf 'Packaged %s (%s)\n' "$dmg" "$(du -h "$dmg" | cut -f1)"
