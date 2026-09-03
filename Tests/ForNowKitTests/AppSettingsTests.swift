import XCTest
@testable import ForNowKit

@MainActor
final class AppSettingsTests: XCTestCase {
    func testFullScreenParticipationDefaultsToDisabled() {
        let settings = AppSettings(defaults: makeDefaults())

        XCTAssertFalse(settings.enableInFullScreen)
    }

    func testFullScreenParticipationPersistsExplicitChoice() {
        let defaults = makeDefaults()
        let settings = AppSettings(defaults: defaults)
        settings.enableInFullScreen = true

        XCTAssertTrue(AppSettings(defaults: defaults).enableInFullScreen)
    }

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

        XCTAssertEqual(settings.displayAttachmentSelection, .automatic)
    }

    func testDisplayAttachmentsPersistAcrossReload() {
        let defaults = makeDefaults()
        let settings = AppSettings(defaults: defaults)
        settings.setAttachedDisplayIDs(["display-a", "display-b"])

        XCTAssertEqual(
            AppSettings(defaults: defaults).displayAttachmentSelection,
            .selected(["display-a", "display-b"])
        )
    }

    func testResetDisplayAttachmentsRestoresAutomaticMode() {
        let defaults = makeDefaults()
        let settings = AppSettings(defaults: defaults)
        settings.setAttachedDisplayIDs(["display-a"])

        settings.resetAttachedDisplays()

        XCTAssertEqual(settings.displayAttachmentSelection, .automatic)
        XCTAssertEqual(AppSettings(defaults: defaults).displayAttachmentSelection, .automatic)
    }

    func testDisabledDisplayAttachmentsPersistAcrossReload() {
        let defaults = makeDefaults()
        let settings = AppSettings(defaults: defaults)

        settings.setDisplayAttachmentSelection(.disabled)

        XCTAssertEqual(settings.displayAttachmentSelection, .disabled)
        XCTAssertEqual(AppSettings(defaults: defaults).displayAttachmentSelection, .disabled)
    }

    func testEmptyLegacyDisplayIDsSetterPreservesAutomaticMode() {
        let defaults = makeDefaults()
        let settings = AppSettings(defaults: defaults)
        settings.setDisplayAttachmentSelection(.disabled)

        settings.setAttachedDisplayIDs([])

        XCTAssertEqual(settings.displayAttachmentSelection, .automatic)
        XCTAssertEqual(AppSettings(defaults: defaults).displayAttachmentSelection, .automatic)
    }

    func testEmptySelectedDisplayAttachmentsNormalizeToDisabled() {
        let defaults = makeDefaults()
        let settings = AppSettings(defaults: defaults)

        settings.setDisplayAttachmentSelection(.selected([]))

        XCTAssertEqual(settings.displayAttachmentSelection, .disabled)
        XCTAssertEqual(AppSettings(defaults: defaults).displayAttachmentSelection, .disabled)
    }

    func testLegacyEmptyDisplayAttachmentsRemainAutomatic() {
        let defaults = makeDefaults()
        defaults.set([], forKey: "settings.attachedDisplayIDs")

        XCTAssertEqual(AppSettings(defaults: defaults).displayAttachmentSelection, .automatic)
    }

    func testLegacySelectedDisplayAttachmentsAreMigrated() {
        let defaults = makeDefaults()
        defaults.set(["display-b", "display-a"], forKey: "settings.attachedDisplayIDs")

        XCTAssertEqual(
            AppSettings(defaults: defaults).displayAttachmentSelection,
            .selected(["display-a", "display-b"])
        )
    }

    func testUnknownDisplayAttachmentModeUsesLegacyFallback() {
        let defaults = makeDefaults()
        defaults.set("unexpected", forKey: "settings.displayAttachmentMode")
        defaults.set(["display-a"], forKey: "settings.attachedDisplayIDs")

        XCTAssertEqual(
            AppSettings(defaults: defaults).displayAttachmentSelection,
            .selected(["display-a"])
        )
    }

    func testUnknownDisplayAttachmentModeWithoutIDsFallsBackToAutomatic() {
        let defaults = makeDefaults()
        defaults.set("unexpected", forKey: "settings.displayAttachmentMode")

        XCTAssertEqual(AppSettings(defaults: defaults).displayAttachmentSelection, .automatic)
    }

    func testAutomaticDisplayAttachmentModeIgnoresStaleIDs() {
        let defaults = makeDefaults()
        defaults.set("automatic", forKey: "settings.displayAttachmentMode")
        defaults.set(["stale"], forKey: "settings.attachedDisplayIDs")

        XCTAssertEqual(AppSettings(defaults: defaults).displayAttachmentSelection, .automatic)
    }

    func testDisabledDisplayAttachmentModeIgnoresStaleIDs() {
        let defaults = makeDefaults()
        defaults.set("disabled", forKey: "settings.displayAttachmentMode")
        defaults.set(["stale"], forKey: "settings.attachedDisplayIDs")

        XCTAssertEqual(AppSettings(defaults: defaults).displayAttachmentSelection, .disabled)
    }

    func testSelectedModeWithEmptyIDsFallsBackToAutomatic() {
        let defaults = makeDefaults()
        defaults.set("selected", forKey: "settings.displayAttachmentMode")
        defaults.set([], forKey: "settings.attachedDisplayIDs")

        XCTAssertEqual(AppSettings(defaults: defaults).displayAttachmentSelection, .automatic)
    }

    private func makeDefaults() -> UserDefaults {
        let suite = "AppSettingsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}
