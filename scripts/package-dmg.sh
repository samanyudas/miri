#!/bin/bash
# Packages the built prototype into a compressed disk image and checks the mounted copy.
set -euo pipefail
cd "$(dirname "$0")/.."
app=.build/prototype/Miri.app
[[ -d "$app" ]] || { echo "Run scripts/build-prototype.sh first." >&2; exit 1; }
revision=$(git rev-parse --short HEAD)
dmg=".build/Miri-dev-$revision.dmg"
staging=$(mktemp -d)
mount=$(mktemp -d)
trap 'hdiutil detach -quiet "$mount" 2>/dev/null || true; rm -rf "$staging" "$mount"' EXIT
ditto "$app" "$staging/Miri.app"
ln -s /Applications "$staging/Applications"
rm -f "$dmg"
hdiutil create -quiet -volname Miri -srcfolder "$staging" -format UDZO -ov "$dmg"
hdiutil verify -quiet "$dmg"
hdiutil attach -quiet -readonly -nobrowse -mountpoint "$mount" "$dmg"
codesign --verify --strict "$mount/Miri.app"
codesign --verify --strict "$mount/Miri.app/Contents/Helpers/miri-engine"
cmp "$app/Contents/Resources/engine-revision.txt" "$mount/Miri.app/Contents/Resources/engine-revision.txt"
printf 'Packaged %s (%s)\n' "$dmg" "$(du -h "$dmg" | cut -f1)"
