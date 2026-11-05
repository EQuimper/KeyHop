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

    static func load(_ mode: String, shift: Bool) -> Binding {
        if let data = UserDefaults.standard.dictionary(forKey: mode),
           let key = data["key"] as? NSNumber, let flags = data["flags"] as? NSNumber,
           let name = data["name"] as? String {
            return Binding(key: key.uint16Value, flags: CGEventFlags(rawValue: flags.uint64Value), name: name)
        }
        return Binding(key: 38, flags: shift ? [.maskControl, .maskShift] : .maskControl, name: "J")
    }

    func save(_ mode: String) {
        UserDefaults.standard.set(["key": NSNumber(value: key), "flags": NSNumber(value: flags), "name": name], forKey: mode)
    }
}

final class Keyboard {
    var consume: (Binding, String, Bool) -> Bool = { _, _, _ in false }
    var interrupted: () -> Void = {}
    private var tap: CFMachPort?
    private var held = Set<UInt16>()

    func start() -> Bool {
        if tap != nil { return true }
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, context in
            let keyboard = Unmanaged<Keyboard>.fromOpaque(context!).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                keyboard.interrupted()
                keyboard.held.removeAll()
                if let tap = keyboard.tap { CGEvent.tapEnable(tap: tap, enable: true) }
                return Unmanaged.passUnretained(event)
            }
            let code = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            if type == .keyUp {
                return keyboard.held.remove(code) != nil ? nil : Unmanaged.passUnretained(event)
            }
            let repeating = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            if repeating && keyboard.held.contains(code) { return nil }
            let text = NSEvent(cgEvent: event)?.charactersIgnoringModifiers ?? ""
            let binding = Binding(key: code, flags: event.flags, name: text)
            if keyboard.consume(binding, text, repeating) {
                keyboard.held.insert(code)
                return nil
            }
            return Unmanaged.passUnretained(event)
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
