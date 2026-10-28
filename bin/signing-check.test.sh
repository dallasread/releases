#!/bin/sh
# signing-check.sh against throwaway certificates, from a G2 Sub-CA and from an older one.
set -e
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail() { echo "signing-check.test: $*" >&2; exit 1; }
name="Developer ID Application: Test Person (TEAM123456)"

# ca <file> <subject>; leaf <ca> <file> <common name> [pkcs12 flags]: writes <file>.b64
ca() { openssl req -x509 -newkey rsa:2048 -nodes -days 2 -subj "$2" -keyout "$tmp/$1.key" -out "$tmp/$1.pem" 2>/dev/null; }
leaf() {
  openssl req -newkey rsa:2048 -nodes -subj "/CN=$3/OU=TEAM123456" -keyout "$tmp/$2.key" -out "$tmp/$2.csr" 2>/dev/null
  openssl x509 -req -in "$tmp/$2.csr" -CA "$tmp/$1.pem" -CAkey "$tmp/$1.key" -set_serial "0x$(openssl rand -hex 8)" -days 1 -out "$tmp/$2.pem" 2>/dev/null
  ca=$1 file=$2; shift 3
  openssl pkcs12 -export "$@" -inkey "$tmp/$file.key" -in "$tmp/$file.pem" -certfile "$tmp/$ca.pem" -passout pass:secret -out "$tmp/$file.p12"
  base64 < "$tmp/$file.p12" | tr -d '\n' > "$tmp/$file.b64"
}
check() { APPLE_CERTIFICATE=$(cat "$tmp/$1.b64") APPLE_CERTIFICATE_PASSWORD=${3:-secret} APPLE_SIGNING_IDENTITY=$2 "$here/signing-check.sh"; }
refuses() { if err=$(check "$@" 2>&1); then fail "passed: $*"; fi; echo "$err"; }

ca g2 "/CN=Developer ID Certification Authority/OU=G2/O=Apple Inc./C=US"
ca g1 "/CN=Developer ID Certification Authority/OU=Apple Certification Authority/O=Apple Inc./C=US"
leaf g2 good "$name"
# LibreSSL writes the legacy encryption by default and has no -legacy flag.
if openssl pkcs12 -help 2>&1 | grep -q -- -legacy; then leaf g2 legacy "$name" -legacy; else leaf g2 legacy "$name"; fi
leaf g1 old "$name"
leaf g2 dist "Apple Distribution: Test Person (TEAM123456)"
sha1=$(openssl x509 -in "$tmp/good.pem" -noout -fingerprint -sha1 | sed 's/.*=//; s/://g')

check good "$name" >/dev/null || fail "a G2 Developer ID named in full"
check good "$sha1" >/dev/null || fail "a G2 Developer ID named by SHA-1"
check legacy "$name" >/dev/null || fail "a .p12 in the legacy encryption Keychain Access writes"
refuses old "$name" | grep -q "G2 Sub-CA" || fail "the old Sub-CA was not named"
refuses dist "Apple Distribution" | grep -q "not a Developer ID Application" || fail "a distribution certificate was not named"
refuses good "Developer ID Application: Someone Else (OTHER12345)" | grep -q "names another certificate" || fail "a mismatched identity was not named"
refuses good "$name" wrong | grep -q "cannot open" || fail "a wrong password was not named"
refuses good "" | grep -q "APPLE_SIGNING_IDENTITY is not set" || fail "an empty identity was not named"

echo "signing-check: ok"
