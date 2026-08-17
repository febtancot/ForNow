import XCTest
@testable import ForNowKit

@MainActor
final class AudioPlaybackControllerTests: XCTestCase {
    func testToggleStartsPausesAndResumesSameItem() {
        let fake = FakeAudioPlayer(duration: 12)
        let controller = makeController(players: [fake])
        let id = UUID()

        XCTAssertTrue(controller.toggle(itemID: id, fileURL: URL(fileURLWithPath: "/tmp/a.m4a")))
        XCTAssertEqual(controller.activeItemID, id)
        XCTAssertTrue(controller.isPlaying)
        XCTAssertEqual(controller.duration, 12)

        fake.currentTime = 3
        XCTAssertTrue(controller.toggle(itemID: id, fileURL: URL(fileURLWithPath: "/tmp/a.m4a")))
        XCTAssertFalse(controller.isPlaying)
        XCTAssertEqual(controller.currentTime, 3)
        XCTAssertEqual(fake.pauseCount, 1)

        XCTAssertTrue(controller.toggle(itemID: id, fileURL: URL(fileURLWithPath: "/tmp/a.m4a")))
        XCTAssertTrue(controller.isPlaying)
        XCTAssertEqual(fake.playCount, 2)
    }

    func testSwitchingItemStopsPreviousPlayer() {
        let first = FakeAudioPlayer(duration: 10)
        let second = FakeAudioPlayer(duration: 20)
        let controller = makeController(players: [first, second])
        let firstID = UUID()
        let secondID = UUID()

        XCTAssertTrue(controller.toggle(itemID: firstID, fileURL: URL(fileURLWithPath: "/tmp/a.m4a")))
        XCTAssertTrue(controller.toggle(itemID: secondID, fileURL: URL(fileURLWithPath: "/tmp/b.m4a")))

        XCTAssertEqual(first.stopCount, 1)
        XCTAssertEqual(controller.activeItemID, secondID)
        XCTAssertEqual(controller.duration, 20)
        XCTAssertTrue(controller.isPlaying)
    }

    func testSeekClampsToValidRange() {
        let fake = FakeAudioPlayer(duration: 8)
        let controller = makeController(players: [fake])
        XCTAssertTrue(controller.toggle(itemID: UUID(), fileURL: URL(fileURLWithPath: "/tmp/a.m4a")))

        controller.seek(to: 99)
        XCTAssertEqual(controller.currentTime, 8)
        XCTAssertEqual(fake.currentTime, 8)

        controller.seek(to: -2)
        XCTAssertEqual(controller.currentTime, 0)
        XCTAssertEqual(fake.currentTime, 0)
    }

    func testPlaybackFailureLeavesNoActiveItem() {
        let fake = FakeAudioPlayer(duration: 5, playSucceeds: false)
        let controller = makeController(players: [fake])

        XCTAssertFalse(controller.toggle(itemID: UUID(), fileURL: URL(fileURLWithPath: "/tmp/a.m4a")))
        XCTAssertNil(controller.activeItemID)
        XCTAssertFalse(controller.isPlaying)
        XCTAssertEqual(controller.duration, 0)
    }

    func testNaturalCompletionClearsPlaybackState() {
        let fake = FakeAudioPlayer(duration: 5)
        let controller = makeController(players: [fake])
        XCTAssertTrue(controller.toggle(itemID: UUID(), fileURL: URL(fileURLWithPath: "/tmp/a.m4a")))

        fake.currentTime = 5
        fake.isPlaying = false
        controller.refreshProgress()

        XCTAssertNil(controller.activeItemID)
        XCTAssertFalse(controller.isPlaying)
        XCTAssertEqual(controller.currentTime, 0)
    }

    private func makeController(players: [FakeAudioPlayer]) -> AudioPlaybackController {
        var queue = players
        return AudioPlaybackController(playerFactory: { _ in queue.removeFirst() },
                                       progressUpdatesEnabled: false)
    }
}

private final class FakeAudioPlayer: AudioPlaying {
    var currentTime: TimeInterval = 0
    let duration: TimeInterval
    var isPlaying = false
    var prepareSucceeds = true
    var playSucceeds: Bool
    private(set) var playCount = 0
    private(set) var pauseCount = 0
    private(set) var stopCount = 0

    init(duration: TimeInterval, playSucceeds: Bool = true) {
        self.duration = duration
        self.playSucceeds = playSucceeds
    }

    func prepareToPlay() -> Bool { prepareSucceeds }

    func play() -> Bool {
        playCount += 1
        isPlaying = playSucceeds
        return playSucceeds
    }

    func pause() {
        pauseCount += 1
        isPlaying = false
    }

    func stop() {
        stopCount += 1
        isPlaying = false
        currentTime = 0
    }
}
