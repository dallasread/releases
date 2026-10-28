#!/bin/sh
# app-info.sh <src-tauri dir> <tag>
# Prints name=, slug= and version= for $GITHUB_OUTPUT, and fails unless the tag is v<version>.
# tauri.conf.json's version is the number itself or a path to a JSON file holding it.
set -e
node - "$1" "$2" <<'JS'
const fs = require("fs"), path = require("path");
const [dir, tag] = process.argv.slice(2);
const conf = JSON.parse(fs.readFileSync(path.join(dir, "tauri.conf.json"), "utf8"));
let version = conf.version;
if (version && version.endsWith(".json")) version = JSON.parse(fs.readFileSync(path.resolve(dir, version), "utf8")).version;
if (!version) { console.error(`app-info: no version in ${dir}/tauri.conf.json`); process.exit(1); }
if (tag !== `v${version}`) { console.error(`app-info: tag ${tag} does not name version ${version}`); process.exit(1); }
console.log(`name=${conf.productName}\nslug=${conf.productName.replace(/ /g, "-")}\nversion=${version}`);
JS
