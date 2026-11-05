import XCTest
@testable import KeyHop

final class HintLayoutTests: XCTestCase {
    func testCloselySpacedSidebarLabelsStayReadable() throws {
        let bounds = CGRect(x: 0, y: 0, width: 450, height: 300)
        let badge = CGRect(x: 80, y: 258, width: 300, height: 28)
        let anchors = (0..<14).map { i in
            HintAnchor(target: CGRect(x: 0, y: 50 + i * 5, width: 14, height: 5),
                       size: CGSize(width: 25, height: 19))
        }
        let frames = try HintLayout.frames(for: anchors, in: bounds, avoiding: badge).map { try XCTUnwrap($0) }
        for (index, frame) in frames.enumerated() {
            XCTAssertTrue(bounds.contains(frame))
            XCTAssertFalse(frame.intersects(badge))
            for other in frames.dropFirst(index + 1) {
                XCTAssertFalse(frame.insetBy(dx: -2, dy: -2).intersects(other))
            }
        }
    }

    func testWindowCornersAndStatusBadge() throws {
        let bounds = CGRect(x: 0, y: 0, width: 270, height: 150)
        let badge = CGRect(x: 55, y: 108, width: 150, height: 28)
        let anchors = [CGPoint(x: 269,y: 149), CGPoint(x: 0,y: 0), CGPoint(x: 120,y: 123)].map {
            HintAnchor(target: CGRect(origin: $0, size: CGSize(width: 4, height: 4)), size: CGSize(width: 25, height: 19))
        }
        for frame in HintLayout.frames(for: anchors, in: bounds, avoiding: badge) {
            let frame = try XCTUnwrap(frame)
            XCTAssertTrue(bounds.contains(frame))
            XCTAssertFalse(badge.intersects(frame))
        }
    }
}
