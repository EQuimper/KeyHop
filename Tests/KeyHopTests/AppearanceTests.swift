import XCTest
@testable import KeyHop

final class AppearanceTests: XCTestCase {
    func testPrefixOnlyShowsRemainingKeysAndKeepsGroupMarker() {
        let tag = Tag(label: "jfk ›", rect: .zero, prefix: "j")
        XCTAssertTrue(tag.visible)
        XCTAssertEqual(tag.text, "fk ›")
        XCTAssertEqual(Tag(label: "jfk ›", rect: .zero, prefix: "jf").text, "k ›")
        XCTAssertFalse(Tag(label: "fk", rect: .zero, prefix: "j").visible)
        XCTAssertEqual(Tag(label: "jf", rect: .zero).text, "jf")
    }

    func testColorPersistsAndTextContrasts() throws {
        let suite = "KeyHopTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertEqual(LabelColor.load(from: defaults), LabelColor.original)
        LabelColor.save(.init(srgbRed: 0.1, green: 0.2, blue: 0.3, alpha: 1), to: defaults)
        let restored = LabelColor.load(from: try XCTUnwrap(UserDefaults(suiteName: suite)))
        XCTAssertEqual(restored.greenComponent, 0.2, accuracy: 0.001)
        XCTAssertEqual(LabelColor.ink(on: restored), .white)
        XCTAssertEqual(LabelColor.ink(on: LabelColor.original), .black)
    }
}
