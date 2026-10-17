# Contributing

Thanks for helping improve DockPin.

## Development

```sh
swift build
./scripts/build_app.sh
open dist/DockPin.app
```

DockPin needs Accessibility permission before the event tap can control pointer movement.

Run the recovery regression tests with full Xcode (XCTest is not included in the standalone Command Line Tools):

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test --scratch-path .build/xcode-tests
```

The tests simulate disconnect, reconnect, wake, and cancellation without moving the pointer or changing display settings.

## Pull Requests

- Keep changes focused.
- Include a short note about manual testing.
- Update both English and Chinese docs when user-facing behavior changes.
- Avoid adding telemetry, network calls, or background services.
