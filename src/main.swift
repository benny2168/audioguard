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
    
    var isJumpAudio: Bool {
        return uid.contains("com.p5sys.jump.audio") || name.lowercased().contains("jump desktop")
    }
}

// MARK: - Audio Manager (CoreAudio Bridge)
class AudioManager {
    static let shared = AudioManager()
    
    var onDevicesChanged: (() -> Void)?
    var onDefaultOutputChanged: ((AudioDevice?) -> Void)?
    var onDefaultInputChanged: ((AudioDevice?) -> Void)?
    
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
            
            list.append(AudioDevice(id: id, name: devName, uid: devUID, isInput: hasInput, isOutput: hasOutput))
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
    
    private func setupListeners() {
        var defaultOutputAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &defaultOutputAddr, DispatchQueue.main) { [weak self] _, _ in
            self?.onDefaultOutputChanged?(self?.getDefaultOutputDevice())
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
    }
}

// MARK: - Controller & State Engine
class AudioGuardEngine {
    static let shared = AudioGuardEngine()
    
    private let defaults = UserDefaults.standard
    private var checkTimer: Timer?
    
    var lastNonJumpOutputUID: String? {
        get { defaults.string(forKey: "lastNonJumpOutputUID") }
        set { defaults.set(newValue, forKey: "lastNonJumpOutputUID") }
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
    
    var blockJumpAsFallback: Bool {
        get { defaults.object(forKey: "blockJumpAsFallback") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "blockJumpAsFallback") }
    }
    
    var showNotifications: Bool {
        get { defaults.object(forKey: "showNotifications") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "showNotifications") }
    }
    
    private(set) var isJumpSessionActive: Bool = false
    
    func start() {
        // Register default preferred if not set
        if preferredOutputUID == nil {
            if let current = AudioManager.shared.getDefaultOutputDevice(), !current.isJumpAudio {
                preferredOutputUID = current.uid
                lastNonJumpOutputUID = current.uid
            } else if let speaker = AudioManager.shared.getAllDevices().first(where: { $0.uid == "BuiltInSpeakerDevice" }) {
                preferredOutputUID = speaker.uid
                lastNonJumpOutputUID = speaker.uid
            }
        }
        
        AudioManager.shared.onDefaultOutputChanged = { [weak self] current in
            self?.handleDefaultOutputChange(current: current)
        }
        
        // Start polling timer to watch Jump Desktop active audio streaming state
        checkTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.pollJumpState()
        }
    }
    
    private func pollJumpState() {
        let allDevices = AudioManager.shared.getAllDevices()
        guard let jumpDevice = allDevices.first(where: { $0.isJumpAudio && $0.isOutput }) else {
            return
        }
        
        let isRunning = AudioManager.shared.isDeviceRunning(id: jumpDevice.id)
        let previousState = isJumpSessionActive
        isJumpSessionActive = isRunning
        
        let currentDefault = AudioManager.shared.getDefaultOutputDevice()
        let isDefaultJump = currentDefault?.isJumpAudio ?? false
        
        // Case 1: Jump session was active and just ended (or Jump disconnected and left Jump Audio as default)
        if previousState == true && isRunning == false {
            if isDefaultJump && autoRevertOnDisconnect {
                revertToPreferred(reason: "Jump Desktop disconnected")
            }
        }
        
        // Case 2: Jump is NOT running, but default output is Jump Audio (e.g. AirPods disconnected, or Jump stuck)
        if !isRunning && isDefaultJump && blockJumpAsFallback {
            revertToPreferred(reason: "Jump Audio was selected while session is inactive")
        }
    }
    
    private func handleDefaultOutputChange(current: AudioDevice?) {
        guard let current = current else { return }
        
        if !current.isJumpAudio {
            // User or system switched to a real physical device
            lastNonJumpOutputUID = current.uid
        } else {
            // Output switched to Jump Audio
            let jumpRunning = AudioManager.shared.isDeviceRunning(id: current.id)
            if !jumpRunning && blockJumpAsFallback {
                // Not an active session (e.g. AirPods disconnect fallback) -> immediately restore preferred
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                    self?.revertToPreferred(reason: "Prevented Jump Audio fallback")
                }
            }
        }
    }
    
    func revertToPreferred(reason: String) {
        let targetUID = preferredOutputUID ?? lastNonJumpOutputUID
        guard let uid = targetUID else { return }
        
        if AudioManager.shared.setDefaultOutputDevice(uid: uid) {
            let targetDevice = AudioManager.shared.getAllDevices().first { $0.uid == uid }
            let name = targetDevice?.name ?? "Default Speakers"
            
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

// MARK: - Menu Bar App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    let menu = NSMenu()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
        
        setupStatusItem()
        AudioGuardEngine.shared.start()
        
        AudioManager.shared.onDevicesChanged = { [weak self] in
            self?.updateMenu()
        }
        AudioManager.shared.onDefaultOutputChanged = { [weak self] _ in
            self?.updateMenu()
        }
        AudioManager.shared.onDefaultInputChanged = { [weak self] _ in
            self?.updateMenu()
        }
        
        // Refresh menu every 2 seconds for live status
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateMenu()
        }
        
        updateMenu()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "speaker.wave.2.fill", accessibilityDescription: "AudioGuard")
            button.imagePosition = .imageLeft
        }
        statusItem.menu = menu
    }
    
    @objc func updateMenu() {
        menu.removeAllItems()
        
        let currentOut = AudioManager.shared.getDefaultOutputDevice()
        let currentIn = AudioManager.shared.getDefaultInputDevice()
        let isJump = currentOut?.isJumpAudio ?? false
        let isJumpActive = AudioGuardEngine.shared.isJumpSessionActive
        
        // Update Menu Bar Icon
        if let button = statusItem.button {
            if isJumpActive {
                button.image = NSImage(systemSymbolName: "antenna.radiowaves.left.and.right", accessibilityDescription: "Jump Remote Active")
                button.title = " Remote"
            } else {
                button.image = NSImage(systemSymbolName: "speaker.wave.2.fill", accessibilityDescription: "AudioGuard")
                button.title = ""
            }
        }
        
        // --- Header Section ---
        let headerTitle = isJumpActive ? "🔵 Jump Desktop Session: Active" : (isJump ? "🟡 Jump Audio: Idle" : "🟢 AudioGuard: Guarding")
        let headerItem = NSMenuItem(title: headerTitle, action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)
        
        let outName = currentOut?.name ?? "None"
        let outItem = NSMenuItem(title: "🔊 Output: \(outName)", action: nil, keyEquivalent: "")
        outItem.isEnabled = false
        menu.addItem(outItem)
        
        let inName = currentIn?.name ?? "None"
        let inItem = NSMenuItem(title: "🎙️ Input: \(inName)", action: nil, keyEquivalent: "")
        inItem.isEnabled = false
        menu.addItem(inItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // --- Preferred Fallback Output Submenu ---
        let prefOutMenu = NSMenu()
        let allDevices = AudioManager.shared.getAllDevices()
        let outDevices = allDevices.filter { $0.isOutput && !$0.isJumpAudio }
        let currentPrefOut = AudioGuardEngine.shared.preferredOutputUID
        
        for dev in outDevices {
            let item = NSMenuItem(title: dev.name, action: #selector(selectPreferredOutput(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = dev.uid
            if dev.uid == currentPrefOut {
                item.state = .on
            }
            prefOutMenu.addItem(item)
        }
        
        let prefOutMenuItem = NSMenuItem(title: "🎵 Preferred Fallback Output", action: nil, keyEquivalent: "")
        prefOutMenuItem.submenu = prefOutMenu
        menu.addItem(prefOutMenuItem)
        
        // --- Preferred Fallback Input Submenu ---
        let prefInMenu = NSMenu()
        let inDevices = allDevices.filter { $0.isInput && !$0.isJumpAudio }
        let currentPrefIn = AudioGuardEngine.shared.preferredInputUID
        
        for dev in inDevices {
            let item = NSMenuItem(title: dev.name, action: #selector(selectPreferredInput(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = dev.uid
            if dev.uid == currentPrefIn {
                item.state = .on
            }
            prefInMenu.addItem(item)
        }
        
        let prefInMenuItem = NSMenuItem(title: "🎙️ Preferred Fallback Input", action: nil, keyEquivalent: "")
        prefInMenuItem.submenu = prefInMenu
        menu.addItem(prefInMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // --- Action: Switch to Preferred Now ---
        let restoreItem = NSMenuItem(title: "⚡ Switch to Preferred Audio Now", action: #selector(restoreNow), keyEquivalent: "r")
        restoreItem.target = self
        menu.addItem(restoreItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // --- Settings Section ---
        let revertToggle = NSMenuItem(title: "Auto-Revert on Jump Disconnect", action: #selector(toggleAutoRevert), keyEquivalent: "")
        revertToggle.target = self
        revertToggle.state = AudioGuardEngine.shared.autoRevertOnDisconnect ? .on : .off
        menu.addItem(revertToggle)
        
        let blockToggle = NSMenuItem(title: "Block Jump Audio as Auto-Fallback", action: #selector(toggleBlockFallback), keyEquivalent: "")
        blockToggle.target = self
        blockToggle.state = AudioGuardEngine.shared.blockJumpAsFallback ? .on : .off
        menu.addItem(blockToggle)
        
        let notifToggle = NSMenuItem(title: "Show Notifications on Revert", action: #selector(toggleNotifications), keyEquivalent: "")
        notifToggle.target = self
        notifToggle.state = AudioGuardEngine.shared.showNotifications ? .on : .off
        menu.addItem(notifToggle)
        
        let launchToggle = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchToggle.target = self
        launchToggle.state = isLaunchAtLoginEnabled() ? .on : .off
        menu.addItem(launchToggle)
        
        menu.addItem(NSMenuItem.separator())
        
        // --- Quit ---
        let quitItem = NSMenuItem(title: "Quit AudioGuard", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }
    
    @objc func selectPreferredOutput(_ sender: NSMenuItem) {
        if let uid = sender.representedObject as? String {
            AudioGuardEngine.shared.preferredOutputUID = uid
            updateMenu()
        }
    }
    
    @objc func selectPreferredInput(_ sender: NSMenuItem) {
        if let uid = sender.representedObject as? String {
            AudioGuardEngine.shared.preferredInputUID = uid
            updateMenu()
        }
    }
    
    @objc func restoreNow() {
        AudioGuardEngine.shared.revertToPreferred(reason: "Manual switch triggered")
        if let inputUID = AudioGuardEngine.shared.preferredInputUID {
            _ = AudioManager.shared.setDefaultInputDevice(uid: inputUID)
        }
        updateMenu()
    }
    
    @objc func toggleAutoRevert() {
        AudioGuardEngine.shared.autoRevertOnDisconnect.toggle()
        updateMenu()
    }
    
    @objc func toggleBlockFallback() {
        AudioGuardEngine.shared.blockJumpAsFallback.toggle()
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
