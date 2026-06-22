#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"

"$ROOT_DIR/scripts/build_app.sh" release

cd "$ROOT_DIR/dist"
rm -f DockPin.zip

PACKAGE_DIR="$(mktemp -d /tmp/dockpin-package.XXXXXX)"
trap 'rm -rf "$PACKAGE_DIR"' EXIT
PACKAGE_APP="$PACKAGE_DIR/DockPin.app"

ditto --norsrc --noextattr DockPin.app "$PACKAGE_APP"

CODE_SIGN_ARGS=(--force --deep --sign "$CODE_SIGN_IDENTITY")
if [[ "$CODE_SIGN_IDENTITY" != "-" ]]; then
  CODE_SIGN_ARGS+=(--timestamp --options runtime)
fi
codesign "${CODE_SIGN_ARGS[@]}" "$PACKAGE_APP"

if [[ "${NOTARIZE:-0}" == "1" ]]; then
  : "${APPLE_ID:?APPLE_ID is required when NOTARIZE=1}"
  : "${APPLE_TEAM_ID:?APPLE_TEAM_ID is required when NOTARIZE=1}"
  : "${APPLE_APP_SPECIFIC_PASSWORD:?APPLE_APP_SPECIFIC_PASSWORD is required when NOTARIZE=1}"

  rm -f DockPin-notary.zip
  ditto -c -k --norsrc --noextattr --keepParent "$PACKAGE_APP" DockPin-notary.zip
  xcrun notarytool submit DockPin-notary.zip \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "$APPLE_APP_SPECIFIC_PASSWORD" \
    --wait
  xcrun stapler staple "$PACKAGE_APP"
  rm -f DockPin-notary.zip
fi

codesign --verify --deep --strict --verbose=2 "$PACKAGE_APP"
ditto -c -k --norsrc --noextattr --keepParent "$PACKAGE_APP" DockPin.zip

echo "Packaged $ROOT_DIR/dist/DockPin.zip"
