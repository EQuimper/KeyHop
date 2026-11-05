import AppKit
import XCTest
@testable import KeyHop

final class RecognitionTests: XCTestCase {
    func testVisibleWordsHaveDistinctPositionsInWindowCoordinates() throws {
        let image = NSImage(size: CGSize(width: 500, height: 90), flipped: false) { bounds in
            NSColor.white.setFill()
            bounds.fill()
            ("Select these words" as NSString).draw(at: CGPoint(x: 25, y: 30), withAttributes: [
                .font: NSFont.systemFont(ofSize: 30), .foregroundColor: NSColor.black
            ])
            return true
        }
        let bitmap = try XCTUnwrap(image.cgImage(forProposedRect: nil, context: nil, hints: nil))
        let window = CGRect(x: -250, y: 200, width: 500, height: 90)
        let words = try WindowTarget.recognizeWords(image: bitmap, in: window)
        XCTAssertEqual(words.map(\.title), ["Select", "these", "words"])
        XCTAssertTrue(words.allSatisfy { window.contains($0.rect) })
        for (left, right) in zip(words, words.dropFirst()) {
            XCTAssertLessThan(left.rect.maxX, right.rect.minX)
        }
    }
}
