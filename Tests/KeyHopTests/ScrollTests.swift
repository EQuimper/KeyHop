import AppKit
import XCTest
@testable import KeyHop

final class ScrollTests: XCTestCase {
    func testDocumentBoundaryJumpsDoNotUseWheelDistances() {
        XCTAssertNil(ScrollCommand.top.offset(in: CGSize(width: 600, height: 800)), "Firefox caps even enormous wheel deltas to roughly one page")
        XCTAssertNil(ScrollCommand.bottom.offset(in: CGSize(width: 600, height: 800)))
    }

    func testBoundaryKeysAreUnmodifiedHomeAndEndPairs() {
        for (command, key) in [(ScrollCommand.top, Int64(115)), (.bottom, Int64(119))] {
            let events = ScrollBoundary.keyEvents(for: command)
            XCTAssertEqual(events.count, 2)
            XCTAssertEqual(events.map(\.type), [.keyDown, .keyUp])
            for event in events {
                XCTAssertEqual(event.getIntegerValueField(.keyboardEventKeycode), key)
                XCTAssertTrue(event.flags.isEmpty, "Shift-G must not select document text")
            }
        }
        XCTAssertTrue(ScrollBoundary.keyEvents(for: .down).isEmpty)
    }

    func testSinglePanelStartsImmediatelyAndTabReturnsToLabels() {
        let rect = CGRect(x: 0, y: 0, width: 600, height: 400)
        var navigation = ScrollNavigation(rects: [rect], bounds: rect, letters: ["a", "s"], spatial: false)
        XCTAssertEqual(navigation.selected, 0)
        navigation.choosePanel()
        XCTAssertNil(navigation.selected)
        navigation.type(key: 0, text: "a")
        XCTAssertEqual(navigation.selected, 0)
    }

    func testMultiplePanelsRequireCompleteLabelsAndSupportBackspace() {
        let rects = (0..<5).map { CGRect(x: $0 * 50, y: 0, width: 45, height: 100) }
        var navigation = ScrollNavigation(rects: rects, bounds: CGRect(x: 0, y: 0, width: 250, height: 100), letters: ["a", "s"], spatial: false)
        XCTAssertNil(navigation.selected)
        navigation.type(key: 0, text: "a")
        XCTAssertEqual(navigation.prefix, "a")
        XCTAssertNil(navigation.selected)
        navigation.type(key: 51, text: "")
        XCTAssertEqual(navigation.prefix, "")
        for letter in navigation.labels[3] { navigation.type(key: 0, text: String(letter)) }
        XCTAssertEqual(navigation.selected, 3)
    }

    func testScrollDirectionsAndHalfPagesUseTheViewport() {
        let viewport = CGSize(width: 500, height: 600)
        XCTAssertEqual(ScrollCommand(key: 0, text: "j")?.offset(in: viewport), CGPoint(x: 0, y: 40))
        XCTAssertEqual(ScrollCommand(key: 126, text: "")?.offset(in: viewport), CGPoint(x: 0, y: -40))
        XCTAssertEqual(ScrollCommand(key: 0, text: "h")?.offset(in: viewport), CGPoint(x: -40, y: 0))
        XCTAssertEqual(ScrollCommand(key: 124, text: "")?.offset(in: viewport), CGPoint(x: 40, y: 0))
        XCTAssertEqual(ScrollCommand(key: 0, text: "d")?.offset(in: viewport)?.y, 300)
        XCTAssertEqual(ScrollCommand(key: 0, text: "u")?.offset(in: viewport)?.y, -300)
        XCTAssertNil(ScrollCommand(key: 0, text: "z"))
    }

    func testPreviewScrollsOnlyTheChosenPanelAndClampsBothAxes() {
        var preview = PreviewScroll(letters: ["j", "k"], spatial: false)
        preview.handle(key: 38, text: "j", repeating: false)
        XCTAssertEqual(preview.navigation.selected, 0)
        preview.handle(key: 38, text: "j", repeating: true)
        XCTAssertEqual(preview.offsets[0], .zero, "Holding a label must not start scrolling")
        preview.handle(key: 38, text: "j", repeating: false)
        preview.handle(key: 38, text: "j", repeating: true)
        XCTAssertEqual(preview.offsets[0].y, 80)
        XCTAssertEqual(preview.offsets[1], .zero)
        for _ in 0..<40 { preview.handle(key: 0, text: "d", repeating: false) }
        XCTAssertEqual(preview.offsets[0].y, PreviewScroll.content.height - PreviewScroll.panels[0].height)
        for _ in 0..<40 { preview.handle(key: 0, text: "u", repeating: false) }
        XCTAssertEqual(preview.offsets[0].y, 0)
        preview.handle(key: 48, text: "", repeating: false)
        preview.handle(key: 40, text: "k", repeating: false)
        preview.handle(key: 37, text: "l", repeating: false)
        XCTAssertEqual(preview.offsets[1].x, 40)
        XCTAssertEqual(preview.offsets[0].x, 0)
    }

    func testVimEndsRequireTwoDistinctGPressesAndPreserveHorizontalPosition() {
        var preview = PreviewScroll(letters: ["a", "s"], spatial: false)
        preview.handle(key: 0, text: "a", repeating: false)
        preview.handle(key: 37, text: "l", repeating: false)
        preview.handle(key: 2, text: "d", repeating: false)
        preview.handle(key: 5, text: "g", repeating: false)
        XCTAssertTrue(preview.navigation.pendingTop)
        XCTAssertEqual(preview.offsets[0].y, 75)
        preview.handle(key: 5, text: "g", repeating: true)
        XCTAssertEqual(preview.offsets[0].y, 75, "Holding g is not gg")
        preview.handle(key: 5, text: "g", repeating: false)
        XCTAssertEqual(preview.offsets[0], CGPoint(x: 40, y: 0))
        XCTAssertFalse(preview.navigation.pendingTop)
        preview.handle(key: 5, text: "G", repeating: false)
        XCTAssertEqual(preview.offsets[0], CGPoint(x: 40, y: 570))
        XCTAssertEqual(preview.offsets[1], .zero)
    }

    func testPendingGIsCancelledByAnotherCommandOrPanelChange() {
        var preview = PreviewScroll(letters: ["g", "j"], spatial: false)
        preview.handle(key: 5, text: "g", repeating: false)
        XCTAssertEqual(preview.navigation.selected, 0)
        XCTAssertFalse(preview.navigation.pendingTop, "A panel label is not the first g of gg")
        preview.handle(key: 5, text: "g", repeating: false)
        preview.handle(key: 38, text: "j", repeating: false)
        XCTAssertFalse(preview.navigation.pendingTop)
        preview.handle(key: 5, text: "g", repeating: false)
        XCTAssertEqual(preview.offsets[0].y, 40)
        preview.handle(key: 48, text: "", repeating: false)
        XCTAssertFalse(preview.navigation.pendingTop)
        preview.handle(key: 38, text: "j", repeating: false)
        preview.handle(key: 5, text: "G", repeating: false)
        XCTAssertEqual(preview.offsets[1].y, 570)
        XCTAssertEqual(preview.offsets[0].y, 40)
    }

    func testHeldScrollKeyNeverLeaksRepeatsOrKeyUpAfterModeEnds() throws {
        let keyboard = Keyboard()
        var active = true, calls = 0
        keyboard.repeatAllowed = { _, _ in active }
        keyboard.consume = { _, _, _ in calls += 1; return active }
        let event = try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: 38, keyDown: true))
        XCTAssertTrue(keyboard.consumeKey(event, type: .keyDown))
        event.setIntegerValueField(.keyboardEventAutorepeat, value: 1)
        XCTAssertTrue(keyboard.consumeKey(event, type: .keyDown))
        XCTAssertEqual(calls, 2)
        active = false
        XCTAssertTrue(keyboard.consumeKey(event, type: .keyDown))
        XCTAssertTrue(keyboard.consumeKey(event, type: .keyUp))
        event.setIntegerValueField(.keyboardEventAutorepeat, value: 0)
        XCTAssertFalse(keyboard.consumeKey(event, type: .keyDown))
        XCTAssertFalse(keyboard.consumeKey(event, type: .keyUp))
    }

    func testPanelSelectionDoesNotEnableRepeatsForTheSameHeldKey() throws {
        let keyboard = Keyboard()
        var selected = false, calls = 0
        keyboard.repeatAllowed = { _, _ in selected }
        keyboard.consume = { _, _, _ in selected = true; calls += 1; return true }
        let event = try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: 38, keyDown: true))
        XCTAssertTrue(keyboard.consumeKey(event, type: .keyDown))
        event.setIntegerValueField(.keyboardEventAutorepeat, value: 1)
        XCTAssertTrue(keyboard.consumeKey(event, type: .keyDown))
        XCTAssertEqual(calls, 1)
        XCTAssertTrue(keyboard.consumeKey(event, type: .keyUp))
    }
}
