import AppKit
import ApplicationServices
import SwiftUI

final class App: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let session = Session()
    private let keyboard = Keyboard()
    private var item: NSStatusItem!
    private var observer: NSObjectProtocol?
    private var permissionTimer: Timer?
    private var keyboardReady = false
    private var settingsWindow: NSWindow?
    private var click = Binding.load("click", shift: false)
    private var select = Binding.load("select", shift: true)
    private var exclusions: [String] {
        get { UserDefaults.standard.stringArray(forKey: "excluded") ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: "excluded") }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "scope", accessibilityDescription: "KeyHop")
        item.button?.toolTip = "KeyHop"
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        keyboard.consume = { [weak self] binding, text, repeatKey in
            self?.handle(binding, text, repeatKey) ?? false
        }
        keyboard.interrupted = { [weak self] in self?.session.stop() }
        observer = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
                                                                     object: nil, queue: .main) { [weak self] _ in
            self?.session.stop()
        }
        tryKeyboard()
        if !keyboardReady {
            requestAccessibility()
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
                self?.tryKeyboard()
                if self?.keyboardReady == true { timer.invalidate() }
            }
        }
    }

    private func tryKeyboard() {
        keyboardReady = AXIsProcessTrusted() && keyboard.start()
    }

    @objc private func requestAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    private func handle(_ binding: Binding, _ text: String, _ repeatKey: Bool) -> Bool {
        if session.active {
            let systemChord: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate]
            if !CGEventFlags(rawValue: binding.flags).intersection(systemChord).isEmpty {
                session.stop()
                return false
            }
            let shift = CGEventFlags(rawValue: binding.flags).contains(.maskShift)
            session.handle(key: binding.key, text: text, button: shift ? .right : .left)
            return true
        }
        guard !repeatKey, click.matches(binding) || select.matches(binding),
              let app = NSWorkspace.shared.frontmostApplication,
              app.bundleIdentifier != Bundle.main.bundleIdentifier, !exclusions.contains(app.bundleIdentifier ?? "") else { return false }
        let selecting = select.matches(binding)
        DispatchQueue.main.async { [weak self] in
            guard NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier else { return }
            self?.session.begin(select: selecting, pid: app.processIdentifier)
        }
        return true
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        func add(_ title: String, _ action: Selector?) -> NSMenuItem {
            let row = menu.addItem(withTitle: title, action: action, keyEquivalent: "")
            row.target = self
            return row
        }
        if !keyboardReady {
            _ = add("Allow Accessibility…", #selector(requestAccessibility))
            menu.addItem(.separator())
        }
        let settings = add("Settings…", #selector(openSettings))
        settings.keyEquivalent = ","
        if let front = NSWorkspace.shared.frontmostApplication, let id = front.bundleIdentifier,
           id != Bundle.main.bundleIdentifier {
            menu.addItem(.separator())
            let excluded = exclusions.contains(id)
            let row = add("\(excluded ? "Enable" : "Pause") in \(front.localizedName ?? id)", #selector(toggleExclusion(_:)))
            row.representedObject = id
        }
        menu.addItem(.separator())
        _ = add("Quit KeyHop", #selector(quit))
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return true
    }

    @objc private func openSettings() {
        session.stop()
        if settingsWindow == nil {
            let view = SettingsView { [weak self] mode, binding in
                if mode == "click" { self?.click = binding } else { self?.select = binding }
            }
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = "KeyHop Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            window.setFrameAutosaveName("KeyHopSettings")
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func toggleExclusion(_ row: NSMenuItem) {
        guard let id = row.representedObject as? String else { return }
        if exclusions.contains(id) { exclusions = exclusions.filter { $0 != id } }
        else { exclusions.append(id) }
    }

    @objc private func quit() { NSApp.terminate(nil) }
}

let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.run()
