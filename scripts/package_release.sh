#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"$ROOT_DIR/scripts/build_app.sh" release

cd "$ROOT_DIR/dist"
rm -f DockPin.zip
xattr -cr DockPin.app || true

if [[ "${NOTARIZE:-0}" == "1" ]]; then
  : "${APPLE_ID:?APPLE_ID is required when NOTARIZE=1}"
  : "${APPLE_TEAM_ID:?APPLE_TEAM_ID is required when NOTARIZE=1}"
  : "${APPLE_APP_SPECIFIC_PASSWORD:?APPLE_APP_SPECIFIC_PASSWORD is required when NOTARIZE=1}"

  rm -f DockPin-notary.zip
  ditto -c -k --norsrc --keepParent DockPin.app DockPin-notary.zip
  xcrun notarytool submit DockPin-notary.zip \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "$APPLE_APP_SPECIFIC_PASSWORD" \
    --wait
  xcrun stapler staple DockPin.app
  rm -f DockPin-notary.zip
fi

codesign --verify --deep --strict --verbose=2 DockPin.app
ditto -c -k --norsrc --keepParent DockPin.app DockPin.zip

echo "Packaged $ROOT_DIR/dist/DockPin.zip"
