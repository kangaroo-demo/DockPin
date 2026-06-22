# Architecture

DockPin is intentionally small.

## Components

- `AppDelegate`: menu bar lifecycle, menu actions, permission prompts.
- `DisplayManager`: reads display names, bounds, main display state, and display UUIDs.
- `PreferencesStore`: persists user choices in `UserDefaults`.
- `EventTapController`: owns the Quartz event tap.
- `DockEdgeController`: applies the soft pointer gate near the selected display edge.
- `LaunchAtLoginController`: wraps `SMAppService.mainApp`.

## Principle

macOS does not provide a public API for assigning the Dock to a display. DockPin avoids private APIs and system modifications. It works by watching pointer movement and clamping the pointer briefly near a selected display edge. If the user keeps moving, DockPin releases the gate so normal cross-display movement still works.

## Build

The project is a Swift Package so it can build with Xcode Command Line Tools. The release script wraps the executable into a minimal `.app` bundle and signs it ad hoc for local use.
