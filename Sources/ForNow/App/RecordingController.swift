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
    private var isRequestingPermission = false
    private var isShowingPermissionAlert = false

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
        guard !isRecording, !isRequestingPermission, !isShowingPermissionAlert else { return }
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            begin()
        case .denied:
            showMicrophonePermissionAlert()
        case .undetermined:
            isRequestingPermission = true
            NSApp.activate(ignoringOtherApps: true)
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                Task { @MainActor in
                    guard let self else { return }
                    self.isRequestingPermission = false
                    if granted {
                        self.begin()
                    } else {
                        self.showMicrophonePermissionAlert()
                    }
                }
            }
        @unknown default:
            feedback("无法读取麦克风权限，请重新打开应用后重试")
        }
    }

    private func showMicrophonePermissionAlert() {
        guard !isShowingPermissionAlert else { return }
        isShowingPermissionAlert = true
        defer { isShowingPermissionAlert = false }

        let alert = NSAlert()
        alert.messageText = "需要麦克风权限才能录音"
        alert.informativeText = "请在系统设置的「隐私与安全性 → 麦克风」中允许「搁这儿」（ForNow）访问。允许后，回到应用再次点击录音。"
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "取消")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
        if !NSWorkspace.shared.open(url) {
            feedback("请手动打开系统设置 → 隐私与安全性 → 麦克风")
        }
    }

    /// 停止并入库。返回入库项目；nil 表示过短取消或失败。
    @discardableResult
    func stopAndStash() -> StashItem? {
        guard isRecording, let recorder else { return nil }
        // AVAudioRecorder 停止后 currentTime 在部分真机/系统版本会归零。
        // 必须先快照时长，再停止并读取已经完成封装的 m4a 文件。
        isRecording = false
        let duration = recorder.currentTime
        recorder.stop()
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
