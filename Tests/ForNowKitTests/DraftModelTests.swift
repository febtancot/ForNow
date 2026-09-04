import XCTest
import Combine
@testable import ForNowKit

final class DraftModelTests: XCTestCase {
    @MainActor
    func testDraftDidChangeCoalescesRapidUpdates() async throws {
        let model = DraftModel()
        var count = 0
        let cancellable = model.draftDidChange.sink { count += 1 }

        for i in 0..<100 {
            model.draft += "x"
            _ = i
        }
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertGreaterThan(count, 0, "至少应发送一次变化事件")
        XCTAssertEqual(count, 1, "同一次运行循环内的连续变化应合并为一次事件")
        cancellable.cancel()
    }

    @MainActor
    func testIdenticalValueDoesNotEmit() async throws {
        let model = DraftModel()
        var count = 0
        let cancellable = model.draftDidChange.sink { count += 1 }

        model.draft = "hello"
        model.draft = "hello"
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(count, 1, "相同值不应触发事件")
        cancellable.cancel()
    }

    @MainActor
    func testClearDraftResetsHeightDespiteThrottle() async throws {
        let model = DraftModel()
        // 塞满 8 行（节流测量一次）。
        model.draft = String(repeating: "这是一段很长的文字。", count: 1000)
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(model.fieldContentHeight, DraftTextMetrics.lineHeight * 8)

        // 1 秒节流内清空：最终状态必须立即归位单行，不能被节流吞掉。
        model.draft = ""
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(model.fieldContentHeight, DraftTextMetrics.lineHeight,
                       "清空草稿后高度应立即复位为单行")
    }

    @MainActor
    func testEmitHappensAfterMeasure() async throws {
        let model = DraftModel()
        let expectation = XCTestExpectation(description: "事件在测量之后到达")
        let cancellable = model.draftDidChange.sink {
            // 收到事件时高度必须已是当前草稿的最新值。
            XCTAssertEqual(model.fieldContentHeight, DraftTextMetrics.lineHeight)
            expectation.fulfill()
        }
        model.draft = "单行文本"
        await fulfillment(of: [expectation], timeout: 1)
        cancellable.cancel()
    }

    @MainActor
    func testAvailableWidthChangeRemeasuresExistingDraft() async throws {
        let model = DraftModel(minimumMeasurementInterval: 0.5)
        let text = String(repeating: "W", count: 30)

        let initialLayout = XCTestExpectation(description: "initial layout")
        var cancellable = model.draftDidChange.prefix(1).sink { initialLayout.fulfill() }
        model.setFieldAvailableWidth(500)
        model.draft = text
        await fulfillment(of: [initialLayout], timeout: 1)
        let wideHeight = model.fieldContentHeight

        let narrowLayout = XCTestExpectation(description: "narrow layout")
        cancellable = model.draftDidChange.prefix(1).sink { narrowLayout.fulfill() }
        model.setFieldAvailableWidth(80)
        await Task.yield()
        XCTAssertEqual(model.fieldContentHeight, wideHeight, "连续宽度变化应先合并到尾沿")
        await fulfillment(of: [narrowLayout], timeout: 1)
        XCTAssertGreaterThan(model.fieldContentHeight, wideHeight)
        XCTAssertEqual(
            model.fieldContentHeight,
            DraftTextMetrics.height(for: text, width: 80)
        )

        let wideLayout = XCTestExpectation(description: "wide layout")
        cancellable = model.draftDidChange.prefix(1).sink { wideLayout.fulfill() }
        model.setFieldAvailableWidth(500)
        await fulfillment(of: [wideLayout], timeout: 1)
        XCTAssertEqual(model.fieldContentHeight, wideHeight)
        cancellable.cancel()
    }

    @MainActor
    func testInvalidTransientWidthsDoNotCollapseWrappedDraft() async throws {
        let model = DraftModel()
        let initialLayout = XCTestExpectation(description: "wrapped layout")
        let cancellable = model.draftDidChange.prefix(1).sink { initialLayout.fulfill() }
        model.setFieldAvailableWidth(80)
        model.draft = String(repeating: "W", count: 30)
        await fulfillment(of: [initialLayout], timeout: 1)
        let wrappedHeight = model.fieldContentHeight

        for width in [CGFloat.zero, -1, .nan, .infinity] {
            model.setFieldAvailableWidth(width)
        }
        await Task.yield()

        XCTAssertGreaterThan(wrappedHeight, DraftTextMetrics.lineHeight)
        XCTAssertEqual(model.fieldContentHeight, wrappedHeight)
        cancellable.cancel()
    }

    @MainActor
    func testRapidTextChangeGetsTrailingHeightMeasurement() async throws {
        let model = DraftModel(minimumMeasurementInterval: 0.5)
        let initialLayout = XCTestExpectation(description: "initial single-line layout")
        var cancellable = model.draftDidChange.prefix(1).sink { initialLayout.fulfill() }
        model.setFieldAvailableWidth(80)
        model.draft = "A"
        await fulfillment(of: [initialLayout], timeout: 1)
        XCTAssertEqual(model.fieldContentHeight, DraftTextMetrics.lineHeight)

        let wrapped = String(repeating: "W", count: 30)
        let trailingLayout = XCTestExpectation(description: "trailing wrapped layout")
        cancellable = model.draftDidChange.prefix(1).sink { trailingLayout.fulfill() }
        model.draft = wrapped
        await Task.yield()
        XCTAssertEqual(model.fieldContentHeight, DraftTextMetrics.lineHeight)
        await fulfillment(of: [trailingLayout], timeout: 1)

        XCTAssertEqual(
            model.fieldContentHeight,
            DraftTextMetrics.height(for: wrapped, width: 80),
            "节流窗口内跨行后停手，也应在尾沿使用最终文本重测"
        )
        cancellable.cancel()
    }
}
