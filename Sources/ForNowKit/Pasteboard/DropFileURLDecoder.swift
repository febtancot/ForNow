import AppKit
import Foundation
import UniformTypeIdentifiers

/// 从拖放 provider 中优先解析真实文件 URL。文件 URL 必须先于 String 读取，
/// 因为 Finder 的文本文件通常同时提供 `public.file-url` 和 `public.text`。
public enum DropFileURLLoader {
    public static func load(from provider: NSItemProvider) async -> URL? {
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier),
           let fileURL = await loadFileURLRepresentation(from: provider) {
            return fileURL
        }
        guard provider.canLoadObject(ofClass: URL.self) else { return nil }
        return await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                continuation.resume(returning: url)
            }
        }
    }

    private static func loadFileURLRepresentation(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url: URL?
                switch item {
                case let value as URL:
                    url = value
                case let value as NSURL:
                    url = value as URL
                case let value as Data:
                    url = DropFileURLDecoder.decode(value)
                case let value as String:
                    url = DropFileURLDecoder.decode(value)
                case let value as NSString:
                    url = DropFileURLDecoder.decode(value as String)
                default:
                    url = nil
                }
                continuation.resume(returning: url?.isFileURL == true ? url : nil)
            }
        }
    }
}

/// 解码 `NSItemProvider` 的 `public.file-url` data representation。
/// Finder 通常以 UTF-8 URL 字符串提供；部分来源会包装成 property list。
public enum DropFileURLDecoder {
    public static func decode(_ data: Data) -> URL? {
        if let value = try? PropertyListSerialization.propertyList(from: data, format: nil),
           let string = value as? String,
           let url = fileURL(from: string) {
            return url
        }
        return fileURL(from: String(decoding: data, as: UTF8.self))
    }

    public static func decode(_ string: String) -> URL? {
        fileURL(from: string)
    }

    private static func fileURL(from rawValue: String) -> URL? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines.union(.controlCharacters))
        guard let url = URL(string: value), url.isFileURL else { return nil }
        return url
    }
}
