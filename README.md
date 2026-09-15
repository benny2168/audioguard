# AudioGuard for macOS 🛡️🔊

A lightweight, native macOS Menu Bar application that prevents virtual audio drivers (such as **Jump Desktop Audio**, Zoom, or Teams) from hijacking your default sound output, and automatically restores your physical speakers when remote sessions end.

---

## The Problem
When using **Jump Desktop** with audio sharing enabled:
1. Jump Desktop switches macOS default audio to its virtual driver (`Jump Desktop Audio`).
2. Upon disconnection, Jump Desktop often fails to restore the original audio output.
3. Because virtual audio drivers never physically disconnect, macOS CoreAudio treats them as "always connected" and repeatedly falls back to them whenever temporary devices (like AirPods or Bluetooth headphones) disconnect.

---

## How AudioGuard Solves It
* **Allows Jump Desktop Audio when connected:** Detects when an active Jump Desktop remote session is streaming and permits Jump Audio so you can hear your Mac remotely.
* **Auto-Reverts on Disconnect:** Instantly switches macOS default audio back to your preferred device (e.g. Mac Studio Speakers, Behringer XR18, Yeti X, Monitor Speakers) the moment you disconnect.
* **Blocks False Fallback:** When AirPods or headphones disconnect, AudioGuard intercepts in <200ms and forces macOS to your physical fallback device instead of Jump Desktop Audio.
* **Menu Bar Status & Control:** Clean menu bar icon showing live output/input, quick device selection submenus, and one-click manual restore (⌘R).

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
2. Run the installer:
   ```bash
   chmod +x install.sh
   ./install.sh
   ```

---

## Menu Bar Controls

Click the speaker icon in your macOS Menu Bar:

* **🟢 Status Header:** Shows current audio state (`🟢 Guarding` / `🔵 Jump Remote Active`).
* **🎵 Preferred Fallback Output:** Submenu to select your primary fallback speaker/DAC.
* **🎙️ Preferred Fallback Input:** Submenu to select your primary microphone.
* **⚡ Switch to Preferred Audio Now (⌘R):** Immediately resets audio.
* **✓ Auto-Revert on Jump Disconnect:** Automatically switches back when remote session ends.
* **✓ Block Jump Audio as Auto-Fallback:** Prevents Jump from becoming the secondary fallback device.
* **✓ Launch at Login:** Automatically starts on macOS boot.

---

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/benny2168/audioguard/main/uninstall.sh | bash
```
Or run `./uninstall.sh` from this repository.
