import Foundation

/// 暂存项目元数据的持久化（不含真实文件字节）。
public protocol StashMetadataStoring: AnyObject {
    func load() throws -> [StashItem]
    func save(_ items: [StashItem]) throws
}

/// 以本地 JSON 文件保存元数据。满足"本地、不上云、重启后仍在"。
public final class JSONMetadataStore: StashMetadataStoring {
    private let fileURL: URL
    private let fileManager: FileManager

    public init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    public func load() throws -> [StashItem] {
        guard fileManager.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        guard !data.isEmpty else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([StashItem].self, from: data)
    }

    public func save(_ items: [StashItem]) throws {
        let directory = fileURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(items)
        try data.write(to: fileURL, options: .atomic)
    }
}
