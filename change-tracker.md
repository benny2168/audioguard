# Change Tracker

## 2026-09-15 - Initial Release v1.0.0
- **Feature:** Created AudioGuard for macOS.
- **Problem Solved:** Jump Desktop Audio virtual driver hijacks macOS default audio output and fails to revert upon disconnection, and captures secondary audio fallback when headphones disconnect.
- **Implementation:**
  - Built Swift CoreAudio monitoring daemon and AppKit Menu Bar UI.
  - Implemented live Jump session stream detection.
  - Added user-customizable fallback device selection submenus and persistence.
  - Added `install.sh`, `build.sh`, and `uninstall.sh`.
- **Validation:** Tested on Mac Studio running macOS 26.3 with Behringer XR18, Blue Yeti X, and Mac Studio Speakers. Successfully verified live device switching and menu bar controls.
