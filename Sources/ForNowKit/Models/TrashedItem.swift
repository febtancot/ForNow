import Foundation

/// 从暂存区移入应用内回收站的项目。真实文件继续保留在受管目录中，直到 30 天到期。
public struct TrashedItem: Identifiable, Codable, Equatable, Sendable {
    public let item: StashItem
    public let trashedAt: Date

    public var id: UUID { item.id }

    public init(item: StashItem, trashedAt: Date) {
        self.item = item
        self.trashedAt = trashedAt
    }
}

/// 恢复操作的结果。内容重复或底层文件缺失的项目留在回收站中。
public struct TrashRestoreResult: Equatable, Sendable {
    public let restored: [StashItem]
    public let duplicates: [StashItem]
    public let missingFiles: [StashItem]

    public init(restored: [StashItem], duplicates: [StashItem], missingFiles: [StashItem]) {
        self.restored = restored
        self.duplicates = duplicates
        self.missingFiles = missingFiles
    }
}
