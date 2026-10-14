#!/bin/bash
# Creates a stable self-signed code-signing identity for Miri Developer builds.
# An ad-hoc signature changes with every build, so macOS drops the Accessibility grant after each rebuild.
# A stable identity keeps the same designated requirement across builds, so the grant survives.
# This does not replace Developer ID signing or notarization. Running it again does nothing once it works.
set -euo pipefail

identity="Miri Developer Local Signing"
keychain="$HOME/Library/Keychains/miri-developer-signing.keychain-db"
# The keychain holds only this local identity, so a fixed password lets scripts unlock it after a reboot.
password="miri-developer-signing"

can_sign() {
    local probe status=1
    security unlock-keychain -p "$password" "$keychain" 2>/dev/null || true
    probe=$(mktemp)
    cp /bin/echo "$probe"
    codesign --force --sign "$identity" "$probe" >/dev/null 2>&1 && status=0
    rm -f "$probe"
    return $status
}

if can_sign; then
    echo "Signing identity '$identity' is ready."
    exit 0
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
/usr/bin/openssl req -x509 -newkey rsa:2048 -keyout "$work/key.pem" -out "$work/cert.pem" -days 3650 -nodes \
    -subj "/CN=$identity/O=Miri" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=critical,codeSigning" \
    -addext "basicConstraints=critical,CA:false" 2>/dev/null
# These algorithms import reliably with security(1) from both LibreSSL and OpenSSL 3.
/usr/bin/openssl pkcs12 -export -inkey "$work/key.pem" -in "$work/cert.pem" -out "$work/identity.p12" \
    -passout pass:"$password" -name "$identity" -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1

security delete-keychain "$keychain" 2>/dev/null || true
security create-keychain -p "$password" "$keychain"
security set-keychain-settings "$keychain"
security unlock-keychain -p "$password" "$keychain"
security import "$work/identity.p12" -k "$keychain" -P "$password" -T /usr/bin/codesign
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$password" "$keychain" >/dev/null
existing=()
while IFS= read -r line; do
    line=${line//\"/}
    existing+=("${line#"${line%%[![:space:]]*}"}")
done < <(security list-keychains -d user)
security list-keychains -d user -s "$keychain" "${existing[@]}"

can_sign || { echo "The identity was imported, but codesign cannot sign with it." >&2; exit 1; }
echo "Created signing identity '$identity'. scripts/build-app.sh uses it automatically."
