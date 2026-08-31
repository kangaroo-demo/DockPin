# Privacy

DockPin is designed to be local-only.

- No analytics.
- No telemetry.
- No network requests.
- No account system.
- No personal data collection.

DockPin stores preferences locally using `UserDefaults`.

When the optional running-app bar is enabled, DockPin reads the local list of running applications to display their icons. This list is not stored or transmitted.

DockPin asks for Accessibility permission because macOS requires that permission for event tap tools that observe or alter pointer movement. DockPin uses that permission only to implement the soft edge gate near the selected Dock edge.
