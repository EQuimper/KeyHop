import SwiftUI
import IOKit.hidsystem

/// The letter rows retain their ANSI offsets; the last row uses half-height arrows.
struct PreviewKeyboard: View {
    let letters: [Character]
    let pressed: Set<String>
    let fill: Color

    private var ink: Color { Color(nsColor: LabelColor.ink(on: NSColor(fill))) }
    private let gap: CGFloat = 2.5
    private let height: CGFloat = 21

    private func key(_ value: String, _ caption: String, _ units: CGFloat, _ pitch: CGFloat,
                     half: Bool = false) -> some View {
        let down = pressed.contains(value)
        let enabled = value.count == 1 && value.first.map(letters.contains) == true
        return Text(caption)
            .font(.system(size: caption.count > 2 ? 8 : 10, weight: enabled || down ? .semibold : .regular, design: .monospaced))
            .foregroundStyle(down ? ink : .white.opacity(enabled ? 0.93 : 0.42))
            .frame(width: units * pitch - gap, height: half ? (height - 2) / 2 : height)
            .background(down ? fill : Color(white: enabled ? 0.23 : 0.15), in: RoundedRectangle(cornerRadius: 3))
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(.white.opacity(down ? 0 : 0.09)))
            .offset(y: down ? 1 : 0)
    }

    private func row(_ keys: String, pitch: CGFloat) -> some View {
        ForEach(Array(keys), id: \.self) { letter in
            key(String(letter), String(letter).uppercased(), 1, pitch)
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let pitch = (proxy.size.width + gap) / 15
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: gap) {
                    row("`1234567890-=", pitch: pitch)
                    key("delete", "⌫", 2, pitch)
                }
                HStack(spacing: gap) {
                    key("tab", "⇥", 1.5, pitch)
                    row(SpatialKeymap.rows[0] + "[]", pitch: pitch)
                    key("\\", "\\", 1.5, pitch)
                }
                HStack(spacing: gap) {
                    key("caps", "⇪", 1.75, pitch)
                    row(SpatialKeymap.rows[1] + ";'", pitch: pitch)
                    key("return", "↵", 2.25, pitch)
                }
                HStack(spacing: gap) {
                    key("shiftLeft", "⇧", 2.25, pitch)
                    row(SpatialKeymap.rows[2] + ",./", pitch: pitch)
                    key("shiftRight", "⇧", 2.75, pitch)
                }
                HStack(spacing: gap) {
                    key("fn", "fn", 1, pitch)
                    key("control", "⌃", 1, pitch)
                    key("option", "⌥", 1.25, pitch)
                    key("command", "⌘", 1.5, pitch)
                    key(" ", "", 5, pitch)
                    key("commandRight", "⌘", 1.25, pitch)
                    key("optionRight", "⌥", 1, pitch)
                    key("left", "←", 1, pitch, half: true)
                        .frame(height: height, alignment: .bottom)
                    VStack(spacing: 2) {
                        key("up", "↑", 1, pitch, half: true)
                        key("down", "↓", 1, pitch, half: true)
                    }
                    key("right", "→", 1, pitch, half: true)
                        .frame(height: height, alignment: .bottom)
                }
            }
        }
        .frame(height: height * 5 + 12)
        .padding(7)
        .background(Color(white: 0.10), in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(.white.opacity(0.10)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(pressed.isEmpty ? "Preview keyboard" : "Preview keyboard · " + pressed.sorted().joined(separator: " ") + " pressed")
        .accessibilityValue(pressed.isEmpty ? "Jump keys: " + String(letters) : "Pressed: " + pressed.sorted().joined(separator: " "))
    }

    static let modifierMasks: [UInt16: NSEvent.ModifierFlags] = [
        56: .init(rawValue: UInt(NX_DEVICELSHIFTKEYMASK)), 60: .init(rawValue: UInt(NX_DEVICERSHIFTKEYMASK)),
        55: .init(rawValue: UInt(NX_DEVICELCMDKEYMASK)), 54: .init(rawValue: UInt(NX_DEVICERCMDKEYMASK)),
        58: .init(rawValue: UInt(NX_DEVICELALTKEYMASK)), 61: .init(rawValue: UInt(NX_DEVICERALTKEYMASK)),
        59: .init(rawValue: UInt(NX_DEVICELCTLKEYMASK)), 57: .capsLock, 63: .function
    ]

    // ANSI positions stay fixed even if Shift or Option changes the generated character.
    static let keyIDs: [UInt16: String] = [
        50:"`", 18:"1", 19:"2", 20:"3", 21:"4", 23:"5", 22:"6", 26:"7", 28:"8", 25:"9", 29:"0", 27:"-", 24:"=", 51:"delete",
        48:"tab", 12:"q", 13:"w", 14:"e", 15:"r", 17:"t", 16:"y", 32:"u", 34:"i", 31:"o", 35:"p", 33:"[", 30:"]", 42:"\\",
        57:"caps", 0:"a", 1:"s", 2:"d", 3:"f", 5:"g", 4:"h", 38:"j", 40:"k", 37:"l", 41:";", 39:"'", 36:"return",
        56:"shiftLeft", 6:"z", 7:"x", 8:"c", 9:"v", 11:"b", 45:"n", 46:"m", 43:",", 47:".", 44:"/", 60:"shiftRight",
        63:"fn", 59:"control", 58:"option", 55:"command", 49:" ", 54:"commandRight", 61:"optionRight",
        123:"left", 126:"up", 125:"down", 124:"right"
    ]
}
