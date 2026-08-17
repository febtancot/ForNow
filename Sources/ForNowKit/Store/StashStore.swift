import Foundation
import Combine

/// 暂存内容的内存 + 持久化仓库。数组顺序即界面顺序（index 0 在最上方）。
///
/// - 新加入的一批项目整体插入到顶部，且保持批内原有顺序。
/// - 所有变更立即写盘；移入回收站时保留真实文件，满 30 天后才永久删除。
@MainActor
public final class StashStore: ObservableObject {
    @Published public private(set) var items: [StashItem] = []
    @Published public private(set) var trashItems: [TrashedItem] = []

    private let metadataStore: StashMetadataStoring
    private let trashMetadataStore: TrashMetadataStoring
    private let now: () -> Date
    private let trashRetentionInterval: TimeInterval
    public let fileStorage: StashFileStoring

    public init(metadataStore: StashMetadataStoring,
                trashMetadataStore: TrashMetadataStoring,
                fileStorage: StashFileStoring,
                trashRetentionDays: Int = 30,
                now: @escaping () -> Date = Date.init) {
        self.metadataStore = metadataStore
        self.trashMetadataStore = trashMetadataStore
        self.fileStorage = fileStorage
        self.trashRetentionInterval = TimeInterval(max(1, trashRetentionDays)) * 24 * 60 * 60
        self.now = now
    }

    /// 默认实现：Application Support/ForNow 下的 JSON + Files 目录。
    public static func makeDefault() -> StashStore {
        let metadata = JSONMetadataStore(fileURL: AppPaths.metadataURL())
        let trashMetadata = JSONTrashMetadataStore(fileURL: AppPaths.trashMetadataURL())
        let files = DiskFileStorage(rootDirectory: AppPaths.filesDirectory())
        let store = StashStore(metadataStore: metadata,
                               trashMetadataStore: trashMetadata,
                               fileStorage: files)
        store.load()
        return store
    }

    // MARK: - 读取

    public func load() {
        items = (try? metadataStore.load()) ?? []
        trashItems = ((try? trashMetadataStore.load()) ?? [])
            .sorted { $0.trashedAt > $1.trashedAt }
        // 两份元数据跨文件写入时若进程恰好中断，可能暂时同时出现同一 id。
        // 活动列表优先，避免到期清理误删已恢复文件。
        let activeIDs = Set(items.map(\.id))
        let countBeforeReconciliation = trashItems.count
        trashItems.removeAll { activeIDs.contains($0.id) }
        if trashItems.count != countBeforeReconciliation { persistTrash() }
        purgeExpiredTrash()
        if pinLockedItemsToTop() { persist() }
        backfillContentHashes()
    }

    /// 为缺少内容哈希的历史项目补算哈希并持久化（一次性迁移），
    /// 使去重对去重功能上线前入库的旧文件同样生效。
    private func backfillContentHashes() {
        var changed = false
        for index in items.indices where items[index].contentHash == nil {
            let item = items[index]
            if item.isContentDeduplicatedFile,
               let url = absoluteURL(for: item),
               let hash = ContentHasher.sha256Hex(ofFileAt: url) {
                items[index].contentHash = hash
                changed = true
            }
        }
        if changed { persist() }
    }

    public var count: Int { items.count }

    public var trashCount: Int { trashItems.count }

    public var activeByteSize: Int64 { items.reduce(0) { $0 + ($1.byteSize ?? 0) } }

    public var trashByteSize: Int64 { trashItems.reduce(0) { $0 + ($1.item.byteSize ?? 0) } }

    public var activeByteSizeText: String {
        ByteCountFormatter.string(fromByteCount: activeByteSize, countStyle: .file)
    }

    public var trashByteSizeText: String {
        ByteCountFormatter.string(fromByteCount: trashByteSize, countStyle: .file)
    }

    public var totalByteSize: Int64 { fileStorage.totalByteSize() }

    public var totalByteSizeText: String {
        ByteCountFormatter.string(fromByteCount: totalByteSize, countStyle: .file)
    }

    public func absoluteURL(for item: StashItem) -> URL? {
        guard let relativePath = item.relativePath else { return nil }
        return fileStorage.absoluteURL(for: relativePath)
    }

    /// 若 URL 正是仓库中某个项目的受管文件/目录，则返回该项目。
    /// 这条路径级防线用于阻止把面板里的项目直接拖回面板；目录无需依赖内容哈希。
    public func existingItem(forManagedURL url: URL) -> StashItem? {
        guard url.isFileURL else { return nil }
        let candidate = canonicalFileURL(url)
        let root = canonicalFileURL(fileStorage.rootDirectory)
        guard candidate.path == root.path || candidate.path.hasPrefix(root.path + "/") else { return nil }
        return items.first { item in
            guard let managedURL = absoluteURL(for: item) else { return false }
            return canonicalFileURL(managedURL) == candidate
        }
    }

    // MARK: - 写入（文字 / 链接）

    @discardableResult
    public func addText(_ raw: String) -> StashItem {
        let item = StashItem.makeText(raw)
        insert([item])
        return item
    }

    @discardableResult
    public func addLink(urlString: String, title: String?) -> StashItem {
        let item = StashItem.makeLink(urlString: urlString, title: title)
        insert([item])
        return item
    }

    // MARK: - 写入（文件 / 图片）

    /// 复制一批文件/文件夹进暂存目录，作为一批插入顶部（保持顺序）。失败的逐个跳过并回传错误。
    /// 与已有项目内容相同的文件不重复入库，对应已有项目放入 `duplicates`。
    @discardableResult
    public func addFiles(at urls: [URL]) -> (added: [StashItem], errors: [Error], duplicates: [StashItem]) {
        var created: [StashItem] = []
        var errors: [Error] = []
        var managedDuplicates: [StashItem] = []
        for url in urls {
            if let existing = existingItem(forManagedURL: url) {
                managedDuplicates.append(existing)
                continue
            }
            do {
                created.append(try makeItem(forFileAt: url))
            } catch {
                errors.append(error)
            }
        }
        let duplicates = uniqueItems(managedDuplicates + insert(created))
        // 返回仓库中实际入库的副本（含内容哈希），保持批内顺序。
        let added = created.compactMap { staged in items.first(where: { $0.id == staged.id }) }
        return (added, errors, duplicates)
    }

    /// 将剪贴板/内存中的图片数据写入暂存目录并入库；内容重复时不入库，
    /// `item` 为 nil、对应已有项目放入 `duplicates`。
    @discardableResult
    public func addImageData(_ data: Data, suggestedName: String, fileExtension: String) throws -> (item: StashItem?, duplicates: [StashItem]) {
        let stored = try fileStorage.importData(data, suggestedName: suggestedName, fileExtension: fileExtension)
        let pixelSize = ImageMetadata.pixelSize(ofFileAt: fileStorage.absoluteURL(for: stored.relativePath))
        let item = StashItem.makeImage(stored: stored, pixelSize: pixelSize)
        let duplicates = insert([item])
        let storedItem = duplicates.isEmpty ? items.first(where: { $0.id == item.id }) : nil
        return (storedItem, duplicates)
    }

    /// 将录音数据写入暂存目录并入库（m4a）。
    @discardableResult
    public func addAudio(data: Data, suggestedName: String, durationSeconds: Double) throws -> StashItem {
        let stored = try fileStorage.importData(data, suggestedName: suggestedName, fileExtension: "m4a")
        let item = StashItem.makeAudio(stored: stored, durationSeconds: durationSeconds)
        let duplicates = insert([item])
        return duplicates.first ?? items.first(where: { $0.id == item.id }) ?? item
    }

    // MARK: - 预备项目（复制文件但不插入，供拖入/粘贴时按顺序批量插入）

    /// 复制文件进暂存目录并生成项目，但不插入列表。
    public func stageFile(at url: URL) throws -> StashItem {
        try makeItem(forFileAt: url)
    }

    /// 将图片数据写入暂存目录并生成项目，但不插入列表。
    public func stageImageData(_ data: Data, suggestedName: String, fileExtension: String) throws -> StashItem {
        let stored = try fileStorage.importData(data, suggestedName: suggestedName, fileExtension: fileExtension)
        let pixelSize = ImageMetadata.pixelSize(ofFileAt: fileStorage.absoluteURL(for: stored.relativePath))
        return StashItem.makeImage(stored: stored, pixelSize: pixelSize)
    }

    /// 将音频 provider 的数据表示写入暂存目录，但暂不插入列表。
    public func stageAudioData(_ data: Data, suggestedName: String, fileExtension: String) throws -> StashItem {
        let stored = try fileStorage.importData(data, suggestedName: suggestedName, fileExtension: fileExtension)
        return StashItem.makeAudio(stored: stored, durationSeconds: nil, displayName: stored.originalName)
    }

    private func makeItem(forFileAt url: URL) throws -> StashItem {
        let stored = try fileStorage.importFile(at: url)
        let kind = StashItem.inferredKind(forFileName: stored.originalName, isDirectory: url.hasDirectoryPath)
        switch kind {
        case .image:
            let pixelSize = ImageMetadata.pixelSize(ofFileAt: fileStorage.absoluteURL(for: stored.relativePath))
            return StashItem.makeImage(stored: stored, pixelSize: pixelSize)
        case .audio:
            return StashItem.makeAudio(stored: stored, durationSeconds: nil, displayName: stored.originalName)
        default:
            return StashItem.makeFile(stored: stored)
        }
    }

    // MARK: - 通用插入

    /// 插入一批项目到顶部（保持批内顺序）。文件/图片/音频按内容哈希去重：
    /// 与已有（或本批内）项目内容相同的跳过入库、清理其暂存副本，
    /// 对应的已有项目作为结果返回，供界面提示与高亮。
    @discardableResult
    public func insert(_ newItems: [StashItem]) -> [StashItem] {
        guard !newItems.isEmpty else { return [] }
        var duplicates: [StashItem] = []
        var toAdd: [StashItem] = []
        for var item in newItems {
            if item.isContentDeduplicatedFile, let url = absoluteURL(for: item) {
                let hash = ContentHasher.sha256Hex(ofFileAt: url)
                item.contentHash = hash
                if let hash, let existing = (items + toAdd).first(where: { $0.contentHash == hash }) {
                    if let relativePath = item.relativePath {
                        try? fileStorage.remove(relativePath: relativePath)
                    }
                    duplicates.append(existing)
                    continue
                }
            }
            toAdd.append(item)
        }
        items.insert(contentsOf: toAdd, at: 0)
        pinLockedItemsToTop()
        persist()
        return duplicates
    }

    // MARK: - 回收站（锁定项被跳过，需先解锁）

    /// 将指定项目移入应用内回收站（锁定项跳过），返回实际移动的数量。
    @discardableResult
    public func remove(ids: Set<UUID>) -> Int {
        guard !ids.isEmpty else { return 0 }
        let removedItems = items.filter { ids.contains($0.id) && !$0.locked }
        guard !removedItems.isEmpty else { return 0 }
        let trashedAt = now()
        trashItems.insert(contentsOf: removedItems.map { TrashedItem(item: $0, trashedAt: trashedAt) }, at: 0)
        items.removeAll { ids.contains($0.id) && !$0.locked }
        // 先写回收站再写活动列表；中途退出最多让项目暂时出现两处，load() 会安全归并。
        persistTrash()
        persist()
        return removedItems.count
    }

    @discardableResult
    public func remove(_ item: StashItem) -> Int {
        remove(ids: [item.id])
    }

    /// 将所有未锁定项目移入回收站；锁定项保留在暂存区。
    public func removeAll() {
        let removedItems = items.filter { !$0.locked }
        guard !removedItems.isEmpty else { return }
        let trashedAt = now()
        trashItems.insert(contentsOf: removedItems.map { TrashedItem(item: $0, trashedAt: trashedAt) }, at: 0)
        items.removeAll { !$0.locked }
        persistTrash()
        persist()
    }

    /// 从回收站恢复到暂存区顶部。若同内容文件已存在或底层文件丢失，该项目保持在回收站。
    @discardableResult
    public func restoreFromTrash(ids: Set<UUID>) -> TrashRestoreResult {
        purgeExpiredTrash()
        guard !ids.isEmpty else {
            return TrashRestoreResult(restored: [], duplicates: [], missingFiles: [])
        }

        var hashes = Set(items.compactMap(\.contentHash))
        var restored: [StashItem] = []
        var duplicates: [StashItem] = []
        var missingFiles: [StashItem] = []

        for entry in trashItems where ids.contains(entry.id) {
            let item = entry.item
            if let relativePath = item.relativePath,
               !FileManager.default.fileExists(atPath: fileStorage.absoluteURL(for: relativePath).path) {
                missingFiles.append(item)
                continue
            }
            if item.isContentDeduplicatedFile,
               let hash = item.contentHash,
               hashes.contains(hash) {
                duplicates.append(item)
                continue
            }
            restored.append(item)
            if let hash = item.contentHash { hashes.insert(hash) }
        }

        if !restored.isEmpty {
            let restoredIDs = Set(restored.map(\.id))
            trashItems.removeAll { restoredIDs.contains($0.id) }
            items.insert(contentsOf: restored, at: 0)
            pinLockedItemsToTop()
            // 恢复时先写活动列表；中途退出由 load() 以活动列表为准归并。
            persist()
            persistTrash()
        }
        return TrashRestoreResult(restored: restored,
                                  duplicates: duplicates,
                                  missingFiles: missingFiles)
    }

    /// 永久清理已在回收站保留满 30 天的项目及其受管文件。
    @discardableResult
    public func purgeExpiredTrash(referenceDate: Date? = nil) -> Int {
        let cutoff = (referenceDate ?? now()).addingTimeInterval(-trashRetentionInterval)
        let expired = trashItems.filter { $0.trashedAt <= cutoff }
        guard !expired.isEmpty else { return 0 }
        for entry in expired {
            if let relativePath = entry.item.relativePath {
                try? fileStorage.remove(relativePath: relativePath)
            }
        }
        let expiredIDs = Set(expired.map(\.id))
        trashItems.removeAll { expiredIDs.contains($0.id) }
        persistTrash()
        return expired.count
    }

    // MARK: - 锁定

    /// 设置一批项目的锁定状态（锁定项不受清空与删除影响）。
    public func setLocked(_ locked: Bool, for ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        for index in items.indices where ids.contains(items[index].id) {
            items[index].locked = locked
        }
        pinLockedItemsToTop()
        persist()
    }

    // MARK: - 私有

    private func persist() {
        try? metadataStore.save(items)
    }

    private func persistTrash() {
        try? trashMetadataStore.save(trashItems)
    }

    private func canonicalFileURL(_ url: URL) -> URL {
        url.standardizedFileURL.resolvingSymlinksInPath()
    }

    private func uniqueItems(_ candidates: [StashItem]) -> [StashItem] {
        var seen: Set<UUID> = []
        return candidates.filter { seen.insert($0.id).inserted }
    }

    /// 稳定分区：锁定项目永远位于列表顶部，两个分区内继续保持原有相对顺序。
    @discardableResult
    private func pinLockedItemsToTop() -> Bool {
        let ordered = items.filter(\.locked) + items.filter { !$0.locked }
        guard ordered.map(\.id) != items.map(\.id) else { return false }
        items = ordered
        return true
    }
}

extension StashItem {
    var isContentDeduplicatedFile: Bool {
        kind == .file || kind == .image || kind == .audio
    }
}
