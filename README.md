# AudioGuard for macOS 🛡️🔊

A modern, all-in-one native macOS Menu Bar application that replaces the default macOS Sound control. It manages system volume with an iOS-style floating volume HUD, provides one-click switching across all input and output devices, prevents virtual audio drivers (such as **Jump Desktop Audio**, Microsoft Teams, Zoom, Loopback, BlackHole) from hijacking your default sound, and automatically restores your physical speakers when remote sessions end.

---

## Key Features

1. **All-in-One Menu Bar Sound Control:**
   * Replaces the default macOS sound icon with an interactive menu containing a smooth volume slider, percentage readout, and mute toggle.
   * Dynamic menu bar icon that reflects real-time volume level, mute state, or active remote streaming.

2. **iOS-Style Floating Volume HUD:**
   * When volume is adjusted via keyboard shortcut keys (F11/F12 / Media keys) or hardware buttons, a frosted-glass floating capsule HUD smoothly animates at the top of your screen showing the speaker icon, level bar, and percentage.

3. **Direct Input & Output Device Selection:**
   * Direct dropdown lists of all detected Output and Input devices for instant one-click switching (marked with active `✓` indicators).

4. **⚡ Instant Preferred Audio Restore (Top Action):**
   * Prominently placed at the very top of the menu (`⌘R`) to immediately reset all sound and microphone routing to your designated physical setup.

5. **Selectable Guarded Virtual Drivers:**
   * Automatically discovers all virtual audio drivers on your Mac (Jump Desktop, Microsoft Teams, Zoom, Loopback, BlackHole, Parrot, etc.).
   * Includes a **🛡️ Guarded Virtual Drivers** submenu where you can check or uncheck individual drivers to guard against.

6. **Automatic Revert & Fallback Protection:**
   * **Allows remote audio when you need it:** Automatically detects when a guarded remote session is actively streaming audio and permits it.
   * **Auto-Reverts on Disconnect:** The moment a remote session ends, AudioGuard instantly restores your physical speakers.
   * **Blocks False Fallback:** When AirPods or headphones disconnect, AudioGuard intercepts in <200ms and forces macOS to your physical fallback device instead of an idle virtual driver.

---

## One-Line Installation on Any Mac

Open Terminal on any Mac and run:

```bash
curl -fsSL https://raw.githubusercontent.com/benny2168/audioguard/main/install.sh | bash
```

*Requirements: macOS 13.0+ (Ventura, Sonoma, Sequoia) and Xcode Command Line Tools (`xcode-select --install`).*

---

## Manual Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/benny2168/audioguard.git
   cd audioguard
   ```
2. Build and install:
   ```bash
   chmod +x install.sh
   ./install.sh
   ```

---

## Menu Layout

```text
⚡ Switch to Preferred Audio (Mac Studio Speakers) [⌘R]
───────────────────────────────────────────────────────
🔊 [━━━━━━━●━━━━━] 65%  (Interactive Volume Slider)
───────────────────────────────────────────────────────
🟢 AudioGuard: Active & Guarding
───────────────────────────────────────────────────────
OUTPUT DEVICES
  🔊 Mac Studio Speakers ✓
  🔊 XR18
  🔊 Odyssey G93SD
  📡 Jump Desktop Audio
───────────────────────────────────────────────────────
INPUT DEVICES
  🎙️ Yeti X ✓
  🎙️ XR18
  🎙️ Logitech BRIO
  📡 Jump Desktop Microphone
───────────────────────────────────────────────────────
🎵 Preferred Fallback Output  ▶
🎙️ Preferred Fallback Input   ▶
🛡️ Guarded Virtual Drivers   ▶ [✓ Jump Desktop, ✓ Teams, ✓ Zoom, ...]
───────────────────────────────────────────────────────
✓ Auto-Revert on App Disconnect
✓ Block Guarded Drivers as Auto-Fallback
✓ Show iOS-Style Floating Volume HUD
✓ Show Notifications on Revert
✓ Launch at Login
───────────────────────────────────────────────────────
Quit AudioGuard [⌘Q]
```

---

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/benny2168/audioguard/main/uninstall.sh | bash
```
Or run `./uninstall.sh` locally.
