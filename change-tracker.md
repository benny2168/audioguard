# Change Tracker

## 2026-09-15 - Version 1.3.0: GitHub Update Detection & Direct In-App Updater
- **Feature Additions:**
  - **Auto-Update Engine:** Created `UpdateManager` that periodically checks GitHub for new versions of AudioGuard via `Info.plist`.
  - **Dynamic Menu Option:** When a new version is detected on GitHub, a prominent action item (`🚀 Update Available: vX.X.X - Click to Install`) is dynamically injected at the top of the menu bar dropdown.
  - **One-Click In-App Updating:** Clicking the update banner executes a background installer that compiles the newest release, replaces the app bundle, and relaunches AudioGuard automatically.
  - **Manual Update Checking:** Added "Check for Updates..." and version information at the bottom of the menu.
- **Validation:**
  - Compiled and launched `/Applications/AudioGuard.app`.
  - Verified menu structure, update check network routine, and version reflection.

## 2026-09-15 - Version 1.2.0: App Icon, Loopback Fallback & Hidden Device Management
- **Fixes & Enhancements:**
  - **Menu Bar Status Label:** Removed text clutter (`Remote`) from the menu bar button, maintaining a clean volume/speaker status icon.
  - **Custom App Icon:** Integrated high-resolution custom app branding icon into `.app` bundle Resources (`AppIcon.icns`) and `Info.plist`.
  - **Loopback & Virtual Fallback Support:** Unlocked virtual audio devices (such as Loopback) to be designated as preferred fallback outputs/inputs.
  - **Hidden Device Management:** Added cascaded submenus below Guarded Virtual Drivers for "👁️‍🗨️ Hidden Outputs" and "👁️‍🗨️ Hidden Inputs". Checked devices are cleanly hidden from the main device lists and preferred fallback pickers.
  - **Updated Installers:** Updated `build.sh` and `install.sh` to package `AppIcon.icns` and handle smooth app relaunch.
- **Validation:**
  - Built with `./build.sh` and installed via `./install.sh`.
  - Verified menu bar icon without text clutter, custom icon packaging, and device hiding logic.

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
