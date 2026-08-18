import XCTest
@testable import ForNowKit

final class DisplayAttachmentSelectionTests: XCTestCase {
    func testAutomaticModeUsesDefaultDisplay() {
        XCTAssertEqual(
            DisplayAttachmentSelection.resolvedIDs(
                configuredIDs: [], availableIDs: ["a", "b", "c"], defaultID: "b"
            ),
            ["b"]
        )
    }

    func testMultipleConnectedSelectionsKeepSystemOrder() {
        XCTAssertEqual(
            DisplayAttachmentSelection.resolvedIDs(
                configuredIDs: ["a", "c"], availableIDs: ["c", "b", "a"], defaultID: "b"
            ),
            ["c", "a"]
        )
    }

    func testDisconnectedSelectionsTemporarilyFallBackToDefault() {
        XCTAssertEqual(
            DisplayAttachmentSelection.resolvedIDs(
                configuredIDs: ["missing"], availableIDs: ["a", "b"], defaultID: "a"
            ),
            ["a"]
        )
    }

    func testNoAvailableDisplaysProducesNoTargets() {
        XCTAssertTrue(
            DisplayAttachmentSelection.resolvedIDs(
                configuredIDs: ["missing"], availableIDs: [], defaultID: nil
            ).isEmpty
        )
    }
}
