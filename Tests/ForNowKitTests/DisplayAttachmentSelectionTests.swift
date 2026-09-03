import XCTest
@testable import ForNowKit

final class DisplayAttachmentSelectionTests: XCTestCase {
    func testAutomaticModeUsesDefaultDisplay() {
        XCTAssertEqual(
            DisplayAttachmentSelection.automatic.resolvedIDs(
                availableIDs: ["a", "b", "c"], defaultID: "b"
            ),
            ["b"]
        )
    }

    func testAutomaticModeFallsBackWhenDefaultIsUnavailable() {
        XCTAssertEqual(
            DisplayAttachmentSelection.automatic.resolvedIDs(
                availableIDs: ["a", "b"], defaultID: "missing"
            ),
            ["a"]
        )
    }

    func testDisabledModeKeepsAllDisplaysHiddenAcrossAvailableDisplayChanges() {
        XCTAssertTrue(
            DisplayAttachmentSelection.disabled.resolvedIDs(
                availableIDs: ["a", "b"], defaultID: "a"
            ).isEmpty
        )
        XCTAssertTrue(
            DisplayAttachmentSelection.disabled.resolvedIDs(
                availableIDs: ["new"], defaultID: "new"
            ).isEmpty
        )
    }

    func testDisabledModeKeepsHiddenTriggersOnNotchedDisplays() {
        XCTAssertEqual(
            DisplayAttachmentSelection.disabled.hiddenNotchTriggerIDs(
                availableIDs: ["external-a", "notch", "external-b", "notch-2"],
                notchedIDs: ["notch", "notch-2"]
            ),
            ["notch", "notch-2"]
        )
        XCTAssertTrue(
            DisplayAttachmentSelection.disabled.hiddenNotchTriggerIDs(
                availableIDs: ["external-a", "external-b"],
                notchedIDs: []
            ).isEmpty
        )
        XCTAssertEqual(
            DisplayAttachmentSelection.disabled.hiddenNotchTriggerIDs(
                availableIDs: ["external", "notch"],
                notchedIDs: ["notch", "disconnected-notch"]
            ),
            ["notch"]
        )
    }

    func testVisibleCapsuleModesDoNotCreateHiddenNotchTriggers() {
        for selection in [
            DisplayAttachmentSelection.automatic,
            .selected(["external"])
        ] {
            XCTAssertTrue(
                selection.hiddenNotchTriggerIDs(
                    availableIDs: ["notch", "external"],
                    notchedIDs: ["notch"]
                ).isEmpty
            )
        }
    }

    func testMultipleConnectedSelectionsKeepSystemOrder() {
        XCTAssertEqual(
            DisplayAttachmentSelection.selected(["a", "c"]).resolvedIDs(
                availableIDs: ["c", "b", "a"], defaultID: "b"
            ),
            ["c", "a"]
        )
    }

    func testDisconnectedSelectionsTemporarilyFallBackToDefault() {
        let selection = DisplayAttachmentSelection.selected(["missing"])
        XCTAssertEqual(
            selection.resolvedIDs(
                availableIDs: ["a", "b"], defaultID: "a"
            ),
            ["a"]
        )
        XCTAssertEqual(
            selection.resolvedIDs(
                availableIDs: ["a", "missing"], defaultID: "a"
            ),
            ["missing"]
        )
        XCTAssertEqual(
            selection.resolvedIDs(
                availableIDs: ["a", "b"], defaultID: "stale"
            ),
            ["a"]
        )
    }

    func testNoAvailableDisplaysProducesNoTargets() {
        XCTAssertTrue(
            DisplayAttachmentSelection.selected(["missing"]).resolvedIDs(
                availableIDs: [], defaultID: nil
            ).isEmpty
        )
    }

    func testTurningOffAutomaticDefaultDisablesAllCapsules() {
        XCTAssertEqual(
            DisplayAttachmentSelection.automatic.togglingDisplay(
                "a", enabled: false, availableIDs: ["a", "b"], defaultID: "a"
            ),
            .disabled
        )
    }

    func testTurningOffOneOfMultipleDisplaysKeepsTheOtherSelection() {
        XCTAssertEqual(
            DisplayAttachmentSelection.selected(["a", "b"]).togglingDisplay(
                "a", enabled: false, availableIDs: ["a", "b"], defaultID: "a"
            ),
            .selected(["b"])
        )
    }

    func testTurningOffLastConnectedSelectionIgnoresStaleDisplayIDs() {
        XCTAssertEqual(
            DisplayAttachmentSelection.selected(["a", "stale"]).togglingDisplay(
                "a", enabled: false, availableIDs: ["a", "b"], defaultID: "a"
            ),
            .disabled
        )
    }

    func testTurningOnDisplayFromDisabledSelectsOnlyThatDisplay() {
        XCTAssertEqual(
            DisplayAttachmentSelection.disabled.togglingDisplay(
                "b", enabled: true, availableIDs: ["a", "b"], defaultID: "a"
            ),
            .selected(["b"])
        )
    }

    func testDisplayTogglesNormalizeBackToAutomaticDefault() {
        XCTAssertEqual(
            DisplayAttachmentSelection.disabled.togglingDisplay(
                "a", enabled: true, availableIDs: ["a", "b"], defaultID: "a"
            ),
            .automatic
        )
        XCTAssertEqual(
            DisplayAttachmentSelection.selected(["a", "b"]).togglingDisplay(
                "b", enabled: false, availableIDs: ["a", "b"], defaultID: "a"
            ),
            .automatic
        )
    }

    func testTransientPanelPrefersRequestedThenDefaultAvailableDisplay() {
        XCTAssertEqual(
            DisplayAttachmentSelection.transientPanelDisplayID(
                requestedID: "b",
                availableIDs: ["a", "b", "c"],
                defaultID: "a",
                unavailableIDs: []
            ),
            "b"
        )
        XCTAssertEqual(
            DisplayAttachmentSelection.transientPanelDisplayID(
                requestedID: "missing",
                availableIDs: ["a", "b", "c"],
                defaultID: "a",
                unavailableIDs: []
            ),
            "a"
        )
        XCTAssertEqual(
            DisplayAttachmentSelection.transientPanelDisplayID(
                requestedID: nil,
                availableIDs: ["a", "b", "c"],
                defaultID: "a",
                unavailableIDs: ["a"]
            ),
            "b"
        )
        XCTAssertEqual(
            DisplayAttachmentSelection.transientPanelDisplayID(
                requestedID: nil,
                availableIDs: ["a", "b", "c"],
                defaultID: "missing",
                unavailableIDs: ["a"]
            ),
            "b"
        )
    }

    func testTransientPanelReturnsNilWhenNoDisplayCanPresentIt() {
        XCTAssertNil(
            DisplayAttachmentSelection.transientPanelDisplayID(
                requestedID: nil,
                availableIDs: ["a", "b"],
                defaultID: "a",
                unavailableIDs: ["a", "b"]
            )
        )
        XCTAssertNil(
            DisplayAttachmentSelection.transientPanelDisplayID(
                requestedID: nil,
                availableIDs: [],
                defaultID: nil,
                unavailableIDs: []
            )
        )
    }
}
