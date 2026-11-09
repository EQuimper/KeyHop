import SwiftUI

struct PreviewScroll {
    static let bounds = CGRect(x: 0, y: 0, width: 300, height: 150)
    static let panels = [CGRect(x: 0, y: 0, width: 146, height: 150), CGRect(x: 154, y: 0, width: 146, height: 150)]
    static let content = CGSize(width: 340, height: 720)
    var navigation: ScrollNavigation
    private(set) var offsets = [CGPoint.zero, CGPoint.zero]
    private var repeatKey: UInt16?

    init(letters: [Character], spatial: Bool) {
        navigation = ScrollNavigation(rects: Self.panels, bounds: Self.bounds, letters: letters, spatial: spatial)
    }

    mutating func handle(key: UInt16, text: String, repeating: Bool) {
        if key == 48 { navigation.choosePanel(); repeatKey = nil; return }
        guard let selected = navigation.selected else {
            repeatKey = nil
            if !repeating { navigation.type(key: key, text: text) }
            return
        }
        guard !repeating || repeatKey == key else { return }
        let command = navigation.command(key: key, text: text, repeating: repeating)
        repeatKey = command?.isRepeatable == true ? key : nil
        guard let command else { return }
        if command == .top { offsets[selected].y = 0; return }
        if command == .bottom { offsets[selected].y = Self.content.height - Self.panels[selected].height; return }
        let size = Self.panels[selected].size
        guard let delta = command.offset(in: size) else { return }
        let previous = offsets[selected]
        offsets[selected] = CGPoint(x: min(Self.content.width - size.width, max(0, previous.x + delta.x)),
                                    y: min(Self.content.height - size.height, max(0, previous.y + delta.y)))
    }
}

struct ScrollPreviewContent: View {
    let state: PreviewScroll
    let fill: Color
    private let sections = ["Folders", "Documents"]
    private let titles = ["Keyboard shortcuts", "Project notes", "Reading list", "Design references", "Weekly review", "Ideas to explore"]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<2) { panel in
                GeometryReader { geometry in
                    let selected = state.navigation.selected == panel
                    let offset = state.offsets[panel]
                    ZStack(alignment: .topLeading) {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(0..<24) { row in
                                HStack(spacing: 8) {
                                    Image(systemName: panel == 0 ? "folder" : "doc.text")
                                        .foregroundStyle(.white.opacity(0.45))
                                    Text(String(format: "%02d", row + 1) + "  " + titles[row % titles.count])
                                        .font(.system(size: 11)).lineLimit(1)
                                }.frame(height: 30)
                            }
                        }
                        .frame(width: PreviewScroll.content.width, height: PreviewScroll.content.height, alignment: .topLeading)
                        .offset(x: -offset.x, y: -offset.y)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
                    .clipped()
                    .overlay(alignment: .topTrailing) {
                        if state.navigation.selected == nil {
                            let label = state.navigation.labels[panel]
                            if label.hasPrefix(state.navigation.prefix) {
                                Text(String(label.dropFirst(state.navigation.prefix.count)))
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Color(nsColor: LabelColor.ink(on: NSColor(fill))))
                                    .padding(.horizontal, 5).padding(.vertical, 2)
                                    .background(fill, in: RoundedRectangle(cornerRadius: 3))
                                    .padding(5)
                            }
                        }
                    }
                    .overlay(alignment: .trailing) {
                        if selected {
                            Capsule().fill(fill).frame(width: 3, height: 24)
                                .offset(y: (offset.y / (PreviewScroll.content.height - PreviewScroll.panels[panel].height) - 0.5) * (geometry.size.height - 30))
                                .padding(.trailing, 2)
                        }
                    }
                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(selected ? fill.opacity(0.8) : .white.opacity(0.1)))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(sections[panel]) scroll preview")
                    .accessibilityValue("\(selected ? "Selected" : "Unselected"), horizontal \(Int(offset.x)), vertical \(Int(offset.y))")
                }
                .frame(maxWidth: .infinity)
            }
        }.frame(height: 150).padding(7)
    }
}
