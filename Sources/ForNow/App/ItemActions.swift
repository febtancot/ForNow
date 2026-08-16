import AppKit
import ForNowKit

/// 单个暂存项目的取出操作：复制、打开、在 Finder 显示、拖出。
@MainActor
enum ItemActions {
    static func copyToPasteboard(_ item: StashItem, store: StashStore) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        switch item.kind {
        case .file, .image:
            if let url = store.absoluteURL(for: item) {
                pasteboard.writeObjects([url as NSURL])
            }
        case .text:
            pasteboard.setString(item.text ?? item.displayName, forType: .string)
        case .link:
            if let string = item.urlString {
                pasteboard.setString(string, forType: .string)
                if let url = URL(string: string) {
                    pasteboard.writeObjects([url as NSURL])
                }
            }
        }
    }

    /// 一次复制多个项目：文件/图片写文件 URL，链接写 URL，文字写字符串。
    static func copyItems(_ items: [StashItem], store: StashStore) {
        guard !items.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        var objects: [NSPasteboardWriting] = []
        for item in items {
            switch item.kind {
            case .file, .image:
                if let url = store.absoluteURL(for: item) { objects.append(url as NSURL) }
            case .link:
                if let string = item.urlString, let url = URL(string: string) {
                    objects.append(url as NSURL)
                } else if let string = item.urlString {
                    objects.append(string as NSString)
                }
            case .text:
                objects.append((item.text ?? item.displayName) as NSString)
            }
        }
        if !objects.isEmpty {
            pasteboard.writeObjects(objects)
        }
    }

    static func open(_ item: StashItem, store: StashStore) {
        switch item.kind {
        case .file, .image:
            if let url = store.absoluteURL(for: item) {
                NSWorkspace.shared.open(url)
            }
        case .link:
            if let string = item.urlString, let url = URL(string: string) {
                NSWorkspace.shared.open(url)
            }
        case .text:
            break
        }
    }

    static func revealInFinder(_ item: StashItem, store: StashStore) {
        if let url = store.absoluteURL(for: item) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    /// 拖出用的 provider。文件/图片提供文件 URL（拖入 Finder / 上传区）；文字/链接提供对应对象。
    static func dragProvider(_ item: StashItem, store: StashStore) -> NSItemProvider {
        switch item.kind {
        case .file, .image:
            if let url = store.absoluteURL(for: item), let provider = NSItemProvider(contentsOf: url) {
                return provider
            }
            return NSItemProvider()
        case .text:
            return textDragProvider(for: item)
        case .link:
            if let string = item.urlString, let url = URL(string: string) {
                return NSItemProvider(object: url as NSURL)
            }
            return NSItemProvider(object: (item.urlString ?? item.displayName) as NSString)
        }
    }

    /// 文字拖出：同时提供 .txt 文件（拖入 Finder 得到文本文件，而非二进制 textClipping）
    /// 与纯文本（拖入文本框直接插入文字）。
    private static func textDragProvider(for item: StashItem) -> NSItemProvider {
        let text = item.text ?? item.displayName
        guard let fileURL = makeTempTextFile(named: item.txtFileName, id: item.id, contents: text) else {
            return NSItemProvider(object: text as NSString)
        }
        let provider = NSItemProvider(contentsOf: fileURL) ?? NSItemProvider()
        provider.registerObject(text as NSString, visibility: .all)
        return provider
    }

    private static func makeTempTextFile(named name: String, id: UUID, contents: String) -> URL? {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ForNowDrag/\(id.uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent(name)
            try Data(contents.utf8).write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
