import XCTest
@testable import ForNowKit

final class DayDropIntegrationContractTests: XCTestCase {
    func testAvailabilityRequiresInstalledDayDropAndItsURLHandler() {
        let applicationURL = URL(fileURLWithPath: "/Applications/DayDrop.app")

        XCTAssertTrue(
            DayDropIntegrationContract.canOpenTodayFolder(
                installedApplicationURL: applicationURL,
                schemeHandlerApplicationURL: applicationURL,
                schemeHandlerBundleIdentifier: DayDropIntegrationContract.bundleIdentifier
            )
        )
    }

    func testAvailabilityRejectsMissingApplication() {
        XCTAssertFalse(
            DayDropIntegrationContract.canOpenTodayFolder(
                installedApplicationURL: nil,
                schemeHandlerApplicationURL: URL(fileURLWithPath: "/Applications/DayDrop.app"),
                schemeHandlerBundleIdentifier: DayDropIntegrationContract.bundleIdentifier
            )
        )
    }

    func testAvailabilityRejectsSchemeOwnedByAnotherApplication() {
        XCTAssertFalse(
            DayDropIntegrationContract.canOpenTodayFolder(
                installedApplicationURL: URL(fileURLWithPath: "/Applications/DayDrop.app"),
                schemeHandlerApplicationURL: URL(fileURLWithPath: "/Applications/DayDrop.app"),
                schemeHandlerBundleIdentifier: "com.example.NotDayDrop"
            )
        )
    }

    func testAvailabilityRejectsDifferentRegisteredCopy() {
        XCTAssertFalse(
            DayDropIntegrationContract.canOpenTodayFolder(
                installedApplicationURL: URL(fileURLWithPath: "/Applications/DayDrop.app"),
                schemeHandlerApplicationURL: URL(fileURLWithPath: "/tmp/DerivedData/DayDrop.app"),
                schemeHandlerBundleIdentifier: DayDropIntegrationContract.bundleIdentifier
            )
        )
    }

    func testOpenTodayFolderURLIsStable() {
        XCTAssertEqual(
            DayDropIntegrationContract.openTodayFolderURL.absoluteString,
            "daydrop://open-today-folder"
        )
    }
}
