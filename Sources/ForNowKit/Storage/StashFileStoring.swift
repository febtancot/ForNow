import Foundation

public enum FileStorageError: LocalizedError, Equatable {
    case sourceUnreadable(String)
    case copyFailed(String)
    case outOfSpace

    public var errorDescription: String? {
        switch self {
        case .sourceUnreadable(let name): return "无法读取原文件“\(name)”。"
        case .copyFailed(let reason): return "复制文件失败：\(reason)"
        case .outOfSpace: return "磁盘空间不足，无法暂存。"
        }
    }
}

/// 管理暂存目录中真实文件的复制、定位与删除。
public protocol StashFileStoring: AnyObject {
    var rootDirectory: URL { get }

    /// 将外部文件/文件夹复制进暂存目录。
    func importFile(at sourceURL: URL) throws -> StoredFile

    /// 将内存数据（如剪贴板图片）写入暂存目录。
    func importData(_ data: Data, suggestedName: String, fileExtension: String) throws -> StoredFile

    /// 由相对路径得到绝对 URL。
    func absoluteURL(for relativePath: String) -> URL

    /// 删除某个项目对应的存储（含其 uuid 子目录）。
    func remove(relativePath: String) throws

    /// 清空整个暂存目录。
    func removeAll() throws

    /// 暂存目录当前占用字节数。
    func totalByteSize() -> Int64
}
