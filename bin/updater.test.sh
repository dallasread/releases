#!/bin/sh
# updater.sh on a throwaway .app, with cargo stubbed to record how the signer is called.
set -e
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail() { echo "updater.test: $*" >&2; exit 1; }

mkdir -p "$tmp/bin" "$tmp/bundle/My App.app/Contents/MacOS"
echo app > "$tmp/bundle/My App.app/Contents/MacOS/my-app"
# An xattr is what makes macOS tar add the ._ entries the updater cannot unpack.
xattr -w com.example.test yes "$tmp/bundle/My App.app/Contents/MacOS/my-app"
cat > "$tmp/bin/cargo" <<STUB
#!/bin/sh
echo "\$*" > "$tmp/args"
echo "\${TAURI_SIGNING_PRIVATE_KEY-unset} \${TAURI_SIGNING_PRIVATE_KEY_PASSWORD-unset}" > "$tmp/env"
cp "\$5" "$tmp/key"
echo "\$5" > "$tmp/keypath"
eval "last=\\\${\$#}"
echo signature > "\$last.sig"
STUB
chmod +x "$tmp/bin/cargo"

sign() { TAURI_SIGNING_PRIVATE_KEY=the-key TAURI_SIGNING_PRIVATE_KEY_PASSWORD=$1 PATH="$tmp/bin:$PATH" \
  "$here/updater.sh" "$tmp/bundle/My App.app" "$tmp/out/My-App_1.0.0_aarch64.app.tar.gz"; }

mkdir "$tmp/out"
sign ''
tarball=$tmp/out/My-App_1.0.0_aarch64.app.tar.gz
tar -tzf "$tarball" > "$tmp/list"
grep -qx "My App.app/Contents/MacOS/my-app" "$tmp/list" || fail "the app is not at the top of the tarball: $(cat "$tmp/list")"
! grep -q '\._' "$tmp/list" || fail "AppleDouble entries: $(cat "$tmp/list")"
[ "$(cat "$tarball.sig")" = signature ] || fail "no .sig beside the tarball"
[ "$(cat "$tmp/key")" = the-key ] || fail "the signer did not get the key as a file"
[ "$(cat "$tmp/env")" = "unset unset" ] || fail "the signer saw the key variables: $(cat "$tmp/env")"
case $(cat "$tmp/args") in
  "tauri signer sign -f "*" -p  $tarball") ;;
  *) fail "signer args: $(cat "$tmp/args")" ;;
esac
[ ! -e "$(cat "$tmp/keypath")" ] || fail "the key file was left behind"

sign 'pass word'
grep -q -- "-p pass word $tarball" "$tmp/args" || fail "the password was not passed: $(cat "$tmp/args")"

echo "updater: ok"
