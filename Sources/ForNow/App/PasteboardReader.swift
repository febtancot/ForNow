import AppKit
import ForNowKit

/// 从 `NSPasteboard` 读取内容，供 `PasteboardImporter` 归类。
struct NSPasteboardReader: PasteboardReading {
    let pasteboard: NSPasteboard

    init(_ pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    func fileURLs() -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] ?? []
        return urls.filter { $0.isFileURL }
    }

    func imageData() -> (data: Data, fileExtension: String)? {
        if let data = pasteboard.data(forType: .png) {
            return (data, "png")
        }
        if let tiff = pasteboard.data(forType: .tiff) {
            // 统一转成 PNG，便于通用与拖出。
            if let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                return (png, "png")
            }
            return (tiff, "tiff")
        }
        return nil
    }

    func webURL() -> String? {
        if let url = NSURL(from: pasteboard) as URL?, !url.isFileURL {
            return url.absoluteString
        }
        // 纯文本恰好是 http(s) 链接时也视为链接。
        if let string = pasteboard.string(forType: .string) {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(),
               scheme == "http" || scheme == "https" {
                return url.absoluteString
            }
        }
        return nil
    }

    func plainText() -> String? {
        pasteboard.string(forType: .string)
    }
}

/// 将归类后的剪贴板内容写入仓库。
@MainActor
enum PasteboardCommit {
    /// - Returns: 是否有内容被添加。
    @discardableResult
    static func commit(_ content: PasteboardContent, to store: StashStore) -> Bool {
        switch content {
        case .files(let urls):
            return !store.addFiles(at: urls).added.isEmpty
        case .image(let data, let ext):
            return (try? store.addImageData(data, suggestedName: "剪贴板图片", fileExtension: ext)) != nil
        case .link(let url, let title):
            store.addLink(urlString: url, title: title)
            return true
        case .text(let text):
            store.addText(text)
            return true
        case .empty:
            return false
        }
    }
}
