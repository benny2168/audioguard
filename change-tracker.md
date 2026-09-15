# Change Tracker

## 2026-09-15 - Version 1.1.0: Full Sound Control & Floating HUD
- **Feature Additions:**
  - Added interactive system volume slider and mute toggle directly in the menu bar dropdown.
  - Added iOS-style floating volume HUD capsule with glassmorphism, progress track, and percentage readout for keyboard shortcut adjustments.
  - Moved "⚡ Switch to Preferred Audio Now" (`⌘R`) to the top row.
  - Added direct Output and Input device selection lists for instant switching.
  - Added "🛡️ Guarded Virtual Drivers" submenu allowing users to check/uncheck individual virtual drivers (Jump Desktop, Microsoft Teams, Zoom, Loopback, BlackHole, Parrot, etc.).
- **Validation:**
  - Compiled and launched `/Applications/AudioGuard.app`.
  - Verified live volume slider adjustments, menu bar icon dynamic updates, and device switching.

## 2026-09-15 - Initial Release v1.0.0
- **Feature:** Created AudioGuard for macOS to prevent virtual audio driver hijacking and auto-revert on Jump Desktop disconnect.
