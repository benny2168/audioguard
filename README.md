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

6. **Cascaded Hidden Output & Input Pickers:**
   * Declutter your sound menus by hiding unwanted aggregate, display, or virtual devices.
   * Includes **👁️‍🗨️ Hidden Outputs** and **👁️‍🗨️ Hidden Inputs** submenus directly below Guarded Virtual Drivers.
   * When checked, hidden devices are automatically excluded from the main selection lists and preferred fallback pickers.

7. **Flexible Virtual Audio Support (Loopback, etc.):**
   * Virtual output devices (like Rogue Amoeba Loopback) can now be designated directly as your preferred fallback output or input.

8. **Automatic GitHub Update Detection & In-App Updating:**
   * AudioGuard automatically checks GitHub in the background for new versions.
   * When an update is detected, an interactive item (`🚀 Update Available: vX.X.X (Click to Install)`) appears at the top of the menu bar dropdown.
   * Clicking the banner performs a complete seamless in-app update and restarts AudioGuard with zero friction.
   * You can also click **Check for Updates...** in the menu footer at any time.

9. **Automatic Revert & Fallback Protection:**
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
🚀 Update Available: v1.3.0 (Click to Install)   <-- (Only when update available)
───────────────────────────────────────────────────────
⚡ Switch to Preferred Audio (Mac Studio Speakers) [⌘R]
───────────────────────────────────────────────────────
🔊 [━━━━━━━●━━━━━] 65%  (Interactive Volume Slider)
───────────────────────────────────────────────────────
🟢 AudioGuard: Active & Guarding
───────────────────────────────────────────────────────
OUTPUT DEVICES
  🔊 Mac Studio Speakers ✓
  🔊 XR18
  🔊 Loopback Audio
───────────────────────────────────────────────────────
INPUT DEVICES
  🎙️ Yeti X ✓
  🎙️ XR18
───────────────────────────────────────────────────────
🎵 Preferred Fallback Output  ▶ [Mac Studio Speakers, XR18, Loopback Audio, ...]
🎙️ Preferred Fallback Input   ▶ [Yeti X, XR18, ...]
🛡️ Guarded Virtual Drivers   ▶ [✓ Jump Desktop, Teams, Zoom, ...]
👁️‍🗨️ Hidden Outputs            ▶ [Odyssey G93SD, DisplayPort Audio, ...]
👁️‍🗨️ Hidden Inputs             ▶ [Logitech BRIO Mic, ...]
───────────────────────────────────────────────────────
✓ Auto-Revert on App Disconnect
✓ Block Guarded Drivers as Auto-Fallback
✓ Show iOS-Style Floating Volume HUD
✓ Show Notifications on Revert
✓ Launch at Login
───────────────────────────────────────────────────────
Check for Updates...
AudioGuard v1.3.0
───────────────────────────────────────────────────────
Quit AudioGuard [⌘Q]
```

---

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/benny2168/audioguard/main/uninstall.sh | bash
```
Or run `./uninstall.sh` locally.
