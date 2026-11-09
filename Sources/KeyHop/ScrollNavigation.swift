import Foundation

/// Positive offsets move toward the end of the document, independent of mouse preferences.
enum ScrollCommand: Equatable {
    case up, down, left, right, pageUp, pageDown, top, bottom

    var isRepeatable: Bool { self != .top && self != .bottom }

    init?(key: UInt16, text: String) {
        if text == "G" { self = .bottom; return }
        switch key {
        case 126: self = .up
        case 125: self = .down
        case 123: self = .left
        case 124: self = .right
        default:
            switch text.lowercased() {
            case "k": self = .up
            case "j": self = .down
            case "h": self = .left
            case "l": self = .right
            case "u": self = .pageUp
            case "d": self = .pageDown
            default: return nil
            }
        }
    }

    func offset(in viewport: CGSize) -> CGPoint? {
        switch self {
        case .up: return CGPoint(x: 0, y: -40)
        case .down: return CGPoint(x: 0, y: 40)
        case .left: return CGPoint(x: -40, y: 0)
        case .right: return CGPoint(x: 40, y: 0)
        case .pageUp: return CGPoint(x: 0, y: -viewport.height / 2)
        case .pageDown: return CGPoint(x: 0, y: viewport.height / 2)
        case .top, .bottom: return nil
        }
    }
}

struct ScrollNavigation {
    private(set) var selected: Int?
    private(set) var prefix = ""
    private(set) var pendingTop = false
    let labels: [String]

    init(rects: [CGRect], bounds: CGRect, letters: [Character], spatial: Bool) {
        labels = spatial ? SpatialKeymap.labels(points: rects.map { CGPoint(x: $0.midX, y: $0.midY) }, bounds: bounds)
                         : Hints.labels(count: rects.count, alphabet: letters)
        selected = rects.count == 1 ? 0 : nil
    }

    mutating func choosePanel() { selected = nil; prefix = ""; pendingTop = false }

    mutating func command(key: UInt16, text: String, repeating: Bool) -> ScrollCommand? {
        guard selected != nil else { return nil }
        if text == "g" {
            guard !repeating else { return nil }
            if pendingTop { pendingTop = false; return .top }
            pendingTop = true
            return nil
        }
        pendingTop = false
        guard let command = ScrollCommand(key: key, text: text), !repeating || command.isRepeatable else { return nil }
        return command
    }

    mutating func type(key: UInt16, text: String) {
        guard selected == nil else { return }
        if key == 51 { prefix = String(prefix.dropLast()); return }
        let input = prefix + text.lowercased()
        guard text.count == 1 else { return }
        if let index = labels.firstIndex(of: input) { selected = index; prefix = "" }
        else { prefix = labels.contains { $0.hasPrefix(input) } ? input : "" }
    }
}
