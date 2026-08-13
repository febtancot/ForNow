import XCTest
@testable import ForNowKit

final class GlobalHotKeyTests: XCTestCase {
    func testDefaultIsControlOptionSpace() {
        let key = GlobalHotKey.default
        XCTAssertEqual(key.keyCode, 49)
        XCTAssertTrue(key.modifiers.contains(.control))
        XCTAssertTrue(key.modifiers.contains(.option))
        XCTAssertEqual(key.displayString, "⌃⌥Space")
    }

    func testDisplayStringModifierOrder() {
        let key = GlobalHotKey(keyCode: 1, modifiers: [.command, .shift, .control, .option])
        XCTAssertEqual(key.displayString, "⌃⌥⇧⌘S") // 顺序固定：⌃⌥⇧⌘
    }

    func testPersistenceRoundTrip() {
        let defaults = UserDefaults(suiteName: "GlobalHotKeyTests-\(UUID().uuidString)")!
        let key = GlobalHotKey(keyCode: 3, modifiers: [.command])
        key.save(to: defaults)
        let loaded = GlobalHotKey.load(from: defaults)
        XCTAssertEqual(loaded, key)
    }

    func testLoadReturnsNilWhenAbsent() {
        let defaults = UserDefaults(suiteName: "GlobalHotKeyTests-empty-\(UUID().uuidString)")!
        XCTAssertNil(GlobalHotKey.load(from: defaults))
    }
}
