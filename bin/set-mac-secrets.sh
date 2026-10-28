#!/bin/sh
# Set the macOS release secrets on Follow Along, 66 Scripts and Reviewer from a Developer ID .p12.
# Export the .p12 first: Keychain Access, the G2 "Developer ID Application" certificate
# (SHA-1 CC7FA092…), File > Export Items, with a password.
#   bin/set-mac-secrets.sh ~/Desktop/developer-id.p12
set -e
p12=${1:?usage: set-mac-secrets.sh <developer-id.p12>}
sha=CC7FA092A377A58B22ABE04BC3F3D562E29FEF7C
updater=$HOME/.config/66scripts/updater.key

printf 'Password of %s: ' "$p12"; stty -echo; read -r pw; stty echo; echo
certs=$(openssl pkcs12 -in "$p12" -passin "pass:$pw" -nokeys -clcerts 2>/dev/null ||
        openssl pkcs12 -legacy -in "$p12" -passin "pass:$pw" -nokeys -clcerts)
got=$(echo "$certs" | openssl x509 -noout -fingerprint -sha1 | sed 's/.*=//; s/://g')
[ "$got" = "$sha" ] || { echo "The .p12 holds $got, not the G2 certificate $sha" >&2; exit 1; }

set_secrets () { # <repo> <gh account>
  export GH_TOKEN; GH_TOKEN=$(gh auth token --user "$2")
  base64 -i "$p12" | gh secret set APPLE_CERTIFICATE -R "$1"
  printf '%s' "$pw" | gh secret set APPLE_CERTIFICATE_PASSWORD -R "$1"
  gh secret set APPLE_SIGNING_IDENTITY -R "$1" -b "$sha"
}
set_secrets followalong/www.followalong.com followalong
set_secrets dallasread/app.66scripts.com dallasread
set_secrets Dev-Review-Inc/dev.review dallasread
gh secret set TAURI_SIGNING_PRIVATE_KEY -R dallasread/app.66scripts.com < "$updater"
echo "Set. Delete $p12 now."
