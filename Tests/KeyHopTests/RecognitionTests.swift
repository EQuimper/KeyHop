import AppKit
import CoreText
import XCTest
@testable import KeyHop

final class RecognitionTests: XCTestCase {
    func testRecognizedEdgesSelectLookGoodWithoutItsNeighboringSpaces() throws {
        let text = "These words look good today"
        let attributed = NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: 14), .foregroundColor: NSColor.black
        ])
        let line = CTLineCreateWithAttributedString(attributed)
        let bounds = CGRect(x: 0, y: 0, width: 260, height: 60)
        let context = try XCTUnwrap(CGContext(data: nil, width: 520, height: 120, bitsPerComponent: 8,
                                              bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        context.scaleBy(x: 2, y: 2)
        context.setFillColor(NSColor.white.cgColor)
        context.fill(bounds)
        let origin = CGPoint(x: 20, y: 25)
        context.textPosition = origin
        CTLineDraw(line, context)
        let words = try WindowTarget.recognizeWords(image: XCTUnwrap(context.makeImage()), in: bounds)
        let start = try XCTUnwrap(words.first { $0.title == "look" })
        let end = try XCTUnwrap(words.first { $0.title == "good" })
        let (from, to) = Hints.drag(from: start, to: end, forward: true)
        let first = CTLineGetStringIndexForPosition(line, CGPoint(x: from.x - origin.x, y: 0))
        let last = CTLineGetStringIndexForPosition(line, CGPoint(x: to.x - origin.x, y: 0))
        XCTAssertEqual(NSRange(location: first, length: last - first), (text as NSString).range(of: "look good"))
    }

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
