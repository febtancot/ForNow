import XCTest
import CoreGraphics
@testable import ForNowKit

final class NotchMetricsTests: XCTestCase {
    private let notchScreen = CGRect(x: 0, y: 0, width: 1512, height: 982)

    func testDetectsNotchAndWidth() {
        let m = NotchMetrics(screenFrame: notchScreen, safeAreaTop: 38, auxLeftWidth: 620, auxRightWidth: 620)
        XCTAssertTrue(m.hasNotch)
        XCTAssertEqual(m.notchWidth, 1512 - 1240)
        XCTAssertEqual(m.notchHeight, 38)
    }

    func testNoNotchWhenAuxAreasMissing() {
        let m = NotchMetrics(screenFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                             safeAreaTop: 0, auxLeftWidth: nil, auxRightWidth: nil)
        XCTAssertFalse(m.hasNotch)
        XCTAssertEqual(m.notchWidth, 0)
    }

    func testOpenFrameIsHorizontallyCentredAndTopAligned() {
        let m = NotchMetrics(screenFrame: notchScreen, safeAreaTop: 38, auxLeftWidth: 620, auxRightWidth: 620)
        let frame = m.openFrame(width: 384, height: 470)
        XCTAssertEqual(frame.midX, notchScreen.midX, accuracy: 1)
        XCTAssertEqual(frame.maxY, notchScreen.maxY, accuracy: 1) // 顶边贴屏幕顶
        XCTAssertEqual(frame.width, 384)
        XCTAssertEqual(frame.height, 470)
    }

    func testClosedFrameMatchesNotchWidth() {
        let m = NotchMetrics(screenFrame: notchScreen, safeAreaTop: 38, auxLeftWidth: 620, auxRightWidth: 620)
        let frame = m.closedFrame()
        XCTAssertEqual(frame.width, 272) // = notchWidth (>160)
        XCTAssertEqual(frame.midX, notchScreen.midX, accuracy: 1)
    }

    func testOpenFrameClampedToScreen() {
        let small = CGRect(x: 0, y: 0, width: 300, height: 300)
        let m = NotchMetrics(screenFrame: small, safeAreaTop: 0, auxLeftWidth: nil, auxRightWidth: nil)
        let frame = m.openFrame(width: 384, height: 470)
        XCTAssertLessThanOrEqual(frame.width, 300 - 40)
        XCTAssertLessThanOrEqual(frame.height, 300 - 120)
    }

    func testExternalDisplayFallbackUsesCentreTab() {
        let external = CGRect(x: 1512, y: 0, width: 2560, height: 1440) // 右侧外接屏
        let m = NotchMetrics(screenFrame: external, safeAreaTop: 0, auxLeftWidth: nil, auxRightWidth: nil)
        let frame = m.closedFrame(fallbackWidth: 190)
        XCTAssertEqual(frame.width, 190)
        XCTAssertEqual(frame.midX, external.midX, accuracy: 1)
    }
}
