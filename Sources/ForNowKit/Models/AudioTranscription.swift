import Foundation

/// 与录音一起持久化，不占用用户备注，也不截断长转写。
public struct AudioTranscription: Codable, Equatable, Sendable {
    public enum Status: String, Codable, Sendable {
        case queued, preparing, transcribing, completed, noSpeech, failed, unavailable, interrupted

        public var isInProgress: Bool {
            self == .queued || self == .preparing || self == .transcribing
        }
    }

    public var status: Status
    public var localeIdentifier: String
    public var text: String?
    public var message: String?

    public init(status: Status, localeIdentifier: String, text: String? = nil, message: String? = nil) {
        self.status = status
        self.localeIdentifier = localeIdentifier
        self.text = text
        self.message = message
    }

    public var statusText: String {
        switch status {
        case .queued: return "等待本地转写"
        case .preparing: return "正在准备语言模型，首次可能需要下载"
        case .transcribing: return "正在本地转写"
        case .completed: return "本地转写完成"
        case .noSpeech: return "未识别到语音，可更换语言后重试"
        case .failed: return message ?? "转写失败，可重试"
        case .unavailable: return message ?? "当前设备不支持本地转写"
        case .interrupted: return "转写已中断，可重试"
        }
    }
}
