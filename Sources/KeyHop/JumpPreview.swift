import SwiftUI

struct JumpPreview: View {
    let letters: [Character]
    let fill: Color
    let spatial: Bool
    private enum Mode: String, CaseIterable { case click = "Click", text = "Select text" }
    @State private var mode: Mode = .click
    @State private var selection = PreviewSelection()
    @State private var wordLabels = false
    @FocusState private var focused: Bool
    @State private var keyboardMonitor: Any?
    @State private var pressed: Set<String> = []
    @State private var releases: [String: UUID] = [:]
    @State private var prefix = ""
    @State private var selected: Int?
    @State private var contextFolder: Int?
    private let folders = ["Design", "Documents", "Projects", "Archive"]
    private var labels: [String] {
        guard spatial else { return Hints.labels(count: folders.count, alphabet: letters) }
        let points = folders.indices.map { CGPoint(x: 0.5, y: (58 + CGFloat($0) * 34) / 184) }
        return SpatialKeymap.labels(points: points, bounds: unitBounds)
    }
    private var unitBounds: CGRect { CGRect(x: 0, y: 0, width: 1, height: 1) }
    private var wordsToLabel: [Int: String] {
        let indices = selection.candidates
        let points = indices.map { index in
            CGPoint(x: (CGFloat(index % 3) + 0.5) / 3, y: (55 + CGFloat(index / 3) * 42) / 170)
        }
        let labels = spatial ? SpatialKeymap.labels(points: points, bounds: unitBounds)
                             : Hints.labels(count: points.count, alphabet: letters)
        return Dictionary(uniqueKeysWithValues: zip(indices, labels))
    }
    private var ink: Color { Color(nsColor: LabelColor.ink(on: NSColor(fill))) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Live preview", systemImage: "eye").font(.system(size: 13, weight: .semibold))
            Picker("Preview mode", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented).labelsHidden()
            ZStack {
                Canvas { context, size in
                    for x in stride(from: 8.0, to: size.width, by: 13) {
                        for y in stride(from: 8.0, to: size.height, by: 13) {
                            context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.4, height: 1.4)),
                                         with: .color(.white.opacity(0.13)))
                        }
                    }
                }
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Image(systemName: "sidebar.left")
                        Text(mode == .click ? "Folders" : "Note").font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Image(systemName: "list.bullet")
                    }
                    .foregroundStyle(.white.opacity(0.72)).padding(.horizontal, 13).frame(height: 35)
                    Divider().overlay(.white.opacity(0.09))
                    if mode == .text {
                        passage
                    } else {
                    VStack(spacing: 2) {
                        ForEach(folders.indices, id: \.self) { i in
                            HStack(spacing: 9) {
                                Image(systemName: "folder").foregroundStyle(.white.opacity(0.58))
                                Text(folders[i]).font(.system(size: 13))
                                Spacer()
                                if labels[i].hasPrefix(prefix) {
                                    Text(String(labels[i].dropFirst(prefix.count)))
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .foregroundStyle(ink).padding(.horizontal, 5).padding(.vertical, 2)
                                        .background(fill, in: RoundedRectangle(cornerRadius: 3))
                                }
                            }
                            .padding(.horizontal, 8).frame(height: 32)
                            .background(selected == i ? Color.white.opacity(0.12) : .clear,
                                        in: RoundedRectangle(cornerRadius: 5))
                            .popover(isPresented: SwiftUI.Binding(
                                get: { contextFolder == i },
                                set: { if !$0 { contextFolder = nil } }
                            )) {
                                Button("Select " + folders[i]) { selected = i; contextFolder = nil }
                                    .padding(8)
                            }
                        }
                    }.padding(6)
                    }
                }
                .foregroundStyle(.white.opacity(0.92))
                .background(Color(white: 0.135), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.16)))
                .shadow(color: .black.opacity(0.28), radius: 9, y: 5)
                .padding(.horizontal, 22)
            }
            .frame(height: 220)
            .background(Color(white: 0.085))
            .clipShape(RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(focused ? fill.opacity(0.72) : .white.opacity(0.12)))
            .contentShape(Rectangle())
            .focusable().focused($focused).focusEffectDisabled()
            .onTapGesture { focused = true }
            .onKeyPress { press in
                guard focused, press.modifiers.intersection([.command, .control, .option]).isEmpty else { return .ignored }
                if mode == .text { return handleSelection(press) }
                if press.key == .escape { prefix = ""; selected = nil; focused = false; return .handled }
                if press.key == .delete { if !prefix.isEmpty { prefix.removeLast() }; return .handled }
                let character = press.characters.lowercased()
                guard character.count == 1, let key = character.first, letters.contains(key) else { return .ignored }
                let input = prefix + character
                if let i = labels.firstIndex(of: input) {
                    if press.modifiers.contains(.shift) { contextFolder = i } else { selected = i }
                    prefix = ""
                }
                else { prefix = labels.contains(where: { $0.hasPrefix(input) }) ? input : "" }
                return .handled
            }
            .onChange(of: letters) { _, _ in resetPreview() }
            .onChange(of: mode) { _, _ in resetPreview(); focused = true }
            .onChange(of: focused) { _, active in
                if active { startKeyboardMonitor() }
                else { prefix = ""; stopKeyboardMonitor() }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in clearKeys() }
            .onDisappear { stopKeyboardMonitor() }
            PreviewKeyboard(letters: letters, pressed: pressed, fill: fill)
                .onTapGesture { focused = true }
            Text(instruction)
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func startKeyboardMonitor() {
        guard keyboardMonitor == nil else { return }
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { event in
            guard focused, event.window?.isKeyWindow == true,
                  let key = PreviewKeyboard.keyIDs[event.keyCode] else { return event }
            if event.type == .flagsChanged {
                if let mask = PreviewKeyboard.modifierMasks[event.keyCode] {
                    showPress(key, down: event.modifierFlags.contains(mask))
                }
            } else {
                showPress(key, down: event.type == .keyDown)
            }
            return event
        }
    }

    private func stopKeyboardMonitor() {
        if let keyboardMonitor { NSEvent.removeMonitor(keyboardMonitor) }
        keyboardMonitor = nil
        clearKeys()
    }

    private func showPress(_ key: String, down: Bool) {
        if !down {
            guard pressed.contains(key) else { return }
            // Keep quick taps visible; an older release must never clear a newer press.
            let id = UUID()
            releases[key] = id
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                guard releases[key] == id else { return }
                releases.removeValue(forKey: key)
                pressed.remove(key)
            }
        } else {
            releases.removeValue(forKey: key)
            pressed.insert(key)
        }
    }

    private func clearKeys() {
        releases.removeAll()
        pressed.removeAll()
    }

    private var instruction: String {
        guard focused else { return "Click the preview to try your keys." }
        if mode == .click { return "Type a label to click. Hold ⇧ on its last letter to right-click." }
        if selection.finished { return "Selection complete. Press Return to try again." }
        if wordLabels { return "Type a label to choose the word." }
        return selection.anchor == nil ? "Type the first word, then Return. Tab shows labels."
                                       : "Type the last word, then Return. Tab shows labels."
    }

    private var passage: some View {
        VStack(spacing: 2) {
            ForEach(PreviewSelection.lines.indices, id: \.self) { line in
                HStack(spacing: 0) {
                    ForEach(PreviewSelection.lines[line].indices, id: \.self) { column in
                        let index = line * 3 + column
                        VStack(spacing: 1) {
                            if wordLabels, let label = wordsToLabel[index], label.hasPrefix(prefix) {
                                Text(String(label.dropFirst(prefix.count)))
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(ink).padding(.horizontal, 4).background(fill, in: RoundedRectangle(cornerRadius: 3))
                            } else { Color.clear.frame(height: 13) }
                            Text(PreviewSelection.words[index]).font(.system(size: 13))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 3)
                                .background(selection.range?.contains(index) == true ? Color.purple.opacity(0.55) : .clear)
                        }.frame(maxWidth: .infinity)
                    }
                }
            }
            Text(selection.finished ? "Selected" : (selection.anchor == nil ? "Start" : "End") +
                 (selection.query.isEmpty ? "" : " · " + selection.query) +
                 (selection.current == nil ? " · No match" : ""))
                .font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.65)).padding(.vertical, 5)
        }.padding(.horizontal, 7).padding(.top, 4)
    }

    private func resetPreview() {
        clearKeys()
        prefix = ""
        selected = nil
        contextFolder = nil
        selection = PreviewSelection()
        wordLabels = false
    }

    private func handleSelection(_ press: KeyPress) -> KeyPress.Result {
        switch press.key {
        case .escape:
            resetPreview()
            focused = false
        case .return:
            if selection.finished { resetPreview() }
            else if let index = selection.current { selection.choose(index); wordLabels = false; prefix = "" }
        case .tab:
            if !selection.finished { wordLabels.toggle(); prefix = "" }
        case .upArrow: if !selection.finished { selection.step(-1) }
        case .downArrow: if !selection.finished { selection.step(1) }
        case .delete:
            if wordLabels { if !prefix.isEmpty { prefix.removeLast() } }
            else { selection.edit(String(selection.query.dropLast())) }
        default:
            let character = press.characters.lowercased()
            guard character.count == 1, character.first?.isLetter == true || character == "." else { return .ignored }
            if wordLabels {
                let typed = prefix + character
                if let index = wordsToLabel.first(where: { $0.value == typed })?.key {
                    selection.choose(index); wordLabels = false; prefix = ""
                } else { prefix = wordsToLabel.values.contains { $0.hasPrefix(typed) } ? typed : "" }
            } else { selection.edit((selection.finished ? "" : selection.query) + character) }
        }
        return .handled
    }
}
