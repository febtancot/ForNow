import Foundation

/// 归类后的剪贴板内容。
public enum PasteboardContent: Equatable {
    case files([URL])
    case image(data: Data, fileExtension: String)
    case link(url: String, title: String?)
    case text(String)
    case empty
}

/// 对剪贴板的最小读取抽象，便于注入测试。
public protocol PasteboardReading {
    func fileURLs() -> [URL]
    func imageData() -> (data: Data, fileExtension: String)?
    func webURL() -> String?
    func plainText() -> String?
}

public enum PasteboardImporter {
    /// 剪贴板内容归类。优先级（PRD §7）：文件 > 图片 > 链接 > 富文本/纯文本。
    public static func classify(_ reader: PasteboardReading) -> PasteboardContent {
        let files = reader.fileURLs()
        if !files.isEmpty {
            return .files(files)
        }
        if let image = reader.imageData() {
            return .image(data: image.data, fileExtension: image.fileExtension)
        }
        if let url = reader.webURL(), !url.isEmpty {
            return .link(url: url, title: nil)
        }
        if let text = reader.plainText(),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .text(text)
        }
        return .empty
    }
}
