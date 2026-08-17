import Foundation

/// 回收站元数据的持久化；真实文件仍由 `StashFileStoring` 管理。
public protocol TrashMetadataStoring: AnyObject {
    func load() throws -> [TrashedItem]
    func save(_ items: [TrashedItem]) throws
}

/// 以独立 JSON 文件保存回收站项目及其清除时间。
public final class JSONTrashMetadataStore: TrashMetadataStoring {
    private let fileURL: URL
    private let fileManager: FileManager

    public init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    public func load() throws -> [TrashedItem] {
        guard fileManager.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        guard !data.isEmpty else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([TrashedItem].self, from: data)
    }

    public func save(_ items: [TrashedItem]) throws {
        let directory = fileURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(items).write(to: fileURL, options: .atomic)
    }
}
