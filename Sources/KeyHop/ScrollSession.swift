import AppKit
import ApplicationServices

final class ScrollSession {
    private let overlay = Overlay(frame: .zero)
    private var window: WindowTarget?
    private var targets = [Target]()
    private var navigation = ScrollNavigation(rects: [], bounds: .zero, letters: Hints.alphabet, spatial: false)
    private var boundaryNotice: String?
    private var cursorOrigin: CGPoint?
    private var cursorAnchor: CGPoint?

    var active: Bool { window != nil }

    func acceptsRepeats(key: UInt16, text: String) -> Bool {
        active && navigation.selected != nil && ScrollCommand(key: key, text: text)?.isRepeatable == true
    }

    func begin(pid: pid_t) {
        stop()
        guard let window = WindowTarget(pid: pid) else { NSSound.beep(); return }
        self.window = window
        targets = window.scrollTargets()
        navigation = ScrollNavigation(rects: targets.map(\.rect), bounds: window.bounds, letters: Keymap.letters(),
                                      spatial: UserDefaults.standard.string(forKey: Keymap.choiceKey) == Keymap.qwerty.rawValue)
        render()
    }

    func stop() {
        restoreCursor()
        boundaryNotice = nil
        overlay.hide()
        window = nil
        targets = []
    }

    func handle(key: UInt16, text: String, repeating: Bool) {
        if key == 53 { stop(); return }
        boundaryNotice = nil
        guard active else { return }
        if key == 48 {
            guard !repeating else { return }
            restoreCursor()
            navigation.choosePanel()
            render()
            return
        }
        if navigation.selected == nil {
            guard !repeating else { return }
            navigation.type(key: key, text: text)
            render()
        } else {
            let command = navigation.command(key: key, text: text, repeating: repeating)
            if let command { scroll(command) }
            render()
        }
    }

    private func render() {
        guard let window else { return }
        if let selected = navigation.selected {
            // Keep the document readable while scrolling, without tinting the panel.
            overlay.show(in: window.bounds, tags: [], highlights: [],
                         message: "Scroll · \(boundaryNotice ?? (navigation.pendingTop ? "g…" : targets[selected].title)) · hjkl / ↑↓←→ · u/d half-page · gg top · G bottom · Tab panels · Esc")
        } else {
            let tags = zip(targets, navigation.labels).map {
                Tag(label: $0.1, rect: $0.0.rect, prefix: navigation.prefix)
            }
            overlay.show(in: window.bounds, tags: tags, highlights: [], message: "Scroll · Choose a panel · Esc")
        }
    }

    private func scroll(_ command: ScrollCommand) {
        guard let window, let selected = navigation.selected,
              NSWorkspace.shared.frontmostApplication?.processIdentifier == window.pid,
              let current = WindowTarget(pid: window.pid), window.matches(current) else { stop(); return }
        let target = targets[selected]
        let rect: CGRect
        if let element = target.element {
            guard let frame = elementFrame(element) else { stop(); return }
            rect = frame.intersection(window.bounds)
        } else { rect = target.rect }
        guard rect.width >= 40, rect.height >= 40 else { stop(); return }
        let point = CGPoint(x: rect.midX, y: rect.midY)
        guard window.ownsVisiblePoint(point) else { stop(); return }
        if let anchor = cursorAnchor, let cursor = CGEvent(source: nil)?.location,
           hypot(cursor.x - anchor.x, cursor.y - anchor.y) > 2 { stop(); return }
        if cursorOrigin == nil { cursorOrigin = CGEvent(source: nil)?.location }
        // Wheel delivery follows the pointer in native apps and browser processes.
        CGWarpMouseCursorPosition(point)
        cursorAnchor = point
        if command == .top || command == .bottom {
            if !ScrollBoundary.jump(command, target: target, window: window) {
                boundaryNotice = "This panel does not support jumping to its ends"
            }
            return
        }
        guard let offset = command.offset(in: rect.size) else { return }
        let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2,
                            wheel1: -Int32(offset.y.rounded()), wheel2: -Int32(offset.x.rounded()), wheel3: 0)
        event?.location = point
        event?.flags = []
        event?.post(tap: .cghidEventTap)
    }

    private func restoreCursor() {
        if let origin = cursorOrigin, let anchor = cursorAnchor, let cursor = CGEvent(source: nil)?.location,
           hypot(cursor.x - anchor.x, cursor.y - anchor.y) <= 2 {
            CGWarpMouseCursorPosition(origin)
        }
        cursorOrigin = nil
        cursorAnchor = nil
    }
}
