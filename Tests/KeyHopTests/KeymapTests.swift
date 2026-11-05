import XCTest
@testable import KeyHop

final class KeymapTests: XCTestCase {
    func testCustomLettersAreValidatedAndPersistInOrder() throws {
        let suite = "KeyHopTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertEqual(Keymap.validated(" LAks "), "laks")
        for invalid in ["", "l", "ll", "a1", "a b"] { XCTAssertNil(Keymap.validated(invalid)) }
        defaults.set(Keymap.custom.rawValue, forKey: Keymap.choiceKey)
        defaults.set("laks", forKey: Keymap.customKey)
        XCTAssertEqual(Keymap.letters(in: defaults), Array("laks"))
    }

    func testMinimalKeymapCoversGroupsAndButtonsWithoutPrefixConflicts() {
        let rects = (0..<15).map { i in CGRect(x: (i / 3) * 40, y: (i % 3) * 10, width: 10, height: 10) }
            + [CGRect(x: 0, y: 100, width: 50, height: 30)]
        let hints = ClickHint.make(rects: rects, candidates: Array(rects.indices), groupMarkers: true, letters: ["a","s"])
        XCTAssertEqual(hints.flatMap(\.members).sorted(), Array(rects.indices))
        XCTAssertEqual(Set(hints.map(\.label)).count, hints.count)
        for hint in hints {
            XCTAssertTrue(hint.label.allSatisfy { $0 == "a" || $0 == "s" })
            XCTAssertFalse(hints.contains { $0.label != hint.label && $0.label.hasPrefix(hint.label) })
        }
    }
}
