import Foundation
import Combine

/// 暂存内容的内存 + 持久化仓库。数组顺序即界面顺序（index 0 在最上方）。
///
/// - 新加入的一批项目整体插入到顶部，且保持批内原有顺序。
/// - 所有变更立即写盘（元数据）并同步真实文件的复制/删除。
@MainActor
public final class StashStore: ObservableObject {
    @Published public private(set) var items: [StashItem] = []

    private let metadataStore: StashMetadataStoring
    public let fileStorage: StashFileStoring

    public init(metadataStore: StashMetadataStoring, fileStorage: StashFileStoring) {
        self.metadataStore = metadataStore
        self.fileStorage = fileStorage
    }

    /// 默认实现：Application Support/ForNow 下的 JSON + Files 目录。
    public static func makeDefault() -> StashStore {
        let metadata = JSONMetadataStore(fileURL: AppPaths.metadataURL())
        let files = DiskFileStorage(rootDirectory: AppPaths.filesDirectory())
        let store = StashStore(metadataStore: metadata, fileStorage: files)
        store.load()
        return store
    }

    // MARK: - 读取

    public func load() {
        items = (try? metadataStore.load()) ?? []
        backfillContentHashes()
    }

    /// 为缺少内容哈希的历史项目补算哈希并持久化（一次性迁移），
    /// 使去重对去重功能上线前入库的旧文件同样生效。
    private func backfillContentHashes() {
        var changed = false
        for index in items.indices where items[index].contentHash == nil {
            let item = items[index]
            if item.kind == .file || item.kind == .image,
               let url = absoluteURL(for: item),
               let hash = ContentHasher.sha256Hex(ofFileAt: url) {
                items[index].contentHash = hash
                changed = true
            }
        }
        if changed { persist() }
    }

    public var count: Int { items.count }

    public var totalByteSize: Int64 { fileStorage.totalByteSize() }

    public var totalByteSizeText: String {
        ByteCountFormatter.string(fromByteCount: totalByteSize, countStyle: .file)
    }

    public func absoluteURL(for item: StashItem) -> URL? {
        guard let relativePath = item.relativePath else { return nil }
        return fileStorage.absoluteURL(for: relativePath)
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
        for url in urls {
            do {
                created.append(try makeItem(forFileAt: url))
            } catch {
                errors.append(error)
            }
        }
        let duplicates = insert(created)
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
        insert([item])
        return item
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

    private func makeItem(forFileAt url: URL) throws -> StashItem {
        let stored = try fileStorage.importFile(at: url)
        let kind = StashItem.inferredKind(forFileName: stored.originalName, isDirectory: url.hasDirectoryPath)
        switch kind {
        case .image:
            let pixelSize = ImageMetadata.pixelSize(ofFileAt: fileStorage.absoluteURL(for: stored.relativePath))
            return StashItem.makeImage(stored: stored, pixelSize: pixelSize)
        default:
            return StashItem.makeFile(stored: stored)
        }
    }

    // MARK: - 通用插入

    /// 插入一批项目到顶部（保持批内顺序）。文件/图片按内容哈希去重：
    /// 与已有（或本批内）项目内容相同的跳过入库、清理其暂存副本，
    /// 对应的已有项目作为结果返回，供界面提示与高亮。
    @discardableResult
    public func insert(_ newItems: [StashItem]) -> [StashItem] {
        guard !newItems.isEmpty else { return [] }
        var duplicates: [StashItem] = []
        var toAdd: [StashItem] = []
        for var item in newItems {
            if item.kind == .file || item.kind == .image, let url = absoluteURL(for: item) {
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
        persist()
        return duplicates
    }

    // MARK: - 删除（锁定项被跳过，需先解锁）

    /// 删除指定项目（锁定项跳过），返回实际删除的数量。
    @discardableResult
    public func remove(ids: Set<UUID>) -> Int {
        guard !ids.isEmpty else { return 0 }
        var removed = 0
        for item in items where ids.contains(item.id) && !item.locked {
            if let relativePath = item.relativePath {
                try? fileStorage.remove(relativePath: relativePath)
            }
            removed += 1
        }
        items.removeAll { ids.contains($0.id) && !$0.locked }
        persist()
        return removed
    }

    @discardableResult
    public func remove(_ item: StashItem) -> Int {
        remove(ids: [item.id])
    }

    /// 清空所有未锁定项目；锁定项及其文件保留。
    public func removeAll() {
        for item in items where !item.locked {
            if let relativePath = item.relativePath {
                try? fileStorage.remove(relativePath: relativePath)
            }
        }
        items.removeAll { !$0.locked }
        persist()
    }

    // MARK: - 锁定

    /// 设置一批项目的锁定状态（锁定项不受清空与删除影响）。
    public func setLocked(_ locked: Bool, for ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        for index in items.indices where ids.contains(items[index].id) {
            items[index].locked = locked
        }
        persist()
    }

    // MARK: - 私有

    private func persist() {
        try? metadataStore.save(items)
    }
}
