#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${1:-release}"
APP_DIR="$ROOT_DIR/dist/DockPin.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"
STAGING_DIR="$(mktemp -d /tmp/dockpin-build.XXXXXX)"
STAGING_APP="$STAGING_DIR/DockPin.app"
STAGING_CONTENTS="$STAGING_APP/Contents"
STAGING_MACOS="$STAGING_CONTENTS/MacOS"
STAGING_RESOURCES="$STAGING_CONTENTS/Resources"
trap 'rm -rf "$STAGING_DIR"' EXIT

cd "$ROOT_DIR"

swift build -c "$CONFIGURATION"
BIN_PATH="$(swift build -c "$CONFIGURATION" --show-bin-path)"

rm -rf "$APP_DIR"
mkdir -p "$STAGING_MACOS" "$STAGING_RESOURCES"

cp "$BIN_PATH/DockPin" "$STAGING_MACOS/DockPin"
cp "Info.plist" "$STAGING_CONTENTS/Info.plist"

if [[ -d Resources ]]; then
  cp -R Resources/. "$STAGING_RESOURCES/"
  find "$STAGING_RESOURCES" -name "*.iconset" -type d -prune -exec rm -rf {} +
fi

xattr -cr "$STAGING_APP" || true

CODE_SIGN_ARGS=(--force --deep --sign "$CODE_SIGN_IDENTITY")
if [[ "$CODE_SIGN_IDENTITY" != "-" ]]; then
  CODE_SIGN_ARGS+=(--timestamp --options runtime)
fi

codesign "${CODE_SIGN_ARGS[@]}" "$STAGING_APP"
codesign --verify --deep --strict --verbose=2 "$STAGING_APP"

mkdir -p "$(dirname "$APP_DIR")"
ditto --norsrc --noextattr "$STAGING_APP" "$APP_DIR"

echo "Built $APP_DIR"
