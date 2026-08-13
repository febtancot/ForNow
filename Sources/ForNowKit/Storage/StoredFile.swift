import Foundation

/// 文件被复制进暂存目录后的描述。
public struct StoredFile: Equatable, Sendable {
    /// 相对 `StashFileStoring.rootDirectory` 的路径，形如 `<uuid>/<原文件名>`。
    public let relativePath: String
    public let byteSize: Int64
    /// 原始文件名（界面展示用）。
    public let originalName: String

    public init(relativePath: String, byteSize: Int64, originalName: String) {
        self.relativePath = relativePath
        self.byteSize = byteSize
        self.originalName = originalName
    }
}
