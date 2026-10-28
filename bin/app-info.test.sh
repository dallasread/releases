#!/bin/sh
# app-info.sh against throwaway Tauri projects.
set -e
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail() { echo "app-info.test: $*" >&2; exit 1; }

# A literal version, as 66 Scripts and Dev Review carry it.
mkdir -p "$tmp/literal/src-tauri"
echo '{ "productName": "66 Scripts", "version": "0.5.14" }' > "$tmp/literal/src-tauri/tauri.conf.json"
out=$("$here/app-info.sh" "$tmp/literal/src-tauri" v0.5.14)
[ "$out" = "name=66 Scripts
slug=66-Scripts
version=0.5.14" ] || fail "literal: got $out"

# A path to a package.json, as Follow Along carries it.
mkdir -p "$tmp/path/desktop/src-tauri"
echo '{ "productName": "Follow Along", "version": "../../package.json" }' > "$tmp/path/desktop/src-tauri/tauri.conf.json"
echo '{ "name": "followalong", "version": "1.3.1" }' > "$tmp/path/package.json"
out=$("$here/app-info.sh" "$tmp/path/desktop/src-tauri" v1.3.1)
[ "$out" = "name=Follow Along
slug=Follow-Along
version=1.3.1" ] || fail "path: got $out"

# A tag that names another version, or a branch, stops the release.
if err=$("$here/app-info.sh" "$tmp/literal/src-tauri" v0.5.13 2>&1); then fail "a wrong tag passed"; fi
echo "$err" | grep -q "tag v0.5.13 does not name version 0.5.14" || fail "wrong tag: got $err"
if "$here/app-info.sh" "$tmp/literal/src-tauri" main >/dev/null 2>&1; then fail "a branch passed"; fi

# No version at all.
echo '{ "productName": "X" }' > "$tmp/literal/src-tauri/tauri.conf.json"
if err=$("$here/app-info.sh" "$tmp/literal/src-tauri" v1.0.0 2>&1); then fail "no version passed"; fi
echo "$err" | grep -q "no version" || fail "no version: got $err"

echo "app-info: ok"
