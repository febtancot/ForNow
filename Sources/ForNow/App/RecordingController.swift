import AppKit
import AVFoundation
import ForNowKit

/// 麦克风录音：点击开始/停止，停止后音频入库（m4a）。
@MainActor
final class RecordingController: ObservableObject {
    @Published private(set) var isRecording = false
    /// 已录制时长（秒），录音中每 0.5s 刷新，供胶囊/头部实时计时显示。
    @Published private(set) var elapsedSeconds: TimeInterval = 0

    private let store: StashStore
    private let feedback: (String) -> Void
    private var recorder: AVAudioRecorder?
    private var tempURL: URL?
    private var ticker: Timer?

    private static let stampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()

    init(store: StashStore, feedback: @escaping (String) -> Void) {
        self.store = store
        self.feedback = feedback
    }

    /// 开始录音（首次会弹麦克风权限授权框）。
    func start() {
        guard !isRecording else { return }
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            begin()
        case .denied:
            feedback("麦克风权限被拒，请在系统设置中允许")
        case .undetermined:
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                Task { @MainActor in
                    granted ? self?.begin() : self?.feedback("需要麦克风权限才能录音")
                }
            }
        @unknown default:
            break
        }
    }

    /// 停止并入库。返回入库项目；nil 表示过短取消或失败。
    @discardableResult
    func stopAndStash() -> StashItem? {
        guard isRecording, let recorder else { return nil }
        recorder.stop()
        isRecording = false
        let duration = recorder.currentTime
        guard duration >= 0.5, let url = tempURL, let data = try? Data(contentsOf: url) else {
            cleanup()
            return nil
        }
        cleanup()
        let stamp = Self.stampFormatter.string(from: Date())
        return try? store.addAudio(data: data, suggestedName: "录音-\(stamp)", durationSeconds: duration)
    }

    private func begin() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ForNowRecording", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("recording-\(UUID().uuidString).m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            ]
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.prepareToRecord()
            guard recorder.record() else {
                try? FileManager.default.removeItem(at: url)
                feedback("录音启动失败")
                return
            }
            self.recorder = recorder
            self.tempURL = url
            isRecording = true
            elapsedSeconds = 0
            let ticker = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.elapsedSeconds = self?.recorder?.currentTime ?? 0
                }
            }
            RunLoop.main.add(ticker, forMode: .common)
            self.ticker = ticker
        } catch {
            feedback("录音启动失败")
        }
    }

    private func cleanup() {
        ticker?.invalidate()
        ticker = nil
        elapsedSeconds = 0
        if let url = tempURL { try? FileManager.default.removeItem(at: url) }
        tempURL = nil
        recorder = nil
    }
}
