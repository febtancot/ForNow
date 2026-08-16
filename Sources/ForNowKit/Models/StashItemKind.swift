import Foundation

/// 暂存项目的内容类型。优先级顺序见剪贴板归类：文件 > 图片 > 链接 > 富文本 > 纯文本。
public enum StashItemKind: String, Codable, Sendable, CaseIterable {
    case file
    case image
    case text
    case link
    case audio

    /// SF Symbol 名称，供列表图标使用。
    public var symbolName: String {
        switch self {
        case .file: return "doc"
        case .image: return "photo"
        case .text: return "text.alignleft"
        case .link: return "link"
        case .audio: return "waveform"
        }
    }

    /// 中文可读名称，供 VoiceOver 与界面使用。
    public var localizedName: String {
        switch self {
        case .file: return "文件"
        case .image: return "图片"
        case .text: return "文字"
        case .link: return "链接"
        case .audio: return "录音"
        }
    }
}
