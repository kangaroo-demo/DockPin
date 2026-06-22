#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${1:-release}"
APP_DIR="$ROOT_DIR/dist/DockPin.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"

cd "$ROOT_DIR"

swift build -c "$CONFIGURATION"
BIN_PATH="$(swift build -c "$CONFIGURATION" --show-bin-path)"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BIN_PATH/DockPin" "$MACOS_DIR/DockPin"
cp "Info.plist" "$CONTENTS_DIR/Info.plist"

if [[ -d Resources ]]; then
  cp -R Resources/. "$RESOURCES_DIR/"
  find "$RESOURCES_DIR" -name "*.iconset" -type d -prune -exec rm -rf {} +
fi

xattr -cr "$APP_DIR" || true

CODE_SIGN_ARGS=(--force --deep --sign "$CODE_SIGN_IDENTITY")
if [[ "$CODE_SIGN_IDENTITY" != "-" ]]; then
  CODE_SIGN_ARGS+=(--timestamp --options runtime)
fi

codesign "${CODE_SIGN_ARGS[@]}" "$APP_DIR"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

echo "Built $APP_DIR"
