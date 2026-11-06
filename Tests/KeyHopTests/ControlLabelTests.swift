import XCTest
@testable import KeyHop

final class ControlLabelTests: XCTestCase {
    func testFinderItemsAreTargetsWhileDecorativeImagesAndContainersAreSkipped() {
        XCTAssertTrue(ControlLabel.isTarget(role: "AXImage", actions: ["AXOpen", "AXShowMenu"]))
        XCTAssertTrue(ControlLabel.isTarget(role: "AXCell", actions: ["AXOpen"]))
        XCTAssertTrue(ControlLabel.isTarget(role: "AXTextField", actions: ["AXOpen", "AXConfirm"]))
        XCTAssertTrue(ControlLabel.isTarget(role: "AXStaticText", actions: ["AXPress"]))
        XCTAssertFalse(ControlLabel.isTarget(role: "AXImage", actions: []))
        XCTAssertFalse(ControlLabel.isTarget(role: "AXCell", actions: []))
        XCTAssertFalse(ControlLabel.isTarget(role: "AXList", actions: ["AXShowMenu"]))
        XCTAssertTrue(ControlLabel.isTarget(role: "AXButton", actions: []))
    }

    func testFinderValueProvidesAUsableFilenameAcrossViews() {
        XCTAssertEqual(ControlLabel.text(title: "", description: "", itemName: "Example.txt", fallback: "AXTextField"), "Example.txt")
        XCTAssertEqual(ControlLabel.text(title: nil, description: "Example.txt", itemName: nil, fallback: "AXImage"), "Example.txt")
        XCTAssertEqual(ControlLabel.text(title: "Search", description: "Search field", itemName: nil, fallback: "AXTextField"), "Search")
    }
}
