import XCTest
import CoreGraphics
@testable import ForNowKit

final class FullScreenWindowDetectorTests: XCTestCase {
    private let displayBounds = CGRect(x: -444, y: -1440, width: 2560, height: 1440)

    func testDetectsLayerZeroWindowCoveringDisplay() {
        let covered = detect([
            snapshot(bounds: displayBounds)
        ])

        XCTAssertEqual(covered, ["studio"])
    }

    func testDoesNotTreatOrdinaryWindowAsFullScreen() {
        let covered = detect([
            snapshot(bounds: CGRect(x: -300, y: -1300, width: 1800, height: 1000))
        ])

        XCTAssertTrue(covered.isEmpty)
    }

    func testIgnoresStatusBarAndOwnWindows() {
        let covered = detect([
            snapshot(ownerPID: 99, layer: 25, bounds: displayBounds),
            snapshot(ownerPID: 42, bounds: displayBounds)
        ])

        XCTAssertTrue(covered.isEmpty)
    }

    func testAllowsSmallWindowServerRoundingDifference() {
        let nearlyFullScreen = displayBounds.insetBy(dx: 1, dy: 1)

        XCTAssertEqual(detect([snapshot(bounds: nearlyFullScreen)]), ["studio"])
    }

    func testReportsOnlyTheCoveredDisplay() {
        let displays = [
            "studio": displayBounds,
            "mi": CGRect(x: 2116, y: -1080, width: 1920, height: 1080)
        ]
        let covered = FullScreenWindowDetector.coveredDisplayIDs(
            displayBoundsByID: displays,
            windows: [snapshot(bounds: displayBounds)],
            excludingOwnerPID: 42
        )

        XCTAssertEqual(covered, ["studio"])
    }

    private func detect(_ windows: [WindowCoverageSnapshot]) -> Set<String> {
        FullScreenWindowDetector.coveredDisplayIDs(
            displayBoundsByID: ["studio": displayBounds],
            windows: windows,
            excludingOwnerPID: 42
        )
    }

    private func snapshot(
        ownerPID: Int32 = 99,
        layer: Int = 0,
        alpha: Double = 1,
        bounds: CGRect
    ) -> WindowCoverageSnapshot {
        WindowCoverageSnapshot(
            ownerPID: ownerPID,
            layer: layer,
            alpha: alpha,
            bounds: bounds
        )
    }
}
