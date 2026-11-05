import Foundation

enum Keymap: String, CaseIterable {
    case qwerty = "QWERTY"
    case standard = "Standard"
    case homeRow = "Home row"
    case custom = "Custom"

    static let customKey = "customHintLetters"
    static let choiceKey = "hintKeymap"

    static func validated(_ input: String) -> String? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard (2...26).contains(text.utf8.count), text.utf8.allSatisfy({ (97...122).contains($0) }),
              Set(text).count == text.count else { return nil }
        return text
    }

    static func letters(in defaults: UserDefaults = .standard) -> [Character] {
        let choice = Keymap(rawValue: defaults.string(forKey: choiceKey) ?? "") ?? .standard
        return choice.letters(custom: defaults.string(forKey: customKey) ?? "")
    }

    func letters(custom: String, fallback: String? = nil) -> [Character] {
        switch self {
        case .qwerty: return Array(SpatialKeymap.rows.joined())
        case .standard: return Hints.alphabet
        case .homeRow: return Array("asdfghjkl")
        case .custom:
            return Array(Self.validated(custom) ?? fallback.flatMap(Self.validated) ?? String(Hints.alphabet))
        }
    }
}
