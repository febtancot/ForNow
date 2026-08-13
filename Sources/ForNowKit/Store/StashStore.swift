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
    @discardableResult
    public func addFiles(at urls: [URL]) -> (added: [StashItem], errors: [Error]) {
        var created: [StashItem] = []
        var errors: [Error] = []
        for url in urls {
            do {
                created.append(try makeItem(forFileAt: url))
            } catch {
                errors.append(error)
            }
        }
        insert(created)
        return (created, errors)
    }

    /// 将剪贴板/内存中的图片数据写入暂存目录并入库。
    @discardableResult
    public func addImageData(_ data: Data, suggestedName: String, fileExtension: String) throws -> StashItem {
        let stored = try fileStorage.importData(data, suggestedName: suggestedName, fileExtension: fileExtension)
        let pixelSize = ImageMetadata.pixelSize(ofFileAt: fileStorage.absoluteURL(for: stored.relativePath))
        let item = StashItem.makeImage(stored: stored, pixelSize: pixelSize)
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

    public func insert(_ newItems: [StashItem]) {
        guard !newItems.isEmpty else { return }
        items.insert(contentsOf: newItems, at: 0)
        persist()
    }

    // MARK: - 删除

    public func remove(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        for item in items where ids.contains(item.id) {
            if let relativePath = item.relativePath {
                try? fileStorage.remove(relativePath: relativePath)
            }
        }
        items.removeAll { ids.contains($0.id) }
        persist()
    }

    public func remove(_ item: StashItem) {
        remove(ids: [item.id])
    }

    public func removeAll() {
        try? fileStorage.removeAll()
        items.removeAll()
        persist()
    }

    // MARK: - 私有

    private func persist() {
        try? metadataStore.save(items)
    }
}
