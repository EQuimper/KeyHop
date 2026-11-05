import XCTest
@testable import KeyHop

final class HintsTests: XCTestCase {
    func testLabelsAreUniqueAndPrefixFreeWhenOverflowingOneAndTwoKeys() {
        for count in [0, 1, 26, 27, 676, 700] {
            let labels = Hints.labels(count: count)
            XCTAssertEqual(Set(labels).count, count)
            XCTAssertLessThanOrEqual(Set(labels.map(\.count)).count, 1)
        }
    }

    func testSelectionIncludesBothWordsInBothDirections() {
        let a = Target(title: "first", rect: CGRect(x: 10, y: 20, width: 30, height: 10))
        let b = Target(title: "last", rect: CGRect(x: 50, y: 40, width: 20, height: 10))
        let (start, end) = Hints.drag(from: a, to: b, forward: true)
        let (reverseStart, reverseEnd) = Hints.drag(from: b, to: a, forward: false)
        XCTAssertEqual(start, CGPoint(x: 11, y: 25))
        XCTAssertEqual(end, CGPoint(x: 69, y: 45))
        XCTAssertEqual(reverseStart, end)
        XCTAssertEqual(reverseEnd, start)
    }
}
