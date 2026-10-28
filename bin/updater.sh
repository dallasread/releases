#!/bin/sh
# updater.sh <stapled .app> <tarball>
# Packs the app for the Tauri updater and signs it: <tarball> and <tarball>.sig.
#   TAURI_SIGNING_PRIVATE_KEY           the key itself (not a path)
#   TAURI_SIGNING_PRIVATE_KEY_PASSWORD  its password, empty for none
set -e
app=$1 tarball=$2
# macOS tar adds `._` AppleDouble entries for xattrs, and the updater cannot unpack them.
tar --no-mac-metadata --no-xattrs -czf "$tarball" -C "$(dirname "$app")" "$(basename "$app")"
key=$(mktemp)
trap 'rm -f "$key"' EXIT
printf '%s' "$TAURI_SIGNING_PRIVATE_KEY" > "$key"
# The signer reads the variables as -k and -p, which conflict with -f.
# -p always: without it the signer waits on a TTY for a passphrase.
password=$TAURI_SIGNING_PRIVATE_KEY_PASSWORD
env -u TAURI_SIGNING_PRIVATE_KEY -u TAURI_SIGNING_PRIVATE_KEY_PASSWORD \
  cargo tauri signer sign -f "$key" -p "$password" "$tarball" >/dev/null
