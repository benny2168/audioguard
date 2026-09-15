# Current State

## Active Status
- Version: 1.0.0
- Repository: `benny2168/audioguard`
- Deployed on: Mac Studio (Apple M2 Max, macOS 26.3)
- Application Path: `/Applications/AudioGuard.app`

## What is Working
- Native Menu Bar UI with real-time status indication and device switching.
- CoreAudio property listeners for default output/input and device topology changes.
- Jump Desktop virtual audio driver (`Jump Desktop Audio`) stream detection via `kAudioDevicePropertyDeviceIsRunningSomewhere`.
- Automatic reversion to preferred physical device when remote sessions terminate.
- Block Jump Audio from becoming the default secondary fallback when AirPods/headphones disconnect.
- Launch at login support via `ServiceManagement` (`SMAppService.mainApp`).
- One-line `curl` installer script `install.sh`.
