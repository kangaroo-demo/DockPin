# Changelog

## 0.1.4

- Fixed pin activation for stacked displays where the target display edge is partly covered by another display.
- DockPin now nudges and gates the nearest exposed real edge segment instead of always using the center of the selected edge.
- This improves layouts such as an external display above a built-in Retina display, where the Dock should remain on the upper display.

## 0.1.3

- Fixed re-enabling protection not reliably moving the Dock back to the pinned display.
- Reworked pin application to hold and pulse the pointer on the selected Dock edge long enough for macOS to switch Dock ownership.
- Manual apply actions now leave the pointer on the pinned Dock edge so the result is visible and stable.
- Opening the menu no longer restarts the event tap while protection is disabled.

## 0.1.2

- Added first-run setup guide for Gatekeeper and Accessibility permission.
- Stopped showing the Accessibility permission prompt automatically on every launch.
- Protection now starts and stops the event tap instead of only toggling an internal flag.
- Turning protection off nudges the Dock back to the system default outer display edge.
- Selecting Dock edge now syncs the macOS Dock orientation and applies the pin.
- Selecting anchor display now applies the pin immediately.
- Startup now reapplies the saved pin when protection is enabled.

## 0.1.1

- Added DockPin app icon and menu bar icon.
- Changed protection toggle to a stable checkbox item so the checkmark means protection is enabled.
- Fixed disabled Quit menu item.

## 0.1.0

- Initial public MVP.
- Menu bar app for pinning Dock edge behavior to a selected display.
- Display picker, edge picker, protection width, pass-through delay, Accessibility diagnostics, and launch-at-login toggle.
- English and Simplified Chinese UI and documentation.
- GitHub Actions release workflow.
