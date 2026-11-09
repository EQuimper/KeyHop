import AppKit
import ApplicationServices

extension WindowTarget {
    func scrollTargets() -> [Target] {
        guard let element else { return [Target(title: "Window", rect: bounds)] }
        var queue = [element], seen = Set<AXUIElement>(), result = [Target](), index = 0
        let deadline = Date().addingTimeInterval(1)
        while index < queue.count && index < 3500 && Date() < deadline {
            let item = queue[index]
            index += 1
            guard seen.insert(item).inserted else { continue }
            let role = attribute(item, kAXRoleAttribute) as? String ?? ""
            let scrollable = role == kAXScrollAreaRole || attribute(item, kAXVerticalScrollBarAttribute) != nil
                || attribute(item, kAXHorizontalScrollBarAttribute) != nil
            if scrollable, (attribute(item, kAXEnabledAttribute) as? Bool) != false,
               let frame = elementFrame(item) {
                let rect = frame.intersection(bounds)
                if rect.width >= 40, rect.height >= 40,
                   !result.contains(where: { $0.rect.integral == rect.integral }) {
                    let title = ControlLabel.text(title: attribute(item, kAXTitleAttribute) as? String,
                                                  description: attribute(item, kAXDescriptionAttribute) as? String,
                                                  itemName: nil, fallback: "Panel")
                    result.append(Target(title: title, rect: rect, element: item))
                }
            }
            let visible = attribute(item, kAXVisibleChildrenAttribute) as? [AXUIElement] ?? []
            let children = visible.isEmpty ? (attribute(item, kAXChildrenAttribute) as? [AXUIElement] ?? []) : visible
            queue.append(contentsOf: children.prefix(max(0, 5000 - queue.count)))
        }
        // Some browsers and custom views do not expose their scroll containers.
        return result.isEmpty ? [Target(title: "Window", rect: bounds)] : result
    }
}
