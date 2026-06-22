#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"$ROOT_DIR/scripts/build_app.sh" release

cd "$ROOT_DIR/dist"
rm -f DockPin.zip
xattr -cr DockPin.app || true
codesign --force --deep --sign - DockPin.app
ditto -c -k --norsrc --keepParent DockPin.app DockPin.zip

echo "Packaged $ROOT_DIR/dist/DockPin.zip"
