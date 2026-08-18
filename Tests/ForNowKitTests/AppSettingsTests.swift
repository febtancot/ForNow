import XCTest
@testable import ForNowKit

@MainActor
final class AppSettingsTests: XCTestCase {
    func testPanelWidthDefaultsToOriginalWidth() {
        let defaults = makeDefaults()
        let settings = AppSettings(defaults: defaults)

        XCTAssertEqual(settings.panelWidth, 384)
    }

    func testPanelWidthPersistsAcrossReload() {
        let defaults = makeDefaults()
        let settings = AppSettings(defaults: defaults)
        settings.setPanelWidth(512)

        let reloaded = AppSettings(defaults: defaults)

        XCTAssertEqual(reloaded.panelWidth, 512)
    }

    func testPanelWidthIsClampedToSupportedRange() {
        let defaults = makeDefaults()
        let settings = AppSettings(defaults: defaults)

        settings.setPanelWidth(100)
        XCTAssertEqual(settings.panelWidth, AppSettings.minimumPanelWidth)

        settings.setPanelWidth(2_000)
        XCTAssertEqual(settings.panelWidth, AppSettings.maximumPanelWidth)
    }

    func testResetPanelWidthRestoresAndPersistsDefault() {
        let defaults = makeDefaults()
        let settings = AppSettings(defaults: defaults)
        settings.setPanelWidth(560)

        settings.resetPanelWidth()

        XCTAssertEqual(settings.panelWidth, AppSettings.defaultPanelWidth)
        XCTAssertEqual(AppSettings(defaults: defaults).panelWidth, AppSettings.defaultPanelWidth)
    }

    func testDisplayAttachmentsDefaultToAutomaticMode() {
        let settings = AppSettings(defaults: makeDefaults())

        XCTAssertTrue(settings.attachedDisplayIDs.isEmpty)
    }

    func testDisplayAttachmentsPersistAcrossReload() {
        let defaults = makeDefaults()
        let settings = AppSettings(defaults: defaults)
        settings.setAttachedDisplayIDs(["display-a", "display-b"])

        XCTAssertEqual(AppSettings(defaults: defaults).attachedDisplayIDs, ["display-a", "display-b"])
    }

    func testResetDisplayAttachmentsRestoresAutomaticMode() {
        let defaults = makeDefaults()
        let settings = AppSettings(defaults: defaults)
        settings.setAttachedDisplayIDs(["display-a"])

        settings.resetAttachedDisplays()

        XCTAssertTrue(settings.attachedDisplayIDs.isEmpty)
        XCTAssertTrue(AppSettings(defaults: defaults).attachedDisplayIDs.isEmpty)
    }

    private func makeDefaults() -> UserDefaults {
        let suite = "AppSettingsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}
