# Changelog

## 0.2.0

### Added

- Added an optional running-app bar for every display that does not own the native Dock.
- Reveals the bar after a short hover near the bottom-inside edge and hides it after the pointer leaves.
- Shows regular running applications with their native icons, active-app indicator, hidden-app dimming, and click-to-activate behavior.
- Matches the system Dock tile size where practical and uses a floating native-style blur, continuous transparent corners, and a layout that does not reserve desktop space.
- Added a persistent, bilingual menu setting for the running-app bar plus runtime diagnostics and self-test commands.

### Fixed

- Prevented the native Dock from being summoned on exposed outer edges of non-target displays, avoiding duplicate native and custom bars.
- Fixed stacked-display cursor jumps by excluding shared display boundaries from Dock edge clamping. Normal movement between upper and lower displays now stays on the original horizontal path.
- Made pointer gates direction-aware so moving inward from an edge is never warped back outward.
- Re-pins the native Dock before enabling the running-app bar after Accessibility permission or event-tap access becomes available.
- Recovers automatically if macOS disables the event tap and hides the running-app bar whenever native-Dock protection is unavailable.
- Uses a stable designated requirement for local ad-hoc builds so rebuilding does not unnecessarily invalidate Accessibility permission.
- Fixed community release packaging when no code-signing identity is configured.

## 0.1.9

- Simplified the app icon for better readability at Dock and Finder sizes.
- Simplified the menu bar status icon.

## 0.1.8

- Improved the first-run setup guide with clearer Gatekeeper, Accessibility, and target display steps.
- Added English and Simplified Chinese menu screenshots to the README files.

## 0.1.7

- Removed the Enable Protection menu item; DockPin now applies automatically while the app is running.
- Quit now restores the Dock to the system default outer display edge before the app exits.
- Renamed user-facing anchor/protection wording to Target Display and Edge Range.

## 0.1.6

- Restored the more reliable Dock activation timing for enabling and disabling protection.
- Refreshes display topology before nudging the Dock back to the system default edge.
- Removed the user-facing Apply Pin Now menu item; DockPin now keeps that behavior internal.

## 0.1.5

- Improved pointer responsiveness by caching display topology instead of querying displays on every mouse event.
- Shortened Dock activation nudges now that stacked layouts use exposed real edge segments.
- Changed the default pass-through delay from 0.45s to 0.20s and added a 0.10s option.

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
