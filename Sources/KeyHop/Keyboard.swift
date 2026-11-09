import AppKit
import ApplicationServices

struct Binding {
    let key: UInt16
    let flags: UInt64
    let name: String

    static let modifiers: CGEventFlags = [.maskControl, .maskShift, .maskAlternate, .maskCommand]

    init(key: UInt16, flags: CGEventFlags, name: String) {
        self.key = key
        self.flags = flags.intersection(Self.modifiers).rawValue
        self.name = name
    }

    var display: String {
        let flags = CGEventFlags(rawValue: flags)
        return [(CGEventFlags.maskControl, "⌃"), (.maskAlternate, "⌥"), (.maskShift, "⇧"), (.maskCommand, "⌘")]
            .filter { flags.contains($0.0) }.map { $0.1 }.joined() + name.uppercased()
    }

    func matches(_ other: Binding) -> Bool { key == other.key && flags == other.flags }

    static func load(_ mode: String, shift: Bool = false) -> Binding {
        if let data = UserDefaults.standard.dictionary(forKey: mode),
           let key = data["key"] as? NSNumber, let flags = data["flags"] as? NSNumber,
           let name = data["name"] as? String {
            return Binding(key: key.uint16Value, flags: CGEventFlags(rawValue: flags.uint64Value), name: name)
        }
        return Binding(key: 38, flags: mode == "scroll" ? [.maskControl, .maskAlternate] : (shift ? [.maskControl, .maskShift] : .maskControl), name: "J")
    }

    func save(_ mode: String) {
        UserDefaults.standard.set(["key": NSNumber(value: key), "flags": NSNumber(value: flags), "name": name], forKey: mode)
    }
}

final class Keyboard {
    var consume: (Binding, String, Bool) -> Bool = { _, _, _ in false }
    var interrupted: () -> Void = {}
    var repeatAllowed: (Binding, String) -> Bool = { _, _ in false }
    private var repeatKeys = Set<UInt16>()
    private var tap: CFMachPort?
    private var held = Set<UInt16>()

    func consumeKey(_ event: CGEvent, type: CGEventType) -> Bool {
        let code = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        if type == .keyUp {
            repeatKeys.remove(code)
            return held.remove(code) != nil
        }
        let repeating = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        if repeating && held.contains(code) && !repeatKeys.contains(code) { return true }
        let text = NSEvent(cgEvent: event)?.charactersIgnoringModifiers ?? ""
        let binding = Binding(key: code, flags: event.flags, name: text)
        // Decide before handling: a panel label must not become a held scroll key.
        let allowRepeat = !repeating && repeatAllowed(binding, text)
        if consume(binding, text, repeating) {
            if allowRepeat { repeatKeys.insert(code) }
            held.insert(code)
            return true
        }
        // A mode can end while the key is still down. Keep swallowing its remaining repeats.
        return repeating && held.contains(code)
    }

    func start() -> Bool {
        if tap != nil { return true }
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, context in
            let keyboard = Unmanaged<Keyboard>.fromOpaque(context!).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                keyboard.interrupted()
                keyboard.held.removeAll()
                keyboard.repeatKeys.removeAll()
                if let tap = keyboard.tap { CGEvent.tapEnable(tap: tap, enable: true) }
                return Unmanaged.passUnretained(event)
            }
            return keyboard.consumeKey(event, type: type) ? nil : Unmanaged.passUnretained(event)
        }
        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                           options: .defaultTap, eventsOfInterest: CGEventMask(mask),
                                           callback: callback, userInfo: Unmanaged.passUnretained(self).toOpaque())
        else { return false }
        tap = port
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        return true
    }
}
