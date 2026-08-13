import Foundation
import CoreGraphics
import UniformTypeIdentifiers

/// 一个暂存项目。为便于 Codable 持久化与测试，采用带 `kind` 判别字段的扁平结构，
/// 各类型专属字段以可选值表示，并通过工厂方法保证不变量。
public struct StashItem: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var kind: StashItemKind
    /// 界面主标题：文件/图片为原文件名；文字为前两行摘要；链接为标题或域名。
    public var displayName: String
    public var createdAt: Date

    // MARK: 文件 / 图片
    /// 相对 `FileStorage.rootDirectory` 的路径，形如 `<uuid>/<原文件名>`。
    public var relativePath: String?
    public var byteSize: Int64?
    public var originalFileName: String?

    // MARK: 图片
    public var pixelWidth: Int?
    public var pixelHeight: Int?

    // MARK: 文字
    public var text: String?

    // MARK: 链接
    public var urlString: String?
    public var linkTitle: String?

    public init(id: UUID = UUID(),
                kind: StashItemKind,
                displayName: String,
                createdAt: Date = Date(),
                relativePath: String? = nil,
                byteSize: Int64? = nil,
                originalFileName: String? = nil,
                pixelWidth: Int? = nil,
                pixelHeight: Int? = nil,
                text: String? = nil,
                urlString: String? = nil,
                linkTitle: String? = nil) {
        self.id = id
        self.kind = kind
        self.displayName = displayName
        self.createdAt = createdAt
        self.relativePath = relativePath
        self.byteSize = byteSize
        self.originalFileName = originalFileName
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.text = text
        self.urlString = urlString
        self.linkTitle = linkTitle
    }
}

// MARK: - 工厂方法

public extension StashItem {
    static func makeText(_ raw: String, createdAt: Date = Date(), id: UUID = UUID()) -> StashItem {
        StashItem(id: id, kind: .text, displayName: summary(from: raw), createdAt: createdAt, text: raw)
    }

    static func makeLink(urlString: String, title: String?, createdAt: Date = Date(), id: UUID = UUID()) -> StashItem {
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let name: String
        if let t = trimmedTitle, !t.isEmpty {
            name = t
        } else if let host = URL(string: urlString)?.host {
            name = host
        } else {
            name = urlString
        }
        return StashItem(id: id, kind: .link, displayName: name, createdAt: createdAt,
                         urlString: urlString, linkTitle: trimmedTitle)
    }

    static func makeFile(stored: StoredFile, createdAt: Date = Date(), id: UUID = UUID()) -> StashItem {
        StashItem(id: id, kind: .file, displayName: stored.originalName, createdAt: createdAt,
                  relativePath: stored.relativePath, byteSize: stored.byteSize,
                  originalFileName: stored.originalName)
    }

    static func makeImage(stored: StoredFile, pixelSize: CGSize?, createdAt: Date = Date(), id: UUID = UUID()) -> StashItem {
        StashItem(id: id, kind: .image, displayName: stored.originalName, createdAt: createdAt,
                  relativePath: stored.relativePath, byteSize: stored.byteSize,
                  originalFileName: stored.originalName,
                  pixelWidth: pixelSize.map { Int($0.width.rounded()) },
                  pixelHeight: pixelSize.map { Int($0.height.rounded()) })
    }

    /// 文字项目取前两行非空内容、去空白，作为界面摘要。
    static func summary(from raw: String) -> String {
        let nonEmptyLines = raw
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let joined = nonEmptyLines.prefix(2).joined(separator: " ")
        let condensed = joined.isEmpty
            ? raw.trimmingCharacters(in: .whitespacesAndNewlines)
            : joined
        return String(condensed.prefix(120))
    }

    /// 依据扩展名判断文件是图片还是普通文件；目录一律按文件处理。
    static func inferredKind(forFileName name: String, isDirectory: Bool) -> StashItemKind {
        if isDirectory { return .file }
        let ext = (name as NSString).pathExtension
        if !ext.isEmpty, let type = UTType(filenameExtension: ext), type.conforms(to: .image) {
            return .image
        }
        return .file
    }
}

// MARK: - 展示辅助

public extension StashItem {
    /// 图片尺寸文案，如 "1920 × 1080"。
    var pixelSizeText: String? {
        guard let w = pixelWidth, let h = pixelHeight else { return nil }
        return "\(w) × \(h)"
    }

    /// 人类可读的大小文案，如 "1.2 MB"。
    var byteSizeText: String? {
        guard let bytes = byteSize else { return nil }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
