import Cocoa
import CoreAudio
import UserNotifications
import ServiceManagement

// MARK: - Audio Device Model
struct AudioDevice: Identifiable, Hashable {
    let id: AudioObjectID
    let name: String
    let uid: String
    let isInput: Bool
    let isOutput: Bool
    let isVirtual: Bool
    
    static func detectIsVirtual(name: String, uid: String) -> Bool {
        let n = name.lowercased()
        let u = uid.lowercased()
        return u.contains("jump") || u.contains("teams") || u.contains("zoom") ||
               u.contains("loopback") || u.contains("blackhole") || u.contains("soundflower") ||
               u.contains("parrot") || u.contains("null") ||
               n.contains("jump desktop") || n.contains("microsoft teams") ||
               n.contains("zoom") || n.contains("virtual") || n.contains("loopback") ||
               n.contains("blackhole") || n.contains("soundflower") || n.contains("parrot")
    }
}

// MARK: - Audio Manager (CoreAudio Bridge)
class AudioManager {
    static let shared = AudioManager()
    
    var onDevicesChanged: (() -> Void)?
    var onDefaultOutputChanged: ((AudioDevice?) -> Void)?
    var onDefaultInputChanged: ((AudioDevice?) -> Void)?
    var onVolumeChanged: ((Float, Bool) -> Void)?
    
    private var currentOutputID: AudioObjectID = 0
    private var isMuted: Bool = false
    
    init() {
        setupListeners()
    }
    
    func getAllDevices() -> [AudioDevice] {
        var propertySize: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propertySize) == noErr else {
            return []
        }
        
        let count = Int(propertySize) / MemoryLayout<AudioObjectID>.size
        var ids = [AudioObjectID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propertySize, &ids) == noErr else {
            return []
        }
        
        var list: [AudioDevice] = []
        for id in ids {
            var nameAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceNameCFString,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var nameRef: Unmanaged<CFString>?
            var nameSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            var devName = "Unknown Device"
            if AudioObjectGetPropertyData(id, &nameAddr, 0, nil, &nameSize, &nameRef) == noErr, let ref = nameRef {
                devName = ref.takeRetainedValue() as String
            }
            
            var uidAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var uidRef: Unmanaged<CFString>?
            var uidSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            var devUID = "\(id)"
            if AudioObjectGetPropertyData(id, &uidAddr, 0, nil, &uidSize, &uidRef) == noErr, let ref = uidRef {
                devUID = ref.takeRetainedValue() as String
            }
            
            // Transport Type / Virtual check
            var transportAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyTransportType,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var transport: UInt32 = 0
            var transportSize = UInt32(MemoryLayout<UInt32>.size)
            var isVirtual = AudioDevice.detectIsVirtual(name: devName, uid: devUID)
            if AudioObjectGetPropertyData(id, &transportAddr, 0, nil, &transportSize, &transport) == noErr {
                if transport == kAudioDeviceTransportTypeVirtual {
                    isVirtual = true
                }
            }
            
            // Check input streams
            var inputAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            var inSize: UInt32 = 0
            let hasInput = AudioObjectGetPropertyDataSize(id, &inputAddr, 0, nil, &inSize) == noErr && inSize > 0
            
            // Check output streams
            var outputAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            var outSize: UInt32 = 0
            let hasOutput = AudioObjectGetPropertyDataSize(id, &outputAddr, 0, nil, &outSize) == noErr && outSize > 0
            
            list.append(AudioDevice(id: id, name: devName, uid: devUID, isInput: hasInput, isOutput: hasOutput, isVirtual: isVirtual))
        }
        return list
    }
    
    func getDefaultOutputDevice() -> AudioDevice? {
        var devID = AudioObjectID(0)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &devID) == noErr else {
            return nil
        }
        return getAllDevices().first { $0.id == devID }
    }
    
    func getDefaultInputDevice() -> AudioDevice? {
        var devID = AudioObjectID(0)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &devID) == noErr else {
            return nil
        }
        return getAllDevices().first { $0.id == devID }
    }
    
    func setDefaultOutputDevice(uid: String) -> Bool {
        guard let device = getAllDevices().first(where: { $0.uid == uid && $0.isOutput }) else {
            return false
        }
        return setDefaultOutputDevice(id: device.id)
    }
    
    func setDefaultOutputDevice(id: AudioObjectID) -> Bool {
        var devID = id
        let size = UInt32(MemoryLayout<AudioObjectID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        return AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, size, &devID) == noErr
    }
    
    func setDefaultInputDevice(uid: String) -> Bool {
        guard let device = getAllDevices().first(where: { $0.uid == uid && $0.isInput }) else {
            return false
        }
        return setDefaultInputDevice(id: device.id)
    }
    
    func setDefaultInputDevice(id: AudioObjectID) -> Bool {
        var devID = id
        let size = UInt32(MemoryLayout<AudioObjectID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        return AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, size, &devID) == noErr
    }
    
    func isDeviceRunning(id: AudioObjectID) -> Bool {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var isRunning: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        if AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &isRunning) == noErr {
            return isRunning != 0
        }
        return false
    }
    
    // MARK: - Volume Management
    func getVolume() -> (volume: Float, isMuted: Bool) {
        guard let output = getDefaultOutputDevice() else { return (1.0, false) }
        var vol: Float32 = 0.0
        var size = UInt32(MemoryLayout<Float32>.size)
        
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectGetPropertyData(output.id, &addr, 0, nil, &size, &vol) != noErr {
            addr.mElement = 1
            _ = AudioObjectGetPropertyData(output.id, &addr, 0, nil, &size, &vol)
        }
        
        var mute: UInt32 = 0
        var muteSize = UInt32(MemoryLayout<UInt32>.size)
        var muteAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectGetPropertyData(output.id, &muteAddr, 0, nil, &muteSize, &mute) != noErr {
            muteAddr.mElement = 1
            _ = AudioObjectGetPropertyData(output.id, &muteAddr, 0, nil, &muteSize, &mute)
        }
        
        return (max(0.0, min(1.0, vol)), mute != 0)
    }
    
    func setVolume(_ volume: Float) {
        guard let output = getDefaultOutputDevice() else { return }
        var vol = max(0.0, min(1.0, volume))
        let size = UInt32(MemoryLayout<Float32>.size)
        
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectSetPropertyData(output.id, &addr, 0, nil, size, &vol) != noErr {
            addr.mElement = 1
            _ = AudioObjectSetPropertyData(output.id, &addr, 0, nil, size, &vol)
            addr.mElement = 2
            _ = AudioObjectSetPropertyData(output.id, &addr, 0, nil, size, &vol)
        }
        
        // Unmute if volume is increased above 0
        if vol > 0 && isMuted {
            setMuted(false)
        }
    }
    
    func setMuted(_ muted: Bool) {
        guard let output = getDefaultOutputDevice() else { return }
        var muteValue: UInt32 = muted ? 1 : 0
        let size = UInt32(MemoryLayout<UInt32>.size)
        
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectSetPropertyData(output.id, &addr, 0, nil, size, &muteValue) != noErr {
            addr.mElement = 1
            _ = AudioObjectSetPropertyData(output.id, &addr, 0, nil, size, &muteValue)
        }
        isMuted = muted
    }
    
    private func setupListeners() {
        var defaultOutputAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &defaultOutputAddr, DispatchQueue.main) { [weak self] _, _ in
            let outDev = self?.getDefaultOutputDevice()
            self?.attachOutputDeviceListeners(devID: outDev?.id ?? 0)
            self?.onDefaultOutputChanged?(outDev)
        }
        
        var defaultInputAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &defaultInputAddr, DispatchQueue.main) { [weak self] _, _ in
            self?.onDefaultInputChanged?(self?.getDefaultInputDevice())
        }
        
        var devicesAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &devicesAddr, DispatchQueue.main) { [weak self] _, _ in
            self?.onDevicesChanged?()
        }
        
        if let outDev = getDefaultOutputDevice() {
            attachOutputDeviceListeners(devID: outDev.id)
        }
    }
    
    private func attachOutputDeviceListeners(devID: AudioObjectID) {
        guard devID != 0 else { return }
        currentOutputID = devID
        
        var volAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(devID, &volAddr, DispatchQueue.main) { [weak self] _, _ in
            guard let self = self else { return }
            let state = self.getVolume()
            self.onVolumeChanged?(state.volume, state.isMuted)
        }
        
        var muteAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(devID, &muteAddr, DispatchQueue.main) { [weak self] _, _ in
            guard let self = self else { return }
            let state = self.getVolume()
            self.onVolumeChanged?(state.volume, state.isMuted)
        }
    }
}

// MARK: - iOS-Style Floating Volume HUD
class VolumeHUD {
    static let shared = VolumeHUD()
    private var window: NSPanel?
    private var fillView: NSView?
    private var iconView: NSImageView?
    private var labelView: NSTextField?
    private var dismissTimer: Timer?
    
    init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 230, height: 46),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        
        let visualEffect = NSVisualEffectView(frame: panel.contentView!.bounds)
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 23
        visualEffect.layer?.masksToBounds = true
        visualEffect.layer?.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor
        visualEffect.layer?.borderWidth = 1.0
        
        // Icon
        let icon = NSImageView(frame: NSRect(x: 14, y: 13, width: 20, height: 20))
        icon.image = NSImage(systemSymbolName: "speaker.wave.3.fill", accessibilityDescription: nil)
        icon.contentTintColor = .white
        visualEffect.addSubview(icon)
        self.iconView = icon
        
        // Progress track
        let track = NSView(frame: NSRect(x: 42, y: 18, width: 125, height: 10))
        track.wantsLayer = true
        track.layer?.cornerRadius = 5
        track.layer?.masksToBounds = true
        track.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.25).cgColor
        
        let fill = NSView(frame: NSRect(x: 0, y: 0, width: 60, height: 10))
        fill.wantsLayer = true
        fill.layer?.cornerRadius = 5
        fill.layer?.backgroundColor = NSColor.white.cgColor
        track.addSubview(fill)
        self.fillView = fill
        visualEffect.addSubview(track)
        
        // Label
        let label = NSTextField(labelWithString: "50%")
        label.frame = NSRect(x: 173, y: 13, width: 48, height: 20)
        label.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        label.textColor = .white
        visualEffect.addSubview(label)
        self.labelView = label
        
        panel.contentView = visualEffect
        self.window = panel
    }
    
    func show(volume: Float, isMuted: Bool) {
        guard AudioGuardEngine.shared.showVolumeHUD else { return }
        guard let panel = window, let screen = NSScreen.main else { return }
        
        let screenRect = screen.visibleFrame
        let panelX = screenRect.midX - 115
        let panelY = screenRect.maxY - 65
        panel.setFrameOrigin(NSPoint(x: panelX, y: panelY))
        
        let percent = Int(round(volume * 100))
        labelView?.stringValue = isMuted ? "Muted" : "\(percent)%"
        
        let trackWidth: CGFloat = 125
        let fillWidth = isMuted ? 0 : CGFloat(max(0.0, min(1.0, volume))) * trackWidth
        fillView?.frame = NSRect(x: 0, y: 0, width: fillWidth, height: 10)
        
        let symbolName: String
        if isMuted || volume == 0 {
            symbolName = "speaker.slash.fill"
        } else if volume < 0.33 {
            symbolName = "speaker.wave.1.fill"
        } else if volume < 0.66 {
            symbolName = "speaker.wave.2.fill"
        } else {
            symbolName = "speaker.wave.3.fill"
        }
        iconView?.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        
        panel.alphaValue = 1.0
        panel.orderFrontRegardless()
        
        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.25
                panel.animator().alphaValue = 0.0
            }, completionHandler: {
                panel.orderOut(nil)
            })
        }
    }
}

// MARK: - Controller & State Engine
class AudioGuardEngine {
    static let shared = AudioGuardEngine()
    private let defaults = UserDefaults.standard
    private var checkTimer: Timer?
    
    var lastNonVirtualOutputUID: String? {
        get { defaults.string(forKey: "lastNonVirtualOutputUID") }
        set { defaults.set(newValue, forKey: "lastNonVirtualOutputUID") }
    }
    
    var preferredOutputUID: String? {
        get { defaults.string(forKey: "preferredOutputUID") }
        set { defaults.set(newValue, forKey: "preferredOutputUID") }
    }
    
    var preferredInputUID: String? {
        get { defaults.string(forKey: "preferredInputUID") }
        set { defaults.set(newValue, forKey: "preferredInputUID") }
    }
    
    var autoRevertOnDisconnect: Bool {
        get { defaults.object(forKey: "autoRevertOnDisconnect") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "autoRevertOnDisconnect") }
    }
    
    var blockVirtualAsFallback: Bool {
        get { defaults.object(forKey: "blockVirtualAsFallback") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "blockVirtualAsFallback") }
    }
    
    var showVolumeHUD: Bool {
        get { defaults.object(forKey: "showVolumeHUD") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "showVolumeHUD") }
    }
    
    var showNotifications: Bool {
        get { defaults.object(forKey: "showNotifications") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "showNotifications") }
    }
    
    // Configurable set of guarded virtual device UIDs
    var guardedDeviceUIDs: Set<String> {
        get {
            if let array = defaults.stringArray(forKey: "guardedDeviceUIDs") {
                return Set(array)
            }
            return []
        }
        set {
            defaults.set(Array(newValue), forKey: "guardedDeviceUIDs")
        }
    }
    
    // Configurable set of hidden output device UIDs
    var hiddenOutputUIDs: Set<String> {
        get {
            if let array = defaults.stringArray(forKey: "hiddenOutputUIDs") {
                return Set(array)
            }
            return []
        }
        set {
            defaults.set(Array(newValue), forKey: "hiddenOutputUIDs")
        }
    }
    
    // Configurable set of hidden input device UIDs
    var hiddenInputUIDs: Set<String> {
        get {
            if let array = defaults.stringArray(forKey: "hiddenInputUIDs") {
                return Set(array)
            }
            return []
        }
        set {
            defaults.set(Array(newValue), forKey: "hiddenInputUIDs")
        }
    }
    
    func isHiddenOutput(uid: String) -> Bool {
        return hiddenOutputUIDs.contains(uid)
    }
    
    func toggleHiddenOutput(uid: String) {
        var current = hiddenOutputUIDs
        if current.contains(uid) {
            current.remove(uid)
        } else {
            current.insert(uid)
        }
        hiddenOutputUIDs = current
    }
    
    func isHiddenInput(uid: String) -> Bool {
        return hiddenInputUIDs.contains(uid)
    }
    
    func toggleHiddenInput(uid: String) {
        var current = hiddenInputUIDs
        if current.contains(uid) {
            current.remove(uid)
        } else {
            current.insert(uid)
        }
        hiddenInputUIDs = current
    }
    
    private(set) var activeGuardedDeviceName: String? = nil
    private var previouslyRunningGuardedUIDs: Set<String> = []
    
    func start() {
        // One-time migration for v1.3.1: remove audio utility / interface drivers (Dante DVS, Loopback, BlackHole) from guarded set if they were auto-added
        if !defaults.bool(forKey: "hasCleanedUpGuardedDefaultsV131") {
            var current = guardedDeviceUIDs
            current = current.filter { uid in
                let u = uid.lowercased()
                return u.contains("jump") // Only keep true remote desktop drivers (e.g. Jump Desktop)
            }
            guardedDeviceUIDs = current
            defaults.set(true, forKey: "hasCleanedUpGuardedDefaultsV131")
        }
        
        // Initialize guarded devices list with remote streaming drivers (e.g. Jump Desktop) by default if first run
        if defaults.object(forKey: "guardedDeviceUIDs") == nil {
            let remoteVirtuals = AudioManager.shared.getAllDevices().filter { 
                let u = $0.uid.lowercased()
                let n = $0.name.lowercased()
                return u.contains("jump") || n.contains("jump")
            }
            guardedDeviceUIDs = Set(remoteVirtuals.map { $0.uid })
        }
        
        // Register default preferred if not set
        if preferredOutputUID == nil {
            if let current = AudioManager.shared.getDefaultOutputDevice(), !isGuarded(uid: current.uid) {
                preferredOutputUID = current.uid
                lastNonVirtualOutputUID = current.uid
            } else if let speaker = AudioManager.shared.getAllDevices().first(where: { $0.uid == "BuiltInSpeakerDevice" }) {
                preferredOutputUID = speaker.uid
                lastNonVirtualOutputUID = speaker.uid
            }
        }
        
        AudioManager.shared.onDefaultOutputChanged = { [weak self] current in
            self?.handleDefaultOutputChange(current: current)
        }
        
        AudioManager.shared.onVolumeChanged = { volume, isMuted in
            VolumeHUD.shared.show(volume: volume, isMuted: isMuted)
        }
        
        // Polling timer to watch running state of guarded virtual devices
        checkTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.pollGuardedDevices()
        }
    }
    
    func isGuarded(uid: String) -> Bool {
        return guardedDeviceUIDs.contains(uid)
    }
    
    func toggleGuarded(uid: String) {
        var current = guardedDeviceUIDs
        if current.contains(uid) {
            current.remove(uid)
        } else {
            current.insert(uid)
        }
        guardedDeviceUIDs = current
    }
    
    private func pollGuardedDevices() {
        let allDevices = AudioManager.shared.getAllDevices()
        let guardedDevices = allDevices.filter { isGuarded(uid: $0.uid) }
        
        var currentlyRunning = Set<String>()
        var activeName: String? = nil
        
        for dev in guardedDevices {
            if AudioManager.shared.isDeviceRunning(id: dev.id) {
                currentlyRunning.insert(dev.uid)
                if activeName == nil {
                    activeName = dev.name
                }
            }
        }
        
        let previousRunning = previouslyRunningGuardedUIDs
        previouslyRunningGuardedUIDs = currentlyRunning
        activeGuardedDeviceName = activeName
        
        let currentDefault = AudioManager.shared.getDefaultOutputDevice()
        let currentDefaultIsGuarded = currentDefault != nil && isGuarded(uid: currentDefault!.uid)
        
        // Case 1: A guarded virtual app just stopped running its stream
        let stoppedUIDs = previousRunning.subtracting(currentlyRunning)
        if !stoppedUIDs.isEmpty && currentDefaultIsGuarded {
            if let currentUID = currentDefault?.uid, stoppedUIDs.contains(currentUID) {
                if autoRevertOnDisconnect {
                    revertToPreferred(reason: "\(currentDefault?.name ?? "Remote app") session ended")
                }
            }
        }
        
        // Case 2: Default output is a guarded virtual driver that is NOT actively running
        if currentDefaultIsGuarded && blockVirtualAsFallback {
            if let cur = currentDefault, !currentlyRunning.contains(cur.uid) {
                revertToPreferred(reason: "Guarded driver \(cur.name) was idle")
            }
        }
    }
    
    private func handleDefaultOutputChange(current: AudioDevice?) {
        guard let current = current else { return }
        
        if !isGuarded(uid: current.uid) {
            lastNonVirtualOutputUID = current.uid
        } else {
            let isRunning = AudioManager.shared.isDeviceRunning(id: current.id)
            if !isRunning && blockVirtualAsFallback {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                    self?.revertToPreferred(reason: "Prevented \(current.name) auto-fallback")
                }
            }
        }
    }
    
    func revertToPreferred(reason: String) {
        let targetUID = preferredOutputUID ?? lastNonVirtualOutputUID
        guard let uid = targetUID else { return }
        
        if AudioManager.shared.setDefaultOutputDevice(uid: uid) {
            let targetDevice = AudioManager.shared.getAllDevices().first { $0.uid == uid }
            let name = targetDevice?.name ?? "Preferred Speakers"
            
            if showNotifications {
                sendNotification(title: "Audio Restored", body: "Switched back to \(name) (\(reason))")
            }
        }
    }
    
    private func sendNotification(title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .none
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        center.add(request)
    }
}

// MARK: - Auto-Update Manager
class UpdateManager {
    static let shared = UpdateManager()
    
    private var checkTimer: Timer?
    
    var onUpdateStatusChanged: (() -> Void)?
    
    private(set) var availableUpdateVersion: String? = nil
    private(set) var isChecking: Bool = false
    private(set) var isUpdating: Bool = false
    private(set) var lastCheckTime: Date? = nil
    
    var currentVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.3.1"
    }
    
    func startPeriodicChecks() {
        // Initial check 4 seconds after startup
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self] in
            self?.checkForUpdates(silent: true)
        }
        
        // Periodic check every 15 minutes
        checkTimer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
            self?.checkForUpdates(silent: true)
        }
    }
    
    func checkForUpdates(silent: Bool = false, completion: ((Bool, String?) -> Void)? = nil) {
        guard !isChecking && !isUpdating else { return }
        isChecking = true
        onUpdateStatusChanged?()
        
        fetchRemoteVersion { [weak self] remoteVer in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isChecking = false
                self.lastCheckTime = Date()
                
                guard let remoteVersion = remoteVer else {
                    self.onUpdateStatusChanged?()
                    if !silent {
                        self.showErrorAlert(message: "Could not connect to GitHub to check for updates.")
                    }
                    completion?(false, nil)
                    return
                }
                
                let hasUpdate = self.isVersion(remoteVersion, newerThan: self.currentVersion)
                self.availableUpdateVersion = hasUpdate ? remoteVersion : nil
                self.onUpdateStatusChanged?()
                
                if hasUpdate {
                    if silent {
                        self.sendNotification(
                            title: "AudioGuard Update Available",
                            body: "Version \(remoteVersion) is ready. Click the AudioGuard menu bar icon to install."
                        )
                    } else {
                        self.showUpdateAvailableAlert(newVersion: remoteVersion)
                    }
                } else {
                    if !silent {
                        self.showUpToDateAlert()
                    }
                }
                
                completion?(hasUpdate, remoteVersion)
            }
        }
    }
    
    private func fetchRemoteVersion(completion: @escaping (String?) -> Void) {
        // Method 1: Real-time GitHub Contents API (bypasses CDN cache)
        let apiURL = URL(string: "https://api.github.com/repos/benny2168/audioguard/contents/src/Info.plist")!
        var request = URLRequest(url: apiURL)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("AudioGuard-Updater", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 8.0
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data, error == nil,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let base64 = json["content"] as? String {
                let cleanBase64 = base64.replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: "\r", with: "")
                if let plistData = Data(base64Encoded: cleanBase64),
                   let plist = (try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil)) as? [String: Any],
                   let ver = plist["CFBundleShortVersionString"] as? String {
                    completion(ver.trimmingCharacters(in: .whitespacesAndNewlines))
                    return
                }
            }
            
            // Method 2: Fallback to Raw GitHub URL
            let ts = Int(Date().timeIntervalSince1970)
            guard let rawURL = URL(string: "https://raw.githubusercontent.com/benny2168/audioguard/main/src/Info.plist?ts=\(ts)") else {
                completion(nil)
                return
            }
            var rawRequest = URLRequest(url: rawURL)
            rawRequest.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            rawRequest.timeoutInterval = 8.0
            
            let rawTask = URLSession.shared.dataTask(with: rawRequest) { rawData, _, _ in
                if let rawData = rawData,
                   let plist = (try? PropertyListSerialization.propertyList(from: rawData, options: [], format: nil)) as? [String: Any],
                   let ver = plist["CFBundleShortVersionString"] as? String {
                    completion(ver.trimmingCharacters(in: .whitespacesAndNewlines))
                } else {
                    completion(nil)
                }
            }
            rawTask.resume()
        }
        task.resume()
    }
    
    private func isVersion(_ remote: String, newerThan current: String) -> Bool {
        let rParts = remote.split(separator: ".").compactMap { Int($0) }
        let cParts = current.split(separator: ".").compactMap { Int($0) }
        
        let maxLen = max(rParts.count, cParts.count)
        for i in 0..<maxLen {
            let r = i < rParts.count ? rParts[i] : 0
            let c = i < cParts.count ? cParts[i] : 0
            if r > c { return true }
            if r < c { return false }
        }
        return false
    }
    
    func performUpdate() {
        guard !isUpdating else { return }
        isUpdating = true
        onUpdateStatusChanged?()
        
        let versionText = availableUpdateVersion ?? "latest"
        sendNotification(title: "Updating AudioGuard", body: "Installing v\(versionText)... AudioGuard will relaunch automatically.")
        
        // Spawn detached installer script via Process
        let script = "curl -fsSL https://raw.githubusercontent.com/benny2168/audioguard/main/install.sh | bash"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", script]
        
        do {
            try process.run()
        } catch {
            print("Failed to launch updater: \(error)")
            isUpdating = false
            onUpdateStatusChanged?()
            showErrorAlert(message: "Could not run installer: \(error.localizedDescription)")
        }
    }
    
    private func showUpdateAvailableAlert(newVersion: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "AudioGuard Update Available"
        alert.informativeText = "A new version of AudioGuard (v\(newVersion)) is available!\n\nWould you like to install and relaunch now?"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Install & Relaunch")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn {
            self.performUpdate()
        }
    }
    
    private func showUpToDateAlert() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "AudioGuard is Up to Date"
        alert.informativeText = "You are running the latest version (v\(currentVersion))."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func showErrorAlert(message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Update Check Failed"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func sendNotification(title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        center.add(request)
    }
}

// MARK: - Menu Bar App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    let menu = NSMenu()
    private var volumeSlider: NSSlider?
    private var volumeLabel: NSTextField?
    private var muteButton: NSButton?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        
        setupStatusItem()
        AudioGuardEngine.shared.start()
        UpdateManager.shared.startPeriodicChecks()
        
        UpdateManager.shared.onUpdateStatusChanged = { [weak self] in
            self?.updateMenu()
        }
        
        AudioManager.shared.onDevicesChanged = { [weak self] in
            self?.updateMenu()
        }
        AudioManager.shared.onDefaultOutputChanged = { [weak self] _ in
            self?.updateMenu()
            self?.updateStatusIcon()
        }
        AudioManager.shared.onDefaultInputChanged = { [weak self] _ in
            self?.updateMenu()
        }
        AudioManager.shared.onVolumeChanged = { [weak self] vol, muted in
            self?.updateVolumeControls(vol: vol, muted: muted)
            self?.updateStatusIcon()
        }
        
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateStatusIcon()
        }
        
        updateMenu()
        updateStatusIcon()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.menu = menu
        updateStatusIcon()
    }
    
    func updateStatusIcon() {
        guard let button = statusItem.button else { return }
        let (volume, isMuted) = AudioManager.shared.getVolume()
        
        button.title = "" // Keep title completely clear of text (no " Remote" text in menu bar)
        
        let symbolName: String
        if isMuted || volume == 0 {
            symbolName = "speaker.slash.fill"
        } else if volume < 0.33 {
            symbolName = "speaker.wave.1.fill"
        } else if volume < 0.66 {
            symbolName = "speaker.wave.2.fill"
        } else {
            symbolName = "speaker.wave.3.fill"
        }
        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "AudioGuard Sound Control")
    }
    
    @objc func updateMenu() {
        menu.removeAllItems()
        
        let currentOut = AudioManager.shared.getDefaultOutputDevice()
        let currentIn = AudioManager.shared.getDefaultInputDevice()
        let (volume, isMuted) = AudioManager.shared.getVolume()
        let activeGuarded = AudioGuardEngine.shared.activeGuardedDeviceName
        
        // -------------------------------------------------------------
        // 0. DYNAMIC UPDATE BANNER (If New Version Available on GitHub)
        // -------------------------------------------------------------
        if let newVersion = UpdateManager.shared.availableUpdateVersion {
            let updateTitle = UpdateManager.shared.isUpdating
                ? "⏳ Installing AudioGuard v\(newVersion)..."
                : "🚀 Update Available: v\(newVersion) (Click to Install)"
            let updateItem = NSMenuItem(title: updateTitle, action: #selector(installUpdate), keyEquivalent: "")
            updateItem.target = self
            updateItem.isEnabled = !UpdateManager.shared.isUpdating
            menu.addItem(updateItem)
            menu.addItem(NSMenuItem.separator())
        }
        
        // -------------------------------------------------------------
        // 1. TOP ACTION: Switch to Preferred Audio Now (Command+R)
        // -------------------------------------------------------------
        let targetUID = AudioGuardEngine.shared.preferredOutputUID
        let targetDev = AudioManager.shared.getAllDevices().first { $0.uid == targetUID }
        let targetName = targetDev?.name ?? "Preferred Device"
        let restoreItem = NSMenuItem(title: "⚡ Switch to Preferred Audio (\(targetName))", action: #selector(restoreNow), keyEquivalent: "r")
        restoreItem.target = self
        menu.addItem(restoreItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // -------------------------------------------------------------
        // 2. VOLUME CONTROL SLIDER (Interactive Menu Item)
        // -------------------------------------------------------------
        let volumeView = createVolumeControlView(volume: volume, isMuted: isMuted)
        let volumeItem = NSMenuItem()
        volumeItem.view = volumeView
        menu.addItem(volumeItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // -------------------------------------------------------------
        // 3. STATUS INDICATOR
        // -------------------------------------------------------------
        let statusTitle: String
        if let guarded = activeGuarded {
            if guarded.lowercased().contains("jump") {
                statusTitle = "🔵 Remote Desktop Session: \(guarded)"
            } else {
                statusTitle = "🔵 Active Guarded Session: \(guarded)"
            }
        } else if let cur = currentOut, AudioGuardEngine.shared.isGuarded(uid: cur.uid) {
            statusTitle = "🟡 Guarded Driver Active: \(cur.name)"
        } else {
            statusTitle = "🟢 AudioGuard: Active & Guarding"
        }
        let statusItem = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // -------------------------------------------------------------
        // 4. OUTPUT DEVICES (Direct List for One-Click Switch)
        // -------------------------------------------------------------
        let outHeader = NSMenuItem(title: "OUTPUT DEVICES", action: nil, keyEquivalent: "")
        outHeader.isEnabled = false
        menu.addItem(outHeader)
        
        let allDevices = AudioManager.shared.getAllDevices()
        let outDevices = allDevices.filter { $0.isOutput }
        let visibleOutDevices = outDevices.filter { !AudioGuardEngine.shared.isHiddenOutput(uid: $0.uid) }
        
        for dev in visibleOutDevices {
            let isCurrent = dev.id == currentOut?.id
            let iconPrefix = dev.isVirtual ? "📡 " : "🔊 "
            let item = NSMenuItem(title: "\(iconPrefix)\(dev.name)", action: #selector(selectOutputDevice(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = dev.uid
            item.state = isCurrent ? .on : .off
            menu.addItem(item)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // -------------------------------------------------------------
        // 5. INPUT DEVICES (Direct List for One-Click Switch)
        // -------------------------------------------------------------
        let inHeader = NSMenuItem(title: "INPUT DEVICES", action: nil, keyEquivalent: "")
        inHeader.isEnabled = false
        menu.addItem(inHeader)
        
        let inDevices = allDevices.filter { $0.isInput }
        let visibleInDevices = inDevices.filter { !AudioGuardEngine.shared.isHiddenInput(uid: $0.uid) }
        
        for dev in visibleInDevices {
            let isCurrent = dev.id == currentIn?.id
            let iconPrefix = dev.isVirtual ? "📡 " : "🎙️ "
            let item = NSMenuItem(title: "\(iconPrefix)\(dev.name)", action: #selector(selectInputDevice(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = dev.uid
            item.state = isCurrent ? .on : .off
            menu.addItem(item)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // -------------------------------------------------------------
        // 6. PREFERRED FALLBACK SUBMENUS
        // -------------------------------------------------------------
        let prefOutMenu = NSMenu()
        let fallbackOutDevices = outDevices.filter { !AudioGuardEngine.shared.isHiddenOutput(uid: $0.uid) }
        let currentPrefOut = AudioGuardEngine.shared.preferredOutputUID
        for dev in fallbackOutDevices {
            let iconPrefix = dev.isVirtual ? "📡 " : "🔊 "
            let item = NSMenuItem(title: "\(iconPrefix)\(dev.name)", action: #selector(setPreferredOutput(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = dev.uid
            if dev.uid == currentPrefOut { item.state = .on }
            prefOutMenu.addItem(item)
        }
        let prefOutMenuItem = NSMenuItem(title: "🎵 Preferred Fallback Output", action: nil, keyEquivalent: "")
        prefOutMenuItem.submenu = prefOutMenu
        menu.addItem(prefOutMenuItem)
        
        let prefInMenu = NSMenu()
        let fallbackInDevices = inDevices.filter { !AudioGuardEngine.shared.isHiddenInput(uid: $0.uid) }
        let currentPrefIn = AudioGuardEngine.shared.preferredInputUID
        for dev in fallbackInDevices {
            let iconPrefix = dev.isVirtual ? "📡 " : "🎙️ "
            let item = NSMenuItem(title: "\(iconPrefix)\(dev.name)", action: #selector(setPreferredInput(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = dev.uid
            if dev.uid == currentPrefIn { item.state = .on }
            prefInMenu.addItem(item)
        }
        let prefInMenuItem = NSMenuItem(title: "🎙️ Preferred Fallback Input", action: nil, keyEquivalent: "")
        prefInMenuItem.submenu = prefInMenu
        menu.addItem(prefInMenuItem)
        
        // -------------------------------------------------------------
        // 7. GUARDED VIRTUAL DRIVERS & HIDDEN DEVICE FILTERING
        // -------------------------------------------------------------
        let virtualMenu = NSMenu()
        let virtualDevices = allDevices.filter { $0.isVirtual }
        for dev in virtualDevices {
            let isGuarded = AudioGuardEngine.shared.isGuarded(uid: dev.uid)
            let typeDesc = dev.isOutput && dev.isInput ? "(In/Out)" : (dev.isOutput ? "(Out)" : "(In)")
            let item = NSMenuItem(title: "\(dev.name) \(typeDesc)", action: #selector(toggleGuardedDevice(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = dev.uid
            item.state = isGuarded ? .on : .off
            virtualMenu.addItem(item)
        }
        let virtualMenuItem = NSMenuItem(title: "🛡️ Guarded Virtual Drivers", action: nil, keyEquivalent: "")
        virtualMenuItem.submenu = virtualMenu
        menu.addItem(virtualMenuItem)
        
        // Cascaded Submenu: Hidden Outputs
        let hiddenOutMenu = NSMenu()
        for dev in outDevices {
            let isHidden = AudioGuardEngine.shared.isHiddenOutput(uid: dev.uid)
            let iconPrefix = dev.isVirtual ? "📡 " : "🔊 "
            let item = NSMenuItem(title: "\(iconPrefix)\(dev.name)", action: #selector(toggleHiddenOutputDevice(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = dev.uid
            item.state = isHidden ? .on : .off
            hiddenOutMenu.addItem(item)
        }
        let hiddenOutMenuItem = NSMenuItem(title: "👁️‍🗨️ Hidden Outputs", action: nil, keyEquivalent: "")
        hiddenOutMenuItem.submenu = hiddenOutMenu
        menu.addItem(hiddenOutMenuItem)
        
        // Cascaded Submenu: Hidden Inputs
        let hiddenInMenu = NSMenu()
        for dev in inDevices {
            let isHidden = AudioGuardEngine.shared.isHiddenInput(uid: dev.uid)
            let iconPrefix = dev.isVirtual ? "📡 " : "🎙️ "
            let item = NSMenuItem(title: "\(iconPrefix)\(dev.name)", action: #selector(toggleHiddenInputDevice(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = dev.uid
            item.state = isHidden ? .on : .off
            hiddenInMenu.addItem(item)
        }
        let hiddenInMenuItem = NSMenuItem(title: "👁️‍🗨️ Hidden Inputs", action: nil, keyEquivalent: "")
        hiddenInMenuItem.submenu = hiddenInMenu
        menu.addItem(hiddenInMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // -------------------------------------------------------------
        // 8. AUTOMATION & BEHAVIOR SETTINGS
        // -------------------------------------------------------------
        let revertToggle = NSMenuItem(title: "Auto-Revert on App Disconnect", action: #selector(toggleAutoRevert), keyEquivalent: "")
        revertToggle.target = self
        revertToggle.state = AudioGuardEngine.shared.autoRevertOnDisconnect ? .on : .off
        menu.addItem(revertToggle)
        
        let blockToggle = NSMenuItem(title: "Block Guarded Drivers as Auto-Fallback", action: #selector(toggleBlockFallback), keyEquivalent: "")
        blockToggle.target = self
        blockToggle.state = AudioGuardEngine.shared.blockVirtualAsFallback ? .on : .off
        menu.addItem(blockToggle)
        
        let hudToggle = NSMenuItem(title: "Show iOS-Style Floating Volume HUD", action: #selector(toggleVolumeHUD), keyEquivalent: "")
        hudToggle.target = self
        hudToggle.state = AudioGuardEngine.shared.showVolumeHUD ? .on : .off
        menu.addItem(hudToggle)
        
        let notifToggle = NSMenuItem(title: "Show Notifications on Revert", action: #selector(toggleNotifications), keyEquivalent: "")
        notifToggle.target = self
        notifToggle.state = AudioGuardEngine.shared.showNotifications ? .on : .off
        menu.addItem(notifToggle)
        
        let launchToggle = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchToggle.target = self
        launchToggle.state = isLaunchAtLoginEnabled() ? .on : .off
        menu.addItem(launchToggle)
        
        menu.addItem(NSMenuItem.separator())
        
        // -------------------------------------------------------------
        // 9. UPDATES & VERSION INFO
        // -------------------------------------------------------------
        let currentVer = UpdateManager.shared.currentVersion
        let checkTitle = UpdateManager.shared.isChecking ? "Checking for Updates..." : "Check for Updates..."
        let checkUpdateItem = NSMenuItem(title: checkTitle, action: #selector(manualCheckForUpdates), keyEquivalent: "")
        checkUpdateItem.target = self
        checkUpdateItem.isEnabled = !UpdateManager.shared.isChecking && !UpdateManager.shared.isUpdating
        menu.addItem(checkUpdateItem)
        
        let versionItem = NSMenuItem(title: "AudioGuard v\(currentVer)", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // -------------------------------------------------------------
        // 10. QUIT
        // -------------------------------------------------------------
        let quitItem = NSMenuItem(title: "Quit AudioGuard", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }
    
    private func createVolumeControlView(volume: Float, isMuted: Bool) -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 38))
        
        // Mute Button / Icon
        let muteBtn = NSButton(frame: NSRect(x: 12, y: 8, width: 24, height: 24))
        muteBtn.bezelStyle = .inline
        muteBtn.isBordered = false
        muteBtn.target = self
        muteBtn.action = #selector(toggleMute)
        let iconName = isMuted ? "speaker.slash.fill" : (volume < 0.5 ? "speaker.wave.1.fill" : "speaker.wave.3.fill")
        muteBtn.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Mute")
        container.addSubview(muteBtn)
        self.muteButton = muteBtn
        
        // Slider
        let slider = NSSlider(value: Double(volume), minValue: 0.0, maxValue: 1.0, target: self, action: #selector(sliderChanged(_:)))
        slider.frame = NSRect(x: 42, y: 8, width: 175, height: 22)
        slider.isContinuous = true
        container.addSubview(slider)
        self.volumeSlider = slider
        
        // Percentage Label
        let percent = Int(round(volume * 100))
        let label = NSTextField(labelWithString: isMuted ? "Muted" : "\(percent)%")
        label.frame = NSRect(x: 222, y: 10, width: 50, height: 18)
        label.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabelColor
        container.addSubview(label)
        self.volumeLabel = label
        
        return container
    }
    
    @objc func sliderChanged(_ sender: NSSlider) {
        let val = Float(sender.doubleValue)
        AudioManager.shared.setVolume(val)
        let percent = Int(round(val * 100))
        volumeLabel?.stringValue = "\(percent)%"
        updateStatusIcon()
    }
    
    @objc func toggleMute() {
        let (_, isMuted) = AudioManager.shared.getVolume()
        AudioManager.shared.setMuted(!isMuted)
        updateMenu()
        updateStatusIcon()
    }
    
    func updateVolumeControls(vol: Float, muted: Bool) {
        volumeSlider?.doubleValue = Double(vol)
        volumeLabel?.stringValue = muted ? "Muted" : "\(Int(round(vol * 100)))%"
        let iconName = muted ? "speaker.slash.fill" : (vol < 0.5 ? "speaker.wave.1.fill" : "speaker.wave.3.fill")
        muteButton?.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
    }
    
    // MARK: - Actions
    @objc func selectOutputDevice(_ sender: NSMenuItem) {
        if let uid = sender.representedObject as? String {
            _ = AudioManager.shared.setDefaultOutputDevice(uid: uid)
            updateMenu()
            updateStatusIcon()
        }
    }
    
    @objc func selectInputDevice(_ sender: NSMenuItem) {
        if let uid = sender.representedObject as? String {
            _ = AudioManager.shared.setDefaultInputDevice(uid: uid)
            updateMenu()
        }
    }
    
    @objc func setPreferredOutput(_ sender: NSMenuItem) {
        if let uid = sender.representedObject as? String {
            AudioGuardEngine.shared.preferredOutputUID = uid
            // If the user chooses this as preferred, unguard it automatically
            if AudioGuardEngine.shared.isGuarded(uid: uid) {
                AudioGuardEngine.shared.toggleGuarded(uid: uid)
            }
            updateMenu()
        }
    }
    
    @objc func setPreferredInput(_ sender: NSMenuItem) {
        if let uid = sender.representedObject as? String {
            AudioGuardEngine.shared.preferredInputUID = uid
            updateMenu()
        }
    }
    
    @objc func toggleGuardedDevice(_ sender: NSMenuItem) {
        if let uid = sender.representedObject as? String {
            AudioGuardEngine.shared.toggleGuarded(uid: uid)
            updateMenu()
        }
    }
    
    @objc func toggleHiddenOutputDevice(_ sender: NSMenuItem) {
        if let uid = sender.representedObject as? String {
            AudioGuardEngine.shared.toggleHiddenOutput(uid: uid)
            updateMenu()
        }
    }
    
    @objc func toggleHiddenInputDevice(_ sender: NSMenuItem) {
        if let uid = sender.representedObject as? String {
            AudioGuardEngine.shared.toggleHiddenInput(uid: uid)
            updateMenu()
        }
    }
    
    @objc func restoreNow() {
        AudioGuardEngine.shared.revertToPreferred(reason: "Manual switch triggered")
        if let inputUID = AudioGuardEngine.shared.preferredInputUID {
            _ = AudioManager.shared.setDefaultInputDevice(uid: inputUID)
        }
        updateMenu()
        updateStatusIcon()
    }
    
    @objc func installUpdate() {
        UpdateManager.shared.performUpdate()
        updateMenu()
    }
    
    @objc func manualCheckForUpdates() {
        UpdateManager.shared.checkForUpdates(silent: false)
        updateMenu()
    }
    
    @objc func toggleAutoRevert() {
        AudioGuardEngine.shared.autoRevertOnDisconnect.toggle()
        updateMenu()
    }
    
    @objc func toggleBlockFallback() {
        AudioGuardEngine.shared.blockVirtualAsFallback.toggle()
        updateMenu()
    }
    
    @objc func toggleVolumeHUD() {
        AudioGuardEngine.shared.showVolumeHUD.toggle()
        updateMenu()
    }
    
    @objc func toggleNotifications() {
        AudioGuardEngine.shared.showNotifications.toggle()
        updateMenu()
    }
    
    @objc func toggleLaunchAtLogin() {
        let newState = !isLaunchAtLoginEnabled()
        setLaunchAtLogin(enabled: newState)
        updateMenu()
    }
    
    private func isLaunchAtLoginEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }
    
    private func setLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to toggle login item: \(error)")
            }
        }
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - Main Entry Point
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
