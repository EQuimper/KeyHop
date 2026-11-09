import AppKit
import ApplicationServices
import Carbon.HIToolbox

final class Session {
    private enum Phase { case loading, click, start, end, grid, unavailable, message }
    private let overlay = Overlay(frame: .zero)
    private var window: WindowTarget?
    private var phase = Phase.loading
    private var targets = [Target]()
    private var candidates = [Int]()
    private var hints = [ClickHint]()
    private var openGroup: [Int]?
    private var anchor: Int?
    private var filtering = false
    private var query = ""
    private var prefix = ""
    private var groupCursor = 0
    private var currentMatch: Int?
    private var area = CGRect.zero
    private var generation = UUID()
    private var loading: Task<Void, Never>?
    private var deadline: DispatchWorkItem?
    private var readingWords = false
    private var pendingKeys: [(UInt16, String)] = []

    var active: Bool { window != nil }

    func stop() {
        generation = UUID()
        loading?.cancel()
        loading = nil
        deadline?.cancel()
        deadline = nil
        readingWords = false
        pendingKeys.removeAll()
        overlay.hide()
        window = nil
        targets = []
        openGroup = nil
        anchor = nil
    }

    func begin(select: Bool, pid: pid_t) {
        stop()
        guard let window = WindowTarget(pid: pid) else { NSSound.beep(); return }
        self.window = window
        phase = .loading
        readingWords = select
        status(select ? "Start · Type the first word" : "Finding controls · Space grid")
        let id = generation
        if select && !CGPreflightScreenCaptureAccess() {
            message("Allow Screen Recording for KeyHop, then try again.")
            DispatchQueue.main.async { _ = CGRequestScreenCaptureAccess() }
            return
        }
        let timeout = DispatchWorkItem { [weak self] in
            guard let self, self.generation == id, self.phase == .loading else { return }
            self.generation = UUID()
            self.loading?.cancel()
            self.loading = nil
            self.pendingKeys.removeAll()
            if select { self.message("Window reading timed out · Try selection again") }
            else { self.clickUnavailable("Finding controls timed out") }
        }
        deadline = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + (select ? 5 : 2), execute: timeout)
        loading = Task { @MainActor in
            do {
                let items: [Target]
                if select {
                    items = try await window.words()
                } else {
                    items = try await window.clickTargets()
                }
                guard self.generation == id, !Task.isCancelled else { return }
                self.deadline?.cancel()
                self.loading = nil
                self.targets = items
                if items.isEmpty {
                    if select { self.message("No visible words found") }
                    else { self.clickUnavailable("No controls found") }
                    return
                }
                self.phase = select ? .start : .click
                self.resetFilter(search: select)
                let buffered = self.pendingKeys
                self.pendingKeys.removeAll()
                for (key, text) in buffered where self.generation == id {
                    self.handle(key: key, text: text)
                }
            } catch {
                guard self.generation == id, !Task.isCancelled else { return }
                self.deadline?.cancel()
                self.loading = nil
                if select { self.message("Couldn’t read this window · Try another window") }
                else { self.clickUnavailable("Couldn’t read this window") }
            }
        }
    }

    private func status(_ text: String) {
        guard let window else { return }
        overlay.show(in: window.bounds, tags: [], highlights: [], message: text)
    }

    private func clickUnavailable(_ text: String) {
        phase = .unavailable
        status("\(text) · Space grid · Esc cancel")
    }

    private func message(_ text: String) {
        phase = .message
        status(text)
        let id = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            if self?.generation == id { self?.stop() }
        }
    }

    private func resetFilter(search: Bool) {
        filtering = search
        query = ""
        prefix = ""
        refreshMatches()
    }

    private func refreshMatches() {
        candidates = targets.indices.filter { query.isEmpty || targets[$0].title.localizedCaseInsensitiveContains(query) }
        currentMatch = SearchMatch.preferred(in: candidates, anchor: anchor, query: query)
        hints = ClickHint.make(rects: targets.map(\.rect), candidates: candidates,
                               groupMarkers: phase == .click && query.isEmpty, letters: Keymap.letters(),
                               spatialBounds: UserDefaults.standard.string(forKey: Keymap.choiceKey) == Keymap.qwerty.rawValue ? window?.bounds : nil)
        render()
    }

    private func render() {
        guard let window else { return }
        if phase == .grid {
            overlay.show(in: window.bounds, tags: (0..<9).map { Tag(label: String($0 + 1), rect: cell($0)) },
                         highlights: [area], message: "Point · 1–9 zoom · ↵ click · ⇧↵ right-click")
            return
        }
        if let group = openGroup {
            overlay.show(in: window.bounds, tags: [], highlights: [targets[group[groupCursor]].rect],
                         message: "Group · \(groupCursor + 1)/\(group.count) · ↑ ↓ · ↵ click · ⇧↵ right-click")
            return
        }
        let mode = phase == .click ? "Click" : (phase == .start ? "Start" : "End")
        let showHints = !filtering
        var tags = [Tag](), highlights = [CGRect]()
        if showHints {
            tags = hints.map { hint in
                let grouped = hint.members.count > 1
                let marker = hint.members[grouped ? (hint.members.count - 1) / 2 : 0]
                return Tag(label: hint.label + (grouped ? " ›" : ""), rect: targets[marker].rect,
                           prefix: prefix)
            }
        }
        if let index = currentMatch, filtering || phase == .end {
            if let anchor, phase == .end {
                for group in Dictionary(grouping: targets[min(anchor,index)...max(anchor,index)], by: { $0.line }).values {
                    highlights.append(group.reduce(CGRect.null) { $0.union($1.rect) })
                }
            } else { highlights.append(targets[index].rect) }
        }
        let earlierHint = currentMatch == nil && !candidates.isEmpty ? " · ↑ earlier match" : ""
        let detail = filtering
            ? "\(query.isEmpty ? "Type to find" : query) · \(candidates.count)\(earlierHint) · Tab labels · ↵"
            : "\(prefix.isEmpty ? "Type a label" : "Type the remaining letters") · / find" + (phase == .click ? " · Space grid" : "")
        overlay.show(in: window.bounds, tags: tags, highlights: highlights, message: "\(mode) · \(detail)" + (phase == .click ? " · ⇧ right-click" : ""))
    }

    func handle(key: UInt16, text: String, button: CGMouseButton = .left) {
        if key == 53 { stop(); return }
        if phase == .loading {
            if !readingWords && key == 49 {
                generation = UUID()
                deadline?.cancel()
                loading?.cancel()
                loading = nil
                enterGrid()
                return
            }
            if readingWords && pendingKeys.count < 512 {
                pendingKeys.append((key, text))
                let typed = pendingKeys.prefix(while: { $0.0 != 36 }).reduce(into: "") { value, input in
                    if input.0 == 51 {
                        if !value.isEmpty { value.removeLast() }
                    } else if input.1.count == 1 && !input.1.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) {
                        value += input.1
                    }
                }
                status("Start · " + (typed.isEmpty ? "Type the first word" : typed))
            }
            return
        }
        if phase == .unavailable {
            if key == 49 { enterGrid() }
            return
        }
        if phase == .message { return }
        if let group = openGroup {
            switch key {
            case 125, 126:
                groupCursor = (groupCursor + (key == 125 ? 1 : group.count - 1)) % group.count
                render()
            case 36: choose(group[groupCursor], button: button)
            default: break
            }
            return
        }
        if phase == .grid {
            if key == 36 { clickPoint(CGPoint(x: area.midX, y: area.midY), button: button); return }
            if let number = Int(text), (1...9).contains(number), area.width > 3, area.height > 3 {
                area = cell(number - 1)
                render()
            }
            return
        }
        if key == 48 { filtering.toggle(); prefix = ""; render(); return }
        if filtering {
            switch key {
            case 36: if let currentMatch { choose(currentMatch, button: button) }
            case 125, 126:
                guard !candidates.isEmpty else { return }
                currentMatch = SearchMatch.step(in: candidates, from: currentMatch, by: key == 125 ? 1 : -1)
                render()
            case 51:
                if !query.isEmpty { query.removeLast() }
                refreshMatches()
            default:
                if text.count == 1 && !text.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) {
                    query += text
                    refreshMatches()
                }
            }
            return
        }
        if text == "/" { filtering = true; prefix = ""; render(); return }
        if key == 49 && phase == .click { enterGrid(); return }
        if key == 51 { if !prefix.isEmpty { prefix.removeLast() }; render(); return }
        guard text.count == 1 else { return }
        let typed = prefix + text.lowercased()
        if let hint = hints.first(where: { $0.label == typed }) {
            if hint.members.count == 1 {
                choose(hint.members[0], button: button)
            } else {
                openGroup = hint.members
                groupCursor = 0
                prefix = ""
                render()
            }
            return
        }
        prefix = hints.contains(where: { $0.label.hasPrefix(typed) }) ? typed : ""
        render()
    }

    private func enterGrid() {
        guard let window else { return }
        phase = .grid
        area = window.bounds
        render()
    }

    private func cell(_ index: Int) -> CGRect {
        CGRect(x: area.minX + CGFloat(index % 3) * area.width / 3,
               y: area.minY + CGFloat(index / 3) * area.height / 3,
               width: area.width / 3, height: area.height / 3)
    }

    private func sameWindow() -> Bool {
        guard let window, NSWorkspace.shared.frontmostApplication?.processIdentifier == window.pid,
              let current = WindowTarget(pid: window.pid), window.matches(current) else { stop(); return false }
        return true
    }

    private func choose(_ index: Int, button: CGMouseButton) {
        guard sameWindow() else { return }
        let target = targets[index]
        switch phase {
        case .click:
            guard let element = target.element, let rect = elementFrame(element),
                  let window, rect.intersects(window.bounds) else {
                message("Control moved · Try again")
                return
            }
            let visible = rect.intersection(window.bounds)
            clickPoint(CGPoint(x: visible.midX, y: visible.midY), button: button)
        case .start:
            anchor = index
            phase = .end
            resetFilter(search: true)
        case .end:
            guard let anchor, let window else { return }
            let (start, end) = Hints.drag(from: targets[anchor], to: target, forward: anchor <= index)
            stop()
            mouse(.leftMouseDown, start)
            mouse(.leftMouseDragged, CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2))
            mouse(.leftMouseDragged, end)
            mouse(.leftMouseUp, end)
            copySelection(in: window)
        default: break
        }
    }

    private func copySelection(in target: WindowTarget) {
        // Give the host time to process mouse-up before invoking its own Copy command.
        let id = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in
            guard self?.generation == id,
                  NSWorkspace.shared.frontmostApplication?.processIdentifier == target.pid,
                  let current = WindowTarget(pid: target.pid), target.matches(current) else { return }
            for down in [true, false] {
                let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: down)
                event?.flags = .maskCommand
                event?.postToPid(target.pid)
            }
        }
    }

    private func clickPoint(_ point: CGPoint, button: CGMouseButton) {
        guard let window, sameWindow() else { return }
        overlay.hide()
        var hit: AXUIElement?
        var owner: pid_t = 0
        let hitStatus = AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(), Float(point.x), Float(point.y), &hit)
        let axOwnsPoint = hitStatus == .success && hit.map { AXUIElementGetPid($0, &owner) == .success && owner == window.pid } == true
        // Web content may belong to a helper process or have no accessible element.
        guard axOwnsPoint || window.ownsVisiblePoint(point) else {
            message("Target is covered · Try again")
            return
        }
        stop()
        // Some toolbar buttons acknowledge AXPress without handling a click.
        mouse(.mouseMoved, point)
        mouse(button == .right ? .rightMouseDown : .leftMouseDown, point, button: button)
        mouse(button == .right ? .rightMouseUp : .leftMouseUp, point, button: button)
    }

    private func mouse(_ type: CGEventType, _ point: CGPoint, button: CGMouseButton = .left) {
        let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: button)
        event?.setIntegerValueField(.mouseEventClickState, value: 1)
        event?.flags = []
        event?.post(tap: .cghidEventTap)
    }
}
