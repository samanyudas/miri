#!/usr/bin/env bash
# Checks that every interface literal in Sources is localized, and keeps Localization/Localizable.xcstrings equal to
# the strings the Swift compiler extracts (#350).
# Usage: scripts/sync-strings.sh          adds new strings and removes ones the code no longer uses
#        scripts/sync-strings.sh --check  exits 1 when the catalog is out of date, and changes nothing
set -euo pipefail
cd "$(dirname "$0")/.."

catalog=Localization/Localizable.xcstrings
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# The compiler writes one .stringsdata file per source file, with every key that SwiftUI or String(localized:) looks up.
# A separate build path keeps these flags from invalidating the normal build.
# An incremental build rewrites only the files it compiles, so the folder lasts between runs,
# and a file whose source is gone is removed.
stringsdata=.build/strings/stringsdata
mkdir -p "$stringsdata"
swift build --product Miri --build-path .build/strings \
    -Xswiftc -emit-localized-strings -Xswiftc -emit-localized-strings-path -Xswiftc "$PWD/$stringsdata" >/dev/null
for file in "$stringsdata"/*.stringsdata; do
    source=$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["source"])' "$file")
    [[ -f "$source" ]] || rm "$file"
done

# Every literal that reads like interface text must be localized where it stands.
python3 scripts/check-strings.py --check "$stringsdata"

mkdir -p "$work/catalog"
cp "$catalog" "$work/catalog/Localizable.xcstrings"
xcrun xcstringstool sync "$work/catalog/Localizable.xcstrings" --stringsdata "$stringsdata"/*.stringsdata
# sync keeps a string the code no longer uses and marks it stale, so remove those here.
python3 - "$work/catalog/Localizable.xcstrings" <<'PY'
import json, sys
path = sys.argv[1]
catalog = json.load(open(path, encoding="utf-8"))
catalog["strings"] = {key: value for key, value in catalog["strings"].items() if value.get("extractionState") != "stale"}
with open(path, "w", encoding="utf-8") as file:
    json.dump(catalog, file, ensure_ascii=False, indent=2, sort_keys=True)
    file.write("\n")
PY

if [[ "${1:-}" == --check ]]; then
    if ! diff -u "$catalog" "$work/catalog/Localizable.xcstrings" >"$work/diff"; then
        head -40 "$work/diff" >&2
        echo "$catalog is out of date. Run make strings and commit the result." >&2
        exit 1
    fi
    echo "$catalog matches the strings in Sources."
else
    cp "$work/catalog/Localizable.xcstrings" "$catalog"
    echo "Updated $catalog."
fi
