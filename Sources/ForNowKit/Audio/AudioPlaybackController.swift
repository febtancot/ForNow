import AVFoundation
import Combine
import Foundation

/// 对 AVAudioPlayer 的最小抽象，生产环境使用真实播放器，测试注入轻量替身。
protocol AudioPlaying: AnyObject {
    var currentTime: TimeInterval { get set }
    var duration: TimeInterval { get }
    var isPlaying: Bool { get }

    func prepareToPlay() -> Bool
    func play() -> Bool
    func pause()
    func stop()
}

extension AVAudioPlayer: AudioPlaying {}

/// 面板内单实例音频播放器：同一时间只保留一个活动项目，负责播放/暂停、进度和拖动定位。
@MainActor
public final class AudioPlaybackController: ObservableObject {
    @Published public private(set) var activeItemID: UUID?
    @Published public private(set) var isPlaying = false
    @Published public private(set) var currentTime: TimeInterval = 0
    @Published public private(set) var duration: TimeInterval = 0

    private let playerFactory: (URL) throws -> AudioPlaying
    private let progressUpdatesEnabled: Bool
    private var player: AudioPlaying?
    private var ticker: Timer?

    public convenience init() {
        self.init(playerFactory: { try AVAudioPlayer(contentsOf: $0) },
                  progressUpdatesEnabled: true)
    }

    init(playerFactory: @escaping (URL) throws -> AudioPlaying,
         progressUpdatesEnabled: Bool) {
        self.playerFactory = playerFactory
        self.progressUpdatesEnabled = progressUpdatesEnabled
    }

    deinit {
        ticker?.invalidate()
    }

    public func isActive(_ itemID: UUID) -> Bool {
        activeItemID == itemID
    }

    /// 同一项目切换播放/暂停；新项目会停止上一条并从头开始。
    /// - Returns: 是否成功进入播放或暂停状态。文件无法解码/播放时返回 false。
    @discardableResult
    public func toggle(itemID: UUID, fileURL: URL) -> Bool {
        if activeItemID == itemID, let player {
            if isPlaying {
                player.pause()
                currentTime = clamped(player.currentTime, upperBound: duration)
                isPlaying = false
                stopTicker()
                return true
            }
            if currentTime >= duration, duration > 0 {
                player.currentTime = 0
                currentTime = 0
            }
            guard startCurrentPlayer() else {
                player.stop()
                resetState()
                return false
            }
            return true
        }

        stop()
        do {
            let newPlayer = try playerFactory(fileURL)
            guard newPlayer.prepareToPlay() else { return false }
            player = newPlayer
            activeItemID = itemID
            duration = max(0, newPlayer.duration)
            currentTime = clamped(newPlayer.currentTime, upperBound: duration)
            guard startCurrentPlayer() else {
                newPlayer.stop()
                resetState()
                return false
            }
            return true
        } catch {
            resetState()
            return false
        }
    }

    /// 拖动当前活动项目的播放进度；越界值会被限制在 0...duration。
    public func seek(to requestedTime: TimeInterval) {
        guard let player else { return }
        let target = clamped(requestedTime, upperBound: duration)
        player.currentTime = target
        currentTime = target
    }

    public func stop() {
        player?.stop()
        resetState()
    }

    /// 定时同步真实播放器进度；播放自然结束或被系统中断时清理活动状态。
    func refreshProgress() {
        guard let player else {
            resetState()
            return
        }
        currentTime = clamped(player.currentTime, upperBound: duration)
        if isPlaying, !player.isPlaying {
            resetState()
        }
    }

    private func startCurrentPlayer() -> Bool {
        guard let player, player.play() else { return false }
        isPlaying = true
        startTicker()
        return true
    }

    private func startTicker() {
        stopTicker()
        guard progressUpdatesEnabled else { return }
        let ticker = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshProgress() }
        }
        RunLoop.main.add(ticker, forMode: .common)
        self.ticker = ticker
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func resetState() {
        stopTicker()
        player = nil
        activeItemID = nil
        isPlaying = false
        currentTime = 0
        duration = 0
    }

    private func clamped(_ value: TimeInterval, upperBound: TimeInterval) -> TimeInterval {
        min(max(0, value), max(0, upperBound))
    }
}
