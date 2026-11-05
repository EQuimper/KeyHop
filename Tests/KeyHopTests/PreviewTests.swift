import XCTest
@testable import KeyHop

final class PreviewTests: XCTestCase {
    func testSpatialLabelsCoverCornersAndDisambiguateUsingScreenOrder() {
        let bounds = CGRect(x: -800, y: 300, width: 1000, height: 600)
        let local = [CGPoint(x: 25,y: 65), CGPoint(x: 15,y: 20), CGPoint(x: 990,y: 30),
                     CGPoint(x: 20,y: 300), CGPoint(x: 990,y: 320), CGPoint(x: 10,y: 590), CGPoint(x: 990,y: 590)]
        let points = local.map { CGPoint(x: bounds.minX + $0.x, y: bounds.minY + $0.y) }
        XCTAssertEqual(SpatialKeymap.labels(points: points, bounds: bounds), ["qw","qq","p","a","l","z","m"])
    }

    func testPreviewSupportsBackwardsSelectionsAndEmptySearches() {
        var selection = PreviewSelection()
        selection.edit("keyboard")
        selection.choose(selection.current!)
        selection.edit("missing")
        XCTAssertNil(selection.range)
        selection.edit("both")
        selection.choose(selection.current!)
        XCTAssertTrue(selection.finished)
        XCTAssertEqual(selection.range, 1...5)
        selection.edit("keep")
        XCTAssertFalse(selection.finished)
        XCTAssertNil(selection.anchor)
    }
}
