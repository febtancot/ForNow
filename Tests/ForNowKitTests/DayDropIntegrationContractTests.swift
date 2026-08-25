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

    func testTargetDisplayCapabilityRequiresSupportedVersion() {
        XCTAssertFalse(DayDropIntegrationContract.supportsTargetDisplay(infoDictionary: nil))
        XCTAssertFalse(
            DayDropIntegrationContract.supportsTargetDisplay(
                infoDictionary: [DayDropIntegrationContract.targetDisplayCapabilityInfoKey: 0]
            )
        )
        XCTAssertTrue(
            DayDropIntegrationContract.supportsTargetDisplay(
                infoDictionary: [DayDropIntegrationContract.targetDisplayCapabilityInfoKey: 1]
            )
        )
        XCTAssertTrue(
            DayDropIntegrationContract.supportsTargetDisplay(
                infoDictionary: [DayDropIntegrationContract.targetDisplayCapabilityInfoKey: "2"]
            )
        )
    }

    func testTargetDisplayURLCarriesDisplayIdentity() throws {
        let url = try XCTUnwrap(
            DayDropIntegrationContract.openTodayFolderURL(
                targetDisplayID: "runtime-display-42"
            )
        )
        let components = try XCTUnwrap(
            URLComponents(url: url, resolvingAgainstBaseURL: false)
        )

        XCTAssertEqual(url.host, "open-today-folder")
        XCTAssertEqual(
            components.queryItems,
            [URLQueryItem(name: "display-id", value: "runtime-display-42")]
        )
    }

    func testTargetDisplayURLRejectsEmptyIdentity() {
        XCTAssertNil(DayDropIntegrationContract.openTodayFolderURL(targetDisplayID: ""))
        XCTAssertNil(
            DayDropIntegrationContract.openTodayFolderURL(targetDisplayID: "screen one")
        )
    }
}
