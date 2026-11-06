import AppKit
import ApplicationServices
import ScreenCaptureKit
import Vision

struct Target {
    let title: String
    let rect: CGRect // Global Quartz coordinates, origin at top left.
    var line = 0
    var element: AXUIElement?
}

enum Hints {
    static let alphabet = Array("fjdkalsghrueiwopqtyzxcvbnm")
    static func labels(count: Int, alphabet: [Character] = Hints.alphabet) -> [String] {
        guard count > 0 else { return [] }
        var width = 1, capacity = alphabet.count
        while capacity < count { width += 1; capacity *= alphabet.count }
        return (0..<count).map { index in
            var value = index, label = ""
            for _ in 0..<width {
                label.insert(alphabet[value % alphabet.count], at: label.startIndex)
                value /= alphabet.count
            }
            return label
        }
    }

    static func drag(from start: Target, to end: Target, forward: Bool) -> (CGPoint, CGPoint) {
        func point(_ rect: CGRect, leading: Bool) -> CGPoint {
            // An inset can cross the insertion midpoint of a narrow glyph such as “l”.
            CGPoint(x: leading ? rect.minX : rect.maxX, y: rect.midY)
        }
        return (point(start.rect, leading: forward), point(end.rect, leading: !forward))
    }
}

func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
    return value
}

func elementFrame(_ element: AXUIElement) -> CGRect? {
    guard let position = attribute(element, kAXPositionAttribute), CFGetTypeID(position) == AXValueGetTypeID(),
          let size = attribute(element, kAXSizeAttribute), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
    var origin = CGPoint.zero, extent = CGSize.zero
    guard AXValueGetValue(position as! AXValue, .cgPoint, &origin),
          AXValueGetValue(size as! AXValue, .cgSize, &extent) else { return nil }
    return CGRect(origin: origin, size: extent)
}

enum ControlLabel {
    static let itemRoles: Set<String> = ["AXImage", "AXCell", "AXStaticText", "AXTextField"]
    private static let roles: Set<String> = ["AXButton", "AXCheckBox", "AXRadioButton", "AXPopUpButton", "AXLink",
                                           "AXTextField", "AXTextArea", "AXToolbarItem", "AXMenuButton", "AXDisclosureTriangle"]

    static func isTarget(role: String, actions: [String]) -> Bool {
        roles.contains(role) || (itemRoles.contains(role) && (actions.contains("AXOpen") || actions.contains(kAXPressAction)))
    }

    static func text(title: String?, description: String?, itemName: String?, fallback: String) -> String {
        // Finder exposes filenames as AXValue in list/column views and descriptions in icon views.
        [title, itemName, description].compactMap { $0 }.first { !$0.isEmpty } ?? fallback
    }
}

struct WindowTarget {
    let pid: pid_t
    let bounds: CGRect
    let element: AXUIElement?
    let title: String
    let windowID: CGWindowID?

    // WindowServer supplies a grid surface even when an app exposes no AX window.
    private static func surfaces() -> [[String: Any]] {
        CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] ?? []
    }

    private static func surfaceFrame(_ info: [String: Any]) -> CGRect? {
        guard let dict = info[kCGWindowBounds as String] as? NSDictionary else { return nil }
        return CGRect(dictionaryRepresentation: dict)
    }

    init?(pid: pid_t) {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.3)
        let raw = attribute(app, kAXFocusedWindowAttribute)
        let focused = raw.flatMap { CFGetTypeID($0) == AXUIElementGetTypeID() ? ($0 as! AXUIElement) : nil }
        let frame = focused.flatMap(elementFrame)
        let surface = Self.surfaces().first { info in
            guard info[kCGWindowOwnerPID as String] as? Int32 == pid,
                  info[kCGWindowLayer as String] as? Int == 0,
                  let rect = Self.surfaceFrame(info), !rect.isEmpty else { return false }
            guard let frame, !frame.isEmpty else { return true }
            return frame.integral == rect.integral
        }
        guard let bounds = (frame?.isEmpty == false ? frame : nil) ?? surface.flatMap(Self.surfaceFrame) else { return nil }
        self.bounds = bounds
        self.pid = pid
        element = focused
        title = focused.flatMap { attribute($0, kAXTitleAttribute) as? String } ?? ""
        windowID = surface?[kCGWindowNumber as String] as? CGWindowID
    }

    func matches(_ other: WindowTarget) -> Bool {
        guard pid == other.pid, bounds == other.bounds else { return false }
        if let windowID, let id = other.windowID { return windowID == id }
        guard let element, let current = other.element else { return false }
        return CFEqual(element, current)
    }

    func ownsVisiblePoint(_ point: CGPoint) -> Bool {
        guard let windowID else { return false }
        let top = Self.surfaces().first {
            $0[kCGWindowOwnerPID as String] as? Int32 != ProcessInfo.processInfo.processIdentifier &&
            ($0[kCGWindowAlpha as String] as? Double ?? 1) > 0 &&
            Self.surfaceFrame($0)?.contains(point) == true
        }
        return top?[kCGWindowNumber as String] as? CGWindowID == windowID
    }

    func clickTargets() async throws -> [Target] {
        guard element != nil else { return [] }
        let app = AXUIElementCreateApplication(pid)
        if attribute(app, "AXManualAccessibility") as? Bool == false {
            AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        }
        // Browser content can arrive after the window's close/minimize/zoom buttons.
        let chrome = ["AXCloseButton", "AXMinimizeButton", "AXZoomButton", "AXFullScreenButton"]
        for attempt in 0..<6 {
            try Task.checkCancellation()
            let items = controls()
            if items.contains(where: { target in
                guard let element = target.element else { return false }
                return !chrome.contains(attribute(element, kAXSubroleAttribute) as? String ?? "")
            }) { return items }
            if attempt < 5 { try await Task.sleep(nanoseconds: 150_000_000) }
        }
        return []
    }

    func controls() -> [Target] {
        guard let element else { return [] }
        var result = [Target](), queue = [element], seen = Set<AXUIElement>(), index = 0
        while index < queue.count && index < 3500 && !Task.isCancelled {
            let item = queue[index]
            index += 1
            guard seen.insert(item).inserted else { continue }
            let role = attribute(item, kAXRoleAttribute) as? String ?? ""
            var actions: CFArray?
            if ControlLabel.itemRoles.contains(role) { AXUIElementCopyActionNames(item, &actions) }
            let actionNames = actions as? [String] ?? []
            let opensItem = actionNames.contains("AXOpen")
            let actionable = ControlLabel.isTarget(role: role, actions: actionNames)
            if actionable, let rect = elementFrame(item), rect.width > 2, rect.height > 2,
               bounds.contains(CGPoint(x: rect.midX, y: rect.midY)),
               (attribute(item, kAXEnabledAttribute) as? Bool) != false {
                let title = ControlLabel.text(
                    title: attribute(item, kAXTitleAttribute) as? String,
                    description: attribute(item, kAXDescriptionAttribute) as? String,
                    itemName: opensItem ? attribute(item, kAXValueAttribute) as? String : nil,
                    fallback: role)
                result.append(Target(title: title, rect: rect, element: item))
            }
            let visible = attribute(item, kAXVisibleChildrenAttribute) as? [AXUIElement] ?? []
            let children = visible.isEmpty ? (attribute(item, kAXChildrenAttribute) as? [AXUIElement] ?? []) : visible
            queue.append(contentsOf: children.prefix(max(0, 5000 - queue.count)))
        }
        return result
    }

    func words() async throws -> [Target] {
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        // Match geometry as well as the process so squarely overlapping unrelated windows
        // are never chosen just because their titles happen to match.
        let candidates = content.windows.filter {
            $0.owningApplication?.processID == pid && $0.windowLayer == 0 &&
            abs($0.frame.minX - bounds.minX) < 3 && abs($0.frame.minY - bounds.minY) < 3 &&
            abs($0.frame.width - bounds.width) < 3 && abs($0.frame.height - bounds.height) < 3
        }
        let matches = candidates.filter { $0.title == title }
        guard let window = matches.count == 1 ? matches.first : (candidates.count == 1 ? candidates.first : nil)
        else { throw CaptureError.window }
        try Task.checkCancellation()
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        config.showsCursor = false
        config.ignoreShadowsSingleWindow = true
        config.width = Int((window.frame.width * CGFloat(filter.pointPixelScale)).rounded())
        config.height = Int((window.frame.height * CGFloat(filter.pointPixelScale)).rounded())
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        try Task.checkCancellation()
        return try Self.recognizeWords(image: image, in: bounds)
    }

    static func recognizeWords(image: CGImage, in bounds: CGRect) throws -> [Target] {
        let request = VNRecognizeTextRequest()
        // Interactive jumps need word positions without waiting for the accurate model to warm up.
        request.recognitionLevel = .fast
        request.recognitionLanguages = ["en-US", "fr-FR"]
        try VNImageRequestHandler(cgImage: image).perform([request])
        var words = [Target]()
        for (line, observation) in (request.results ?? []).enumerated() {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let string = candidate.string
            for token in string.split(whereSeparator: { $0.isWhitespace }) {
                let range = token.startIndex..<token.endIndex
                guard let box = try candidate.boundingBox(for: range)?.boundingBox else { continue }
                let rect = CGRect(x: bounds.minX + box.minX * bounds.width,
                                  y: bounds.minY + (1 - box.maxY) * bounds.height,
                                  width: box.width * bounds.width, height: box.height * bounds.height)
                words.append(Target(title: String(token), rect: rect, line: line))
            }
        }
        return words
    }

    enum CaptureError: Error { case window }
}
