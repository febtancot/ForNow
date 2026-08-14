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
}
