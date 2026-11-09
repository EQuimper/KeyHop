import AppKit
import ApplicationServices
import Carbon.HIToolbox

/// End-of-document is an absolute operation. Browsers clamp wheel events to a page.
enum ScrollBoundary {
    static func keyEvents(for command: ScrollCommand) -> [CGEvent] {
        let key: CGKeyCode
        switch command {
        case .top: key = CGKeyCode(kVK_Home)
        case .bottom: key = CGKeyCode(kVK_End)
        default: return []
        }
        return [true, false].compactMap { down in
            guard let event = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: down) else { return nil }
            event.flags = []
            return event
        }
    }

    static func jump(_ command: ScrollCommand, target: Target, window: WindowTarget) -> Bool {
        guard command == .top || command == .bottom else { return false }
        if let element = target.element,
           let bar = axElement(attribute(element, kAXVerticalScrollBarAttribute)) {
            var settable = DarwinBoolean(false)
            if AXUIElementIsAttributeSettable(bar, kAXValueAttribute as CFString, &settable) == .success,
               settable.boolValue {
                let limit = command == .top ? kAXMinValueAttribute : kAXMaxValueAttribute
                let value = attribute(bar, limit) as? NSNumber ?? NSNumber(value: command == .top ? 0 : 1)
                if AXUIElementSetAttributeValue(bar, kAXValueAttribute as CFString, value) == .success,
                   let actual = attribute(bar, kAXValueAttribute) as? NSNumber,
                   abs(actual.doubleValue - value.doubleValue) < 0.0001 { return true }
            }
        }
        guard let root = target.element ?? window.element,
              let focusTarget = webFocusTarget(in: root) else { return false }
        let app = AXUIElementCreateApplication(window.pid)
        func hasFocus() -> Bool {
            guard let focused = axElement(attribute(app, kAXFocusedUIElementAttribute)) else { return false }
            return CFEqual(focused, focusTarget)
        }
        if !hasFocus() {
            // Focus the document/container without clicking links or editing a focused input.
            guard AXUIElementSetAttributeValue(focusTarget, kAXFocusedAttribute as CFString, kCFBooleanTrue) == .success,
                  hasFocus() else { return false }
        }
        let events = keyEvents(for: command)
        guard events.count == 2 else { return false }
        for event in events { event.postToPid(window.pid) }
        return true
    }

    private static func axElement(_ value: CFTypeRef?) -> AXUIElement? {
        guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private static func webFocusTarget(in root: AXUIElement) -> AXUIElement? {
        if attribute(root, kAXRoleAttribute) as? String == "AXWebArea" { return root }
        // A selected container inside a web document must receive its own Home/End.
        var parent = axElement(attribute(root, kAXParentAttribute))
        for _ in 0..<40 {
            guard let current = parent else { break }
            if attribute(current, kAXRoleAttribute) as? String == "AXWebArea" { return root }
            parent = axElement(attribute(current, kAXParentAttribute))
        }
        // Browser AXScrollArea wrappers normally contain one AXWebArea. Ignore nested
        // scroll areas and background tabs, and never choose arbitrarily between documents.
        var queue = [root], seen = Set<AXUIElement>(), documents = [AXUIElement](), index = 0
        while index < queue.count && index < 200 {
            let item = queue[index]
            index += 1
            guard seen.insert(item).inserted else { continue }
            let role = attribute(item, kAXRoleAttribute) as? String ?? ""
            if role == "AXWebArea" { documents.append(item); continue }
            if item != root && role == kAXScrollAreaRole { continue }
            let visible = attribute(item, kAXVisibleChildrenAttribute) as? [AXUIElement] ?? []
            let children = visible.isEmpty ? (attribute(item, kAXChildrenAttribute) as? [AXUIElement] ?? []) : visible
            queue.append(contentsOf: children.prefix(max(0, 200 - queue.count)))
        }
        return documents.count == 1 ? documents[0] : nil
    }
}
