// Audio Lock — keeps your Mac's sound on the device you chose.
// When a display (like a TV over AirPlay) connects or disconnects and macOS
// switches the sound on its own, Audio Lock switches it straight back.
// Changes you make yourself in Sound settings are kept.
// A headphones-and-lock icon in the menu bar shows that it is on, with a menu to turn it off or quit.

import Cocoa
import CoreAudio
import ServiceManagement

// MARK: - Core Audio helpers

enum Audio {
    static func address(_ selector: AudioObjectPropertySelector,
                        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector,
                                   mScope: scope,
                                   mElement: kAudioObjectPropertyElementMain)
    }

    static func defaultDevice(_ selector: AudioObjectPropertySelector) -> AudioDeviceID? {
        var addr = address(selector)
        var id = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &id)
        return (status == noErr && id != 0) ? id : nil
    }

    @discardableResult
    static func setDefaultDevice(_ selector: AudioObjectPropertySelector, _ device: AudioDeviceID) -> Bool {
        var addr = address(selector)
        var id = device
        let size = UInt32(MemoryLayout<AudioDeviceID>.size)
        return AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, size, &id) == noErr
    }

    static func allDevices() -> [AudioDeviceID] {
        var addr = address(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        let system = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(system, &addr, 0, nil, &size) == noErr, size > 0 else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &addr, 0, nil, &size, &ids) == noErr else { return [] }
        return ids
    }

    static func string(_ device: AudioDeviceID, _ selector: AudioObjectPropertySelector) -> String? {
        var addr = address(selector)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &value) == noErr,
              let cf = value?.takeRetainedValue() else { return nil }
        return cf as String
    }

    static func uid(_ device: AudioDeviceID) -> String? { string(device, kAudioDevicePropertyDeviceUID) }
    static func name(_ device: AudioDeviceID) -> String? { string(device, kAudioObjectPropertyName) }

    static func device(withUID uid: String) -> AudioDeviceID? {
        allDevices().first { Audio.uid($0) == uid }
    }
}

// MARK: - The lock

/// Guards one "default device" setting (main output or alert sounds).
final class DeviceLock {
    let selector: AudioObjectPropertySelector
    let storageKey: String

    /// UID of the device we keep the sound on.
    private(set) var lockedUID: String?
    /// The lock before the last change we accepted, so a late display event can undo it.
    private var previousUID: String?
    private var acceptedAt = Date.distantPast

    init(selector: AudioObjectPropertySelector, storageKey: String) {
        self.selector = selector
        self.storageKey = storageKey
    }

    var currentUID: String? { Audio.defaultDevice(selector).flatMap(Audio.uid) }

    func start() {
        let saved = UserDefaults.standard.string(forKey: storageKey)
        if let saved, Audio.device(withUID: saved) != nil {
            lockedUID = saved
            enforce()
        } else {
            save(currentUID)
        }
    }

    /// Lock to whatever device is playing sound right now.
    func lockToCurrent() {
        previousUID = nil
        save(currentUID)
    }

    private func save(_ uid: String?) {
        lockedUID = uid
        UserDefaults.standard.set(uid, forKey: storageKey)
    }

    /// Called when the default device changes.
    func defaultChanged(lastTopologyChange: @escaping () -> Date) {
        guard let current = currentUID, current != lockedUID else { return }
        let changedAt = Date()
        // Wait a moment so we can tell whether a display/device change caused this.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self, let current = self.currentUID, current != self.lockedUID else { return }
            if abs(lastTopologyChange().timeIntervalSince(changedAt)) < 6 {
                self.enforce()                       // caused by a display change: undo it
            } else {
                self.previousUID = self.lockedUID   // the user chose it: keep it
                self.acceptedAt = Date()
                self.save(current)
            }
        }
    }

    /// Called when a display or audio device is added or removed.
    func topologyChanged() {
        // If we accepted a switch just before this event, it was really caused by it.
        if Date().timeIntervalSince(acceptedAt) < 6, let previous = previousUID {
            save(previous)
            acceptedAt = .distantPast
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.enforce() }
    }

    /// Put the sound back on the locked device (retries, because macOS can switch twice).
    func enforce(attempt: Int = 0) {
        guard let locked = lockedUID, currentUID != locked else { return }
        guard let device = Audio.device(withUID: locked) else { return } // unplugged: nothing to do
        Audio.setDefaultDevice(selector, device)
        if attempt < 4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.enforce(attempt: attempt + 1)
            }
        }
    }
}

final class AudioLock {
    let output = DeviceLock(selector: kAudioHardwarePropertyDefaultOutputDevice, storageKey: "lockedOutputUID")
    let alerts = DeviceLock(selector: kAudioHardwarePropertyDefaultSystemOutputDevice, storageKey: "lockedSystemOutputUID")
    private var lastTopologyChange = Date.distantPast

    /// When off, Audio Lock does nothing. Saved between launches; on by default.
    var isOn: Bool {
        get { UserDefaults.standard.object(forKey: "isOn") as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: "isOn")
            if newValue { output.lockToCurrent(); alerts.lockToCurrent() }
        }
    }

    func start() {
        if isOn {
            output.start()
            alerts.start()
        }

        let system = AudioObjectID(kAudioObjectSystemObject)
        let now = { [weak self] in self?.lastTopologyChange ?? .distantPast }

        var outAddr = Audio.address(kAudioHardwarePropertyDefaultOutputDevice)
        AudioObjectAddPropertyListenerBlock(system, &outAddr, .main) { [weak self] _, _ in
            guard let self, self.isOn else { return }
            self.output.defaultChanged(lastTopologyChange: now)
        }
        var sysAddr = Audio.address(kAudioHardwarePropertyDefaultSystemOutputDevice)
        AudioObjectAddPropertyListenerBlock(system, &sysAddr, .main) { [weak self] _, _ in
            guard let self, self.isOn else { return }
            self.alerts.defaultChanged(lastTopologyChange: now)
        }
        var devAddr = Audio.address(kAudioHardwarePropertyDevices)
        AudioObjectAddPropertyListenerBlock(system, &devAddr, .main) { [weak self] _, _ in
            self?.topologyChanged()
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            self?.topologyChanged()
        }
    }

    private func topologyChanged() {
        lastTopologyChange = Date()
        guard isOn else { return }
        output.topologyChanged()
        alerts.topologyChanged()
    }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let lock = AudioLock()
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()

    func applicationDidFinishLaunching(_ notification: Notification) {
        lock.start()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menu.delegate = self
        statusItem.menu = menu
        updateIcon()

        // Start automatically at login.
        if SMAppService.mainApp.status != .enabled {
            try? SMAppService.mainApp.register()
        }
    }

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        button.image = Self.menuBarIcon(locked: lock.isOn)
        button.imagePosition = .imageOnly
        button.setAccessibilityLabel(lock.isOn ? "Audio Lock, on" : "Audio Lock, off")
        button.toolTip = lock.isOn ? "Audio Lock is on" : "Audio Lock is off"
    }

    /// The Audio Lock logo for the menu bar: blue rounded square, white headphones,
    /// orange lock in the middle. When off, the square turns gray and the lock is left out.
    static func menuBarIcon(locked: Bool) -> NSImage {
        let side: CGFloat = 18
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            let body = rect.insetBy(dx: 0.5, dy: 0.5)
            let path = NSBezierPath(roundedRect: body, xRadius: body.width * 0.24, yRadius: body.width * 0.24)
            let top = locked ? NSColor(red: 0.20, green: 0.45, blue: 1.0, alpha: 1) : NSColor(white: 0.55, alpha: 1)
            let bottom = locked ? NSColor(red: 0.10, green: 0.16, blue: 0.55, alpha: 1) : NSColor(white: 0.35, alpha: 1)
            NSGradient(starting: top, ending: bottom)?.draw(in: path, angle: -90)

            func symbol(_ name: String, _ size: CGFloat, _ weight: NSFont.Weight, _ color: NSColor) -> NSImage? {
                let config = NSImage.SymbolConfiguration(pointSize: size, weight: weight)
                    .applying(.init(paletteColors: [color]))
                return NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config)
            }
            if let phones = symbol("headphones", side * 0.62, .bold, .white) {
                let s = phones.size
                phones.draw(in: NSRect(x: (rect.width - s.width) / 2, y: (rect.height - s.height) / 2,
                                       width: s.width, height: s.height))
            }
            if locked, let lockImage = symbol("lock.fill", side * 0.30, .heavy,
                                              NSColor(red: 1.0, green: 0.66, blue: 0.0, alpha: 1)) {
                let s = lockImage.size
                lockImage.draw(in: NSRect(x: (rect.width - s.width) / 2, y: (rect.height - s.height) / 2 - side * 0.05,
                                          width: s.width, height: s.height))
            }
            return true
        }
        image.isTemplate = false
        return image
    }

    private func bigItem(_ title: String, bold: Bool = false, action: Selector? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.attributedTitle = NSAttributedString(string: title, attributes: [
            .font: bold ? NSFont.boldSystemFont(ofSize: 16) : NSFont.systemFont(ofSize: 16)
        ])
        // Info lines stay enabled (full contrast, easier to read) but do nothing when chosen.
        if action == nil { item.action = #selector(noop) }
        return item
    }

    // Rebuild the menu each time it opens so it always shows the live state.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(bigItem(lock.isOn ? "Audio Lock is ON" : "Audio Lock is OFF", bold: true))
        if lock.isOn {
            let name = lock.output.lockedUID.flatMap(Audio.device(withUID:)).flatMap(Audio.name) ?? "Unknown device"
            menu.addItem(bigItem("Sound locked to: \(name)"))
        }
        menu.addItem(.separator())
        menu.addItem(bigItem(lock.isOn ? "Turn Off" : "Turn On", action: #selector(toggle)))
        menu.addItem(.separator())
        let quitItem = bigItem("Quit Audio Lock", action: #selector(quitApp))
        quitItem.keyEquivalent = "q"
        menu.addItem(quitItem)
    }

    @objc private func toggle() {
        lock.isOn.toggle()
        updateIcon()
    }

    @objc private func noop() {}

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
