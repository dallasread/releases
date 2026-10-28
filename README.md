# releases

Shared GitHub Actions workflows that release Tauri apps for Apple platforms.
Follow Along, 66 Scripts and Reviewer (Dev Review) call them.
Each app's repo keeps a thin caller and its own secrets.

## Workflows

### `testflight.yml`

It builds the iOS app and uploads it to TestFlight.

- Input `project`: the folder that holds `src-tauri/`, `.tool-versions` and `ios-project.test.sh`. The default is `desktop`. Use `.` for the repo root.
- Input `xcode`: the Xcode version on the runner. The default is `26.6`.
- Secrets: `APPLE_API_KEY`, `APPLE_API_ISSUER`, `APPLE_API_KEY_P8` (base64 of the `.p8`), `APPLE_DISTRIBUTION_P12` (base64 of the Apple Distribution `.p12`), `APPLE_DISTRIBUTION_P12_PASSWORD`.

### `macos-release.yml`

It builds the macOS app for Apple Silicon and signs it with a Developer ID.
It notarizes and staples the app and the `.dmg`, and it checks both with `codesign`, `stapler` and `spctl`.
Then it creates the GitHub release of the pushed tag with generated notes.

- Input `project`: as above, without `ios-project.test.sh`.
- Secrets: `APPLE_CERTIFICATE` (base64 of the Developer ID Application `.p12`), `APPLE_CERTIFICATE_PASSWORD`, `APPLE_SIGNING_IDENTITY` (the certificate's name or SHA-1), `APPLE_API_KEY`, `APPLE_API_ISSUER`, `APPLE_API_KEY_P8`.
- Optional secrets: `TAURI_SIGNING_PRIVATE_KEY` (the updater key itself, not a path) and `TAURI_SIGNING_PRIVATE_KEY_PASSWORD`.
- Assets: `<Product-Name>_<version>_aarch64.dmg`. With the updater key, also `<Product-Name>_<version>_aarch64.app.tar.gz` and its `.sig`.

It stops before the build when:

- the tag is not `v<version>`. The version is the one in `tauri.conf.json`, or in the JSON file that `version` names, such as `../../package.json`.
- a signing secret is empty.
- the certificate is not a Developer ID Application certificate from the G2 Sub-CA. Certificates from the older Sub-CA stop signing on 2027-02-01.

The caller job needs `permissions: contents: write`.

## Caller

```yaml
name: Release

on:
  push:
    tags: ["v*"]

jobs:
  testflight:
    uses: dallasread/releases/.github/workflows/testflight.yml@main
    secrets:
      APPLE_API_KEY: ${{ secrets.APPLE_API_KEY }}
      APPLE_API_ISSUER: ${{ secrets.APPLE_API_ISSUER }}
      APPLE_API_KEY_P8: ${{ secrets.APPLE_API_KEY_P8 }}
      APPLE_DISTRIBUTION_P12: ${{ secrets.APPLE_DISTRIBUTION_P12 }}
      APPLE_DISTRIBUTION_P12_PASSWORD: ${{ secrets.APPLE_DISTRIBUTION_P12_PASSWORD }}

  macos:
    uses: dallasread/releases/.github/workflows/macos-release.yml@main
    permissions:
      contents: write
    secrets:
      APPLE_CERTIFICATE: ${{ secrets.APPLE_CERTIFICATE }}
      APPLE_CERTIFICATE_PASSWORD: ${{ secrets.APPLE_CERTIFICATE_PASSWORD }}
      APPLE_SIGNING_IDENTITY: ${{ secrets.APPLE_SIGNING_IDENTITY }}
      APPLE_API_KEY: ${{ secrets.APPLE_API_KEY }}
      APPLE_API_ISSUER: ${{ secrets.APPLE_API_ISSUER }}
      APPLE_API_KEY_P8: ${{ secrets.APPLE_API_KEY_P8 }}
```

A repo of another owner cannot pass `secrets: inherit`, so the caller names each secret.

## Scripts

`macos-release.yml` clones this repo at `main` and runs the scripts in `bin/`.
Each script has a `*.test.sh` beside it. Run all of them with:

```sh
for test in bin/*.test.sh; do sh "$test"; done
```
