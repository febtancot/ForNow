import Foundation

/// 基于本地磁盘的文件暂存实现。
///
/// 每个导入的文件放入一个以 UUID 命名的子目录中，保留其原始文件名：
/// `<root>/<uuid>/<原文件名>`。这样既保证内部唯一（满足重名处理要求），
/// 又能在拖出时还原原始文件名。
public final class DiskFileStorage: StashFileStoring {
    public let rootDirectory: URL
    private let fileManager: FileManager

    public init(rootDirectory: URL, fileManager: FileManager = .default) {
        self.rootDirectory = rootDirectory
        self.fileManager = fileManager
    }

    @discardableResult
    private func ensureRoot() throws -> URL {
        if !fileManager.fileExists(atPath: rootDirectory.path) {
            try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        }
        return rootDirectory
    }

    public func importFile(at sourceURL: URL) throws -> StoredFile {
        guard fileManager.isReadableFile(atPath: sourceURL.path) else {
            throw FileStorageError.sourceUnreadable(sourceURL.lastPathComponent)
        }
        try ensureRoot()

        let originalName = sourceURL.lastPathComponent
        let destDir = try makeItemDirectory()
        let destURL = destDir.appendingPathComponent(originalName)
        do {
            try fileManager.copyItem(at: sourceURL, to: destURL)
        } catch {
            // 复制失败时清理空目录，避免残留。
            try? fileManager.removeItem(at: destDir)
            throw FileStorageError.copyFailed(error.localizedDescription)
        }
        let size = Self.byteSize(of: destURL, fileManager: fileManager)
        return StoredFile(relativePath: destDir.lastPathComponent + "/" + originalName,
                          byteSize: size, originalName: originalName)
    }

    public func importData(_ data: Data, suggestedName: String, fileExtension: String) throws -> StoredFile {
        try ensureRoot()

        var name = suggestedName.isEmpty ? "未命名" : suggestedName
        let ext = fileExtension.trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        if !ext.isEmpty, (name as NSString).pathExtension.lowercased() != ext.lowercased() {
            name += "." + ext
        }
        let destDir = try makeItemDirectory()
        let destURL = destDir.appendingPathComponent(name)
        do {
            try data.write(to: destURL, options: .atomic)
        } catch {
            try? fileManager.removeItem(at: destDir)
            throw FileStorageError.copyFailed(error.localizedDescription)
        }
        return StoredFile(relativePath: destDir.lastPathComponent + "/" + name,
                          byteSize: Int64(data.count), originalName: name)
    }

    public func absoluteURL(for relativePath: String) -> URL {
        rootDirectory.appendingPathComponent(relativePath)
    }

    public func remove(relativePath: String) throws {
        let fileURL = absoluteURL(for: relativePath)
        let folderURL = fileURL.deletingLastPathComponent()
        // 删除项目所在的 uuid 子目录；防御性地避免误删 root。
        if folderURL != rootDirectory, fileManager.fileExists(atPath: folderURL.path) {
            try fileManager.removeItem(at: folderURL)
        } else if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }

    public func removeAll() throws {
        guard fileManager.fileExists(atPath: rootDirectory.path) else { return }
        for url in try fileManager.contentsOfDirectory(at: rootDirectory, includingPropertiesForKeys: nil) {
            try fileManager.removeItem(at: url)
        }
    }

    public func totalByteSize() -> Int64 {
        Self.byteSize(of: rootDirectory, fileManager: fileManager)
    }

    // MARK: - Helpers

    private func makeItemDirectory() throws -> URL {
        let dir = rootDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// 递归统计文件或目录的总字节数。
    static func byteSize(of url: URL, fileManager: FileManager) -> Int64 {
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }
        if isDir.boolValue {
            var total: Int64 = 0
            if let enumerator = fileManager.enumerator(at: url,
                                                       includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]) {
                for case let child as URL in enumerator {
                    let values = try? child.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                    if values?.isRegularFile == true {
                        total += Int64(values?.fileSize ?? 0)
                    }
                }
            }
            return total
        }
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(values?.fileSize ?? 0)
    }
}
