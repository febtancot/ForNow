import XCTest
@testable import ForNowKit

final class DraftTextMetricsTests: XCTestCase {
    @MainActor
    func testEmptyTextIsOneLine() {
        let h = DraftTextMetrics.height(for: "", width: 324)
        XCTAssertEqual(h, DraftTextMetrics.lineHeight)
    }

    @MainActor
    func testShortTextWraps() {
        let h = DraftTextMetrics.height(for: "hello world", width: 30)
        let lines = Int((h / DraftTextMetrics.lineHeight).rounded())
        XCTAssertGreaterThan(lines, 1, "窄宽度下短文本应换行")
    }

    @MainActor
    func testLineCountCappedAtEight() {
        let long = String(repeating: "word ", count: 10_000)
        XCTAssertEqual(DraftTextMetrics.lineCount(for: long, width: 60), 8)
    }

    @MainActor
    func testHugeTextIsBounded() {
        let huge = String(repeating: "这是一段很长的文字。", count: 100_000)
        let h = DraftTextMetrics.height(for: huge, width: 324)
        XCTAssertEqual(h, DraftTextMetrics.lineHeight * 8)
    }

    @MainActor
    func testUnbrokenTextWrapsAccordingToAvailableWidth() {
        let unbroken = String(repeating: "W", count: 30)
        let narrow = DraftTextMetrics.lineCount(for: unbroken, width: 80)
        let wide = DraftTextMetrics.lineCount(for: unbroken, width: 500)

        XCTAssertGreaterThan(narrow, wide, "无空格长串应按可用宽度折行")
        XCTAssertEqual(wide, 1)
    }

    @MainActor
    func testUnbrokenTextIsCappedAtEightVisibleLines() {
        let unbroken = String(repeating: "W", count: 10_000)
        XCTAssertEqual(DraftTextMetrics.lineCount(for: unbroken, width: 80), 8)
        XCTAssertEqual(
            DraftTextMetrics.height(for: unbroken, width: 80),
            DraftTextMetrics.lineHeight * 8
        )
    }
}
