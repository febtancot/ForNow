import XCTest
import CoreGraphics
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

    func testDisplayAtPointSupportsMultiDisplayCoordinates() {
        let displays = [
            (id: "built-in", frame: CGRect(x: 0, y: 0, width: 1800, height: 1169)),
            (id: "upper", frame: CGRect(x: -411, y: 1169, width: 2560, height: 1440)),
            (id: "left", frame: CGRect(x: -1920, y: 0, width: 1920, height: 1080))
        ]

        XCTAssertEqual(
            DisplayAttachmentSelection.displayID(
                at: CGPoint(x: 900, y: 500),
                orderedDisplayFrames: displays
            ),
            "built-in"
        )
        XCTAssertEqual(
            DisplayAttachmentSelection.displayID(
                at: CGPoint(x: 100, y: 1400),
                orderedDisplayFrames: displays
            ),
            "upper"
        )
        XCTAssertEqual(
            DisplayAttachmentSelection.displayID(
                at: CGPoint(x: -1_000, y: 500),
                orderedDisplayFrames: displays
            ),
            "left"
        )
        XCTAssertNil(
            DisplayAttachmentSelection.displayID(
                at: CGPoint(x: 4_000, y: 4_000),
                orderedDisplayFrames: displays
            )
        )
    }

    func testDisplayAtPointUsesHalfOpenEdgesAndSystemOrder() {
        let adjacentDisplays = [
            (id: "left", frame: CGRect(x: -100, y: 0, width: 100, height: 100)),
            (id: "right", frame: CGRect(x: 0, y: 0, width: 100, height: 100)),
            (id: "below", frame: CGRect(x: 0, y: -100, width: 100, height: 100))
        ]

        XCTAssertEqual(
            DisplayAttachmentSelection.displayID(
                at: CGPoint(x: -0.001, y: 50),
                orderedDisplayFrames: adjacentDisplays
            ),
            "left"
        )
        XCTAssertEqual(
            DisplayAttachmentSelection.displayID(
                at: CGPoint(x: 0, y: 50),
                orderedDisplayFrames: adjacentDisplays
            ),
            "right"
        )
        XCTAssertEqual(
            DisplayAttachmentSelection.displayID(
                at: CGPoint(x: 50, y: -0.001),
                orderedDisplayFrames: adjacentDisplays
            ),
            "below"
        )
        XCTAssertNil(
            DisplayAttachmentSelection.displayID(
                at: CGPoint(x: 100, y: 50),
                orderedDisplayFrames: adjacentDisplays
            )
        )

        let mirroredDisplays = [
            (id: "first", frame: CGRect(x: 0, y: 0, width: 100, height: 100)),
            (id: "second", frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        ]
        XCTAssertEqual(
            DisplayAttachmentSelection.displayID(
                at: CGPoint(x: 50, y: 50),
                orderedDisplayFrames: mirroredDisplays
            ),
            "first"
        )
        XCTAssertNil(
            DisplayAttachmentSelection.displayID(
                at: CGPoint.zero,
                orderedDisplayFrames: []
            )
        )
    }

    func testShortcutPanelRequiresRequestedScreenToBeAvailable() {
        XCTAssertEqual(
            DisplayAttachmentSelection.shortcutPanelDisplayID(
                requestedID: "mouse-screen",
                availableIDs: ["main", "mouse-screen"],
                unavailableIDs: []
            ),
            "mouse-screen"
        )
        XCTAssertNil(
            DisplayAttachmentSelection.shortcutPanelDisplayID(
                requestedID: "mouse-screen",
                availableIDs: ["main", "mouse-screen"],
                unavailableIDs: ["mouse-screen"]
            )
        )
        XCTAssertNil(
            DisplayAttachmentSelection.shortcutPanelDisplayID(
                requestedID: "disconnected",
                availableIDs: ["main"],
                unavailableIDs: []
            )
        )
        XCTAssertNil(
            DisplayAttachmentSelection.shortcutPanelDisplayID(
                requestedID: nil,
                availableIDs: ["main"],
                unavailableIDs: []
            )
        )
    }
}
