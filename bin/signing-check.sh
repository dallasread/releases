#!/bin/sh
# Checks the Developer ID certificate before a build spends minutes on it.
#   APPLE_CERTIFICATE           base64 of the .p12
#   APPLE_CERTIFICATE_PASSWORD  its password
#   APPLE_SIGNING_IDENTITY      the certificate's name, or part of it, or its SHA-1
# Prints identity=<the certificate's name>, the form Tauri accepts, for $GITHUB_OUTPUT.
# The certificate must come from the G2 Sub-CA: the older Sub-CA's certificates stop signing on 2027-02-01.
set -e
fail() { echo "signing-check: $*" >&2; exit 1; }
[ -n "$APPLE_SIGNING_IDENTITY" ] || fail "APPLE_SIGNING_IDENTITY is not set"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
printf '%s' "$APPLE_CERTIFICATE" | base64 --decode > "$tmp/cert.p12"
# Keychain Access exports in an encryption OpenSSL 3 reads only with -legacy.
pem() { openssl pkcs12 -in "$tmp/cert.p12" -passin env:APPLE_CERTIFICATE_PASSWORD -nokeys -clcerts "$@" > "$tmp/cert.pem" 2>/dev/null; }
pem || pem -legacy || fail "cannot open APPLE_CERTIFICATE with APPLE_CERTIFICATE_PASSWORD"
issuer=$(openssl x509 -in "$tmp/cert.pem" -noout -issuer)
subject=$(openssl x509 -in "$tmp/cert.pem" -noout -subject)
sha1=$(openssl x509 -in "$tmp/cert.pem" -noout -fingerprint -sha1 | sed 's/.*=//; s/://g')
echo "$subject" | grep -q "Developer ID Application" || fail "not a Developer ID Application certificate: $subject"
echo "$issuer" | grep -Eq 'OU ?= ?G2([,/]|$)' || fail "not from the G2 Sub-CA: $issuer"
[ "$APPLE_SIGNING_IDENTITY" = "$sha1" ] || echo "$subject" | grep -qF "$APPLE_SIGNING_IDENTITY" ||
  fail "APPLE_SIGNING_IDENTITY names another certificate than $subject"
echo "signing-check: ok, $subject" >&2
echo "identity=$(openssl x509 -in "$tmp/cert.pem" -noout -subject -nameopt multiline | sed -n 's/^ *commonName *= //p')"
