import SwiftUI

struct SettingsView: View {
    let onBindingChange: (String, Binding) -> Void
    @State private var click = Binding.load("click", shift: false)
    @State private var select = Binding.load("select", shift: true)
    @State private var recording: String?
    @State private var shortcutMessage = ""
    @State private var monitor: Any?
    @State private var labelColor = Color(nsColor: LabelColor.load())
    @State private var choice = Keymap(rawValue: UserDefaults.standard.string(forKey: Keymap.choiceKey) ?? "") ?? .standard
    @State private var letters = UserDefaults.standard.string(forKey: Keymap.customKey) ?? "asdfjkl"
    @State private var keymapMessage = ""

    private var previewLetters: [Character] {
        choice.letters(custom: letters, fallback: UserDefaults.standard.string(forKey: Keymap.customKey))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "scope").font(.system(size: 21, weight: .medium))
                    .frame(width: 38, height: 38).foregroundStyle(Color(nsColor: LabelColor.ink(on: NSColor(labelColor))))
                    .background(labelColor, in: RoundedRectangle(cornerRadius: 10))
                Text("KeyHop").font(.system(size: 28, weight: .semibold)).tracking(-1.1)
            }.padding(.horizontal, 28).padding(.vertical, 20)
            Divider()
            HStack(alignment: .top, spacing: 25) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Jump labels").font(.system(size: 18, weight: .semibold))
                    Text("Keymap").font(.callout).foregroundStyle(.secondary)
                    Picker("Keymap", selection: $choice) {
                        ForEach(Keymap.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }.labelsHidden().pickerStyle(.segmented)
                    .onChange(of: choice) { _, newValue in
                        if newValue == .custom {
                            letters = UserDefaults.standard.string(forKey: Keymap.customKey) ?? "asdfjkl"
                            applyLetters()
                        } else {
                            UserDefaults.standard.set(newValue.rawValue, forKey: Keymap.choiceKey)
                            keymapMessage = ""
                        }
                    }
                    if choice == .standard || choice == .homeRow {
                        Text(previewLetters.map(String.init).joined(separator: " "))
                            .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                            .accessibilityLabel("Jump keys: " + String(previewLetters))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if choice == .custom {
                        HStack {
                            TextField("Label letters", text: $letters)
                                .font(.system(.body, design: .monospaced)).onSubmit { applyLetters() }
                            Button("Apply") { applyLetters() }
                        }
                        if !keymapMessage.isEmpty { Text(keymapMessage).font(.caption).foregroundStyle(.secondary) }
                    }
                    HStack {
                        Text("Label color")
                        Spacer()
                        ColorPicker("Label color", selection: $labelColor, supportsOpacity: false)
                            .labelsHidden().onChange(of: labelColor) { _, color in LabelColor.save(NSColor(color)) }
                    }.frame(minHeight: 30)
                    Divider().padding(.vertical, 5)
                    Text("Shortcuts").font(.system(size: 18, weight: .semibold))
                    shortcut("Click", mode: "click", binding: click)
                    shortcut("Select and copy", mode: "select", binding: select)
                    if !shortcutMessage.isEmpty { Text(shortcutMessage).font(.caption).foregroundStyle(.secondary) }
                }.frame(width: 278, alignment: .leading)
                Divider()
                JumpPreview(letters: previewLetters, fill: labelColor, spatial: choice == .qwerty)
            }.padding(.horizontal, 28).padding(.vertical, 24)
            Divider()
            HStack {
                Link(destination: URL(string: "https://equimper.com")!) {
                    HStack(spacing: 5) {
                        Text("Created by Emanuel Quimper")
                        Image(systemName: "arrow.up.right").font(.system(size: 9, weight: .semibold))
                    }.font(.caption)
                }.foregroundStyle(.secondary)
                Spacer()
            }.padding(.horizontal, 28).padding(.vertical, 13)
        }
        .frame(width: 754)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color(nsColor: .windowBackgroundColor))
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
            stopRecording()
        }
        .onDisappear { stopRecording() }
    }

    private func shortcut(_ title: String, mode: String, binding: Binding) -> some View {
        HStack {
            Text(title)
            Spacer()
            Button {
                if recording == mode { stopRecording() } else { startRecording(mode) }
            } label: {
                Text(recording == mode ? "Press shortcut…" : binding.display)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 9).frame(minWidth: 48, minHeight: 24)
                    .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 5))
                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.primary.opacity(0.18)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title) shortcut")
        }
    }

    private func applyLetters() {
        guard let valid = Keymap.validated(letters) else {
            keymapMessage = "Use 2–26 different letters from A to Z."
            return
        }
        letters = valid
        UserDefaults.standard.set(valid, forKey: Keymap.customKey)
        UserDefaults.standard.set(Keymap.custom.rawValue, forKey: Keymap.choiceKey)
        keymapMessage = ""
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = nil
        shortcutMessage = ""
    }

    private func startRecording(_ mode: String) {
        stopRecording()
        recording = mode
        shortcutMessage = "Press a letter with ⌃, ⌥ or ⌘. Esc cancels."
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { stopRecording(); return nil }
            guard !event.isARepeat, let text = event.charactersIgnoringModifiers,
                  text.count == 1, text.first?.isLetter == true,
                  !event.modifierFlags.intersection([.control, .option, .command]).isEmpty else { return nil }
            let binding = Binding(key: event.keyCode, flags: CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue)), name: text)
            guard !(mode == "click" ? select : click).matches(binding) else {
                shortcutMessage = "That shortcut is assigned to the other action."
                return nil
            }
            binding.save(mode)
            if mode == "click" { click = binding } else { select = binding }
            onBindingChange(mode, binding)
            stopRecording()
            return nil
        }
    }
}
