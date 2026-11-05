import AppKit

struct Tag {
    let label: String
    let rect: CGRect
    var prefix = ""
    var visible: Bool { label.hasPrefix(prefix) }
    var text: String { String(label.dropFirst(prefix.count)) }
}

final class Overlay: NSView {
    override var isFlipped: Bool { true }
    private var panel: NSPanel?
    private var boundsOnScreen = CGRect.zero
    private var tags = [Tag]()
    private var highlights = [CGRect]()
    private var message = ""

    func show(in rect: CGRect, tags: [Tag], highlights: [CGRect], message: String) {
        let top = CGDisplayBounds(CGMainDisplayID()).height
        let screenRect = CGRect(x: rect.minX, y: top - rect.maxY, width: rect.width, height: rect.height)
        if panel == nil {
            let panel = NSPanel(contentRect: screenRect, styleMask: [.borderless, .nonactivatingPanel],
                                backing: .buffered, defer: false)
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.ignoresMouseEvents = true
            panel.hidesOnDeactivate = false
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            panel.contentView = self
            self.panel = panel
        }
        self.boundsOnScreen = rect
        self.tags = tags
        self.highlights = highlights
        self.message = message
        panel?.setFrame(screenRect, display: true)
        needsDisplay = true
        panel?.orderFrontRegardless()
    }

    func hide() { panel?.orderOut(nil) }

    override func draw(_ dirtyRect: NSRect) {
        func local(_ rect: CGRect) -> CGRect {
            rect.offsetBy(dx: -boundsOnScreen.minX, dy: -boundsOnScreen.minY)
        }
        NSColor.systemPurple.withAlphaComponent(0.35).setFill()
        for rect in highlights { NSBezierPath(roundedRect: local(rect), xRadius: 2, yRadius: 2).fill() }

        let fill = LabelColor.load()
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .bold), .foregroundColor: LabelColor.ink(on: fill)
        ]
        let status = message as NSString
        let style: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13, weight: .medium),
                                                    .foregroundColor: NSColor.white]
        let size = status.size(withAttributes: style)
        let badge = CGRect(x: (bounds.width - size.width - 24) / 2, y: bounds.height - 42,
                           width: size.width + 24, height: 28)
        let anchors = tags.map { tag in
            let text = (tag.label as NSString).size(withAttributes: attributes)
            return HintAnchor(target: local(tag.rect), size: CGSize(width: ceil(text.width) + 8, height: ceil(text.height) + 3))
        }
        var indices = Array(tags.indices)
        var frames = HintLayout.frames(for: anchors, in: bounds, avoiding: badge.insetBy(dx: -3, dy: -3))
        // On a saturated screen a typed prefix frees up space for previously hidden labels.
        if indices.contains(where: { !tags[$0].visible }) && indices.contains(where: { tags[$0].visible && frames[$0] == nil }) {
            indices = indices.filter { tags[$0].visible }
            frames = HintLayout.frames(for: indices.map { anchors[$0] }, in: bounds, avoiding: badge.insetBy(dx: -3, dy: -3))
        }
        let placed = zip(indices, frames).compactMap { i, box -> (Int, CGRect)? in
            guard tags[i].visible, let box else { return nil }
            return (i, box)
        }

        for (i, box) in placed {
            let target = anchors[i].target
            let start = CGPoint(x: min(max(target.midX, box.minX), box.maxX),
                                y: min(max(target.midY, box.minY), box.maxY))
            let end = CGPoint(x: min(max(start.x, target.minX), target.maxX),
                              y: min(max(start.y, target.minY), target.maxY))
            guard hypot(end.x - start.x, end.y - start.y) > 6 else { continue }
            let line = NSBezierPath()
            line.move(to: start)
            line.line(to: end)
            fill.blended(withFraction: 0.25, of: .black)?.withAlphaComponent(0.75).setStroke()
            line.lineWidth = 1
            line.stroke()
        }
        for (i, box) in placed {
            let text = tags[i].text as NSString
            // Reserve the original label's slot so typing never moves a target.
            var badge = box
            badge.size.width = ceil(text.size(withAttributes: attributes).width) + 8
            fill.setFill()
            NSBezierPath(roundedRect: badge, xRadius: 3, yRadius: 3).fill()
            text.draw(at: CGPoint(x: box.minX + 4, y: box.minY + 1), withAttributes: attributes)
        }
        NSColor(white: 0.09, alpha: 0.94).setFill()
        NSBezierPath(roundedRect: badge, xRadius: 8, yRadius: 8).fill()
        status.draw(at: CGPoint(x: badge.minX + 12, y: badge.midY - size.height / 2), withAttributes: style)
    }
}
