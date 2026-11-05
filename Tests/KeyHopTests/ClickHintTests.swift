import XCTest
@testable import KeyHop

final class ClickHintTests: XCTestCase {
    func testDenseMarkersShareOneKeyInVisualOrder() throws {
        var rects = (0..<14).reversed().map { CGRect(x: 78, y: 457 + $0 * 10, width: 36, height: 10) }
        rects.append(CGRect(x: 18, y: 467, width: 36, height: 36))
        rects.append(CGRect(x: 78, y: 690, width: 36, height: 10))
        let hints = ClickHint.make(rects: rects, candidates: Array(rects.indices), groupMarkers: true)
        XCTAssertEqual(hints.count, 3)
        XCTAssertEqual(hints.first { $0.label == "g" }?.members, Array((0..<14).reversed()))
        XCTAssertEqual(hints.flatMap(\.members).sorted(), Array(rects.indices))
        XCTAssertEqual(ClickHint.make(rects: rects, candidates: Array(rects.indices), groupMarkers: false).count, rects.count)
    }

    func testGroupsAndIndividualKeysArePrefixFreeAcrossBusyWindows() {
        let rects = (0..<150).map { i in CGRect(x: (i / 3) * 40, y: (i % 3) * 10, width: 10, height: 10) }
            + (0..<65).map { i in CGRect(x: i * 36, y: 500, width: 32, height: 32) }
        let hints = ClickHint.make(rects: rects, candidates: Array(rects.indices), groupMarkers: true)
        XCTAssertEqual(hints.count, 115)
        XCTAssertEqual(Set(hints.map(\.label)).count, hints.count)
        for a in hints {
            XCTAssertFalse(hints.contains { $0.label != a.label && $0.label.hasPrefix(a.label) })
        }
    }
}
