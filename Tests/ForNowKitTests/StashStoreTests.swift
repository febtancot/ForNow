import XCTest
@testable import ForNowKit

@MainActor
final class StashStoreTests: XCTestCase {
    private var tempRoot: URL!
    private var metadataURL: URL!
    private var trashMetadataURL: URL!
    private var filesDir: URL!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("ForNowTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        metadataURL = tempRoot.appendingPathComponent("metadata.json")
        trashMetadataURL = tempRoot.appendingPathComponent("trash.json")
        filesDir = tempRoot.appendingPathComponent("Files", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    private func makeStore(now: @escaping () -> Date = Date.init) -> StashStore {
        StashStore(metadataStore: JSONMetadataStore(fileURL: metadataURL),
                   trashMetadataStore: JSONTrashMetadataStore(fileURL: trashMetadataURL),
                   fileStorage: DiskFileStorage(rootDirectory: filesDir),
                   now: now)
    }

    // MARK: 文字 / 链接

    func testAddTextAppearsAtTop() {
        let store = makeStore()
        store.addText("hello")
        store.addText("world")
        XCTAssertEqual(store.items.count, 2)
        XCTAssertEqual(store.items.first?.text, "world") // 最新在最上方
        XCTAssertEqual(store.items.first?.kind, .text)
    }

    func testTextSummaryUsesFirstTwoLines() {
        let store = makeStore()
        let item = store.addText("line1\nline2\nline3")
        XCTAssertEqual(item.displayName, "line1 line2")
    }

    func testAddLinkPrefersTitleThenHost() {
        let store = makeStore()
        let a = store.addLink(urlString: "https://example.com/page", title: "Example Title")
        XCTAssertEqual(a.displayName, "Example Title")
        let b = store.addLink(urlString: "https://only.host/x", title: nil)
        XCTAssertEqual(b.displayName, "only.host")
    }

    // MARK: 文件

    func testBatchInsertPreservesOrder() throws {
        let store = makeStore()
        let f1 = try makeSourceFile(named: "a.txt", contents: "a")
        let f2 = try makeSourceFile(named: "b.txt", contents: "bb")
        let result = store.addFiles(at: [f1, f2])
        XCTAssertEqual(result.added.count, 2)
        XCTAssertTrue(result.errors.isEmpty)
        // 同一批加入的多个项目应保持原有顺序（a 在 b 之上）。
        XCTAssertEqual(store.items.map(\.displayName), ["a.txt", "b.txt"])
    }

    func testFileCopiedIntoStorageWithSizeAndOriginalName() throws {
        let store = makeStore()
        let f = try makeSourceFile(named: "note.txt", contents: "12345")
        let result = store.addFiles(at: [f])
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertTrue(result.duplicates.isEmpty)
        let item = try XCTUnwrap(result.added.first)
        XCTAssertEqual(item.kind, .file)
        XCTAssertEqual(item.byteSize, 5)
        XCTAssertEqual(item.originalFileName, "note.txt")
        XCTAssertNotNil(item.contentHash) // 入库时计算内容哈希，供去重
        let url = try XCTUnwrap(store.absoluteURL(for: item))
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testDuplicateNamesGetUniqueStorageButShowOriginalName() throws {
        let store = makeStore()
        let f1 = try makeSourceFile(named: "dup.txt", contents: "one")
        let f2 = try makeSourceFile(named: "dup.txt", contents: "two", subfolder: "sub")
        let result = store.addFiles(at: [f1, f2])
        XCTAssertEqual(result.added.count, 2)
        XCTAssertEqual(Set(result.added.map(\.displayName)), ["dup.txt"])       // 界面仍显示原名
        XCTAssertNotEqual(result.added[0].relativePath, result.added[1].relativePath)  // 内部唯一
        for item in result.added {
            let url = try XCTUnwrap(store.absoluteURL(for: item))
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        }
    }

    func testUnreadableSourceProducesError() {
        let store = makeStore()
        let missing = tempRoot.appendingPathComponent("does-not-exist.txt")
        let result = store.addFiles(at: [missing])
        XCTAssertTrue(result.added.isEmpty)
        XCTAssertEqual(result.errors.count, 1)
    }

    // MARK: 去重

    func testAddingSameFileTwiceSkipsDuplicate() throws {
        let store = makeStore()
        let f = try makeSourceFile(named: "dup.txt", contents: "same")

        let first = store.addFiles(at: [f])
        XCTAssertEqual(first.added.count, 1)
        XCTAssertTrue(first.duplicates.isEmpty)

        let second = store.addFiles(at: [f])
        XCTAssertTrue(second.added.isEmpty)
        XCTAssertEqual(second.duplicates.map(\.id), [first.added[0].id]) // 返回已有项目供高亮
        XCTAssertEqual(store.items.count, 1)
        XCTAssertNotNil(store.items.first?.contentHash)
    }

    func testSameNameSameSizeDifferentContentIsNotDuplicate() throws {
        let store = makeStore()
        let a = try makeSourceFile(named: "same.txt", contents: "aaaa")
        let b = try makeSourceFile(named: "same.txt", contents: "bbbb", subfolder: "sub")

        XCTAssertEqual(store.addFiles(at: [a]).added.count, 1)
        let second = store.addFiles(at: [b])
        XCTAssertEqual(second.added.count, 1)
        XCTAssertTrue(second.duplicates.isEmpty)
        XCTAssertEqual(store.items.count, 2)
    }

    func testDuplicateInSameBatchKeepsOneAndCleansOrphanCopy() throws {
        let store = makeStore()
        let a = try makeSourceFile(named: "x.txt", contents: "data")
        let b = try makeSourceFile(named: "x.txt", contents: "data", subfolder: "sub")

        let result = store.addFiles(at: [a, b])
        XCTAssertEqual(result.added.count, 1)
        XCTAssertEqual(result.duplicates.count, 1)
        XCTAssertEqual(store.items.count, 1)
        // 被跳过的重复项，其暂存副本应被清理（Files 下只剩 1 个 uuid 目录）。
        let stored = try FileManager.default.contentsOfDirectory(at: filesDir, includingPropertiesForKeys: nil)
        XCTAssertEqual(stored.count, 1)
    }

    func testDraggingManagedDirectoryBackDoesNotCreateDuplicate() throws {
        let store = makeStore()
        let sourceDirectory = tempRoot.appendingPathComponent("source-folder", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        try Data("inside".utf8).write(to: sourceDirectory.appendingPathComponent("note.txt"))
        let original = try XCTUnwrap(store.addFiles(at: [sourceDirectory]).added.first)
        let managedURL = try XCTUnwrap(store.absoluteURL(for: original))

        let draggedBack = store.addFiles(at: [managedURL])

        XCTAssertTrue(draggedBack.added.isEmpty)
        XCTAssertTrue(draggedBack.errors.isEmpty)
        XCTAssertEqual(draggedBack.duplicates.map(\.id), [original.id])
        XCTAssertEqual(store.items.count, 1)
        let storedDirectories = try FileManager.default.contentsOfDirectory(at: filesDir,
                                                                            includingPropertiesForKeys: nil)
        XCTAssertEqual(storedDirectories.count, 1)
    }

    func testDraggingManagedAudioBackDoesNotCreateDuplicate() throws {
        let store = makeStore()
        let original = try store.addAudio(data: Data([0x01, 0x02, 0x03]),
                                          suggestedName: "录音-original",
                                          durationSeconds: 2)
        let managedURL = try XCTUnwrap(store.absoluteURL(for: original))

        let draggedBack = store.addFiles(at: [managedURL])

        XCTAssertTrue(draggedBack.added.isEmpty)
        XCTAssertTrue(draggedBack.errors.isEmpty)
        XCTAssertEqual(draggedBack.duplicates.map(\.id), [original.id])
        XCTAssertEqual(store.items.count, 1)
    }

    func testAudioContentHashPreventsDuplicateFromExternalCopy() throws {
        let store = makeStore()
        let bytes = Data([0xAA, 0xBB, 0xCC])
        let original = try store.addAudio(data: bytes,
                                          suggestedName: "录音-original",
                                          durationSeconds: 3)
        let externalCopy = tempRoot.appendingPathComponent("copy.m4a")
        try bytes.write(to: externalCopy)

        let duplicate = store.addFiles(at: [externalCopy])

        XCTAssertNotNil(original.contentHash)
        XCTAssertTrue(duplicate.added.isEmpty)
        XCTAssertEqual(duplicate.duplicates.map(\.id), [original.id])
        XCTAssertEqual(store.items.count, 1)
    }

    func testLoadBackfillsContentHashForLegacyItems() throws {
        // 先用正常路径入库一个文件（带哈希），再把元数据中的哈希键抹掉，模拟去重功能上线前的旧数据。
        let store = makeStore()
        let f = try makeSourceFile(named: "legacy.txt", contents: "legacy content")
        _ = store.addFiles(at: [f])

        let metadata = try JSONSerialization.jsonObject(with: Data(contentsOf: metadataURL)) as! [[String: Any]]
        let legacy = metadata.map { dict -> [String: Any] in
            var copy = dict
            copy.removeValue(forKey: "contentHash")
            return copy
        }
        try JSONSerialization.data(withJSONObject: legacy).write(to: metadataURL)

        // 加载时补算哈希，并写回元数据。
        let reloaded = makeStore()
        reloaded.load()
        XCTAssertNotNil(reloaded.items.first?.contentHash)

        // 再次加载（读回写后的元数据），哈希仍在。
        let reloadedAgain = makeStore()
        reloadedAgain.load()
        XCTAssertNotNil(reloadedAgain.items.first?.contentHash)
    }

    func testLoadBackfillsContentHashForLegacyAudio() throws {
        let store = makeStore()
        _ = try store.addAudio(data: Data([0x10, 0x20, 0x30]),
                               suggestedName: "录音-legacy",
                               durationSeconds: 4)

        let metadata = try JSONSerialization.jsonObject(with: Data(contentsOf: metadataURL)) as! [[String: Any]]
        let legacy = metadata.map { dict -> [String: Any] in
            var copy = dict
            copy.removeValue(forKey: "contentHash")
            return copy
        }
        try JSONSerialization.data(withJSONObject: legacy).write(to: metadataURL)

        let reloaded = makeStore()
        reloaded.load()

        XCTAssertEqual(reloaded.items.first?.kind, .audio)
        XCTAssertNotNil(reloaded.items.first?.contentHash)
    }

    // MARK: 删除

    func testRemoveMovesItemToTrashAndKeepsUnderlyingFile() throws {
        let store = makeStore()
        let f = try makeSourceFile(named: "gone.txt", contents: "x")
        let item = try XCTUnwrap(store.addFiles(at: [f]).added.first)
        let url = try XCTUnwrap(store.absoluteURL(for: item))
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        store.remove(item)
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertEqual(store.trashItems.map(\.item.id), [item.id])
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testRemoveAllMovesItemsToTrashAndKeepsFilesForRecovery() throws {
        let store = makeStore()
        let f = try makeSourceFile(named: "z.txt", contents: "zzz")
        store.addFiles(at: [f])
        store.addText("t")
        XCTAssertGreaterThan(store.totalByteSize, 0)
        store.removeAll()
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertEqual(store.trashItems.count, 2)
        XCTAssertGreaterThan(store.totalByteSize, 0)
    }

    func testTrashPersistsAndRestoresAcrossReload() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let store = makeStore(now: { now })
        let file = try makeSourceFile(named: "recover.txt", contents: "recoverable")
        let item = try XCTUnwrap(store.addFiles(at: [file]).added.first)
        let managedURL = try XCTUnwrap(store.absoluteURL(for: item))
        store.remove(item)

        let reloaded = makeStore(now: { now })
        reloaded.load()
        XCTAssertTrue(reloaded.items.isEmpty)
        XCTAssertEqual(reloaded.trashItems.map(\.id), [item.id])

        let result = reloaded.restoreFromTrash(ids: [item.id])
        XCTAssertEqual(result.restored.map(\.id), [item.id])
        XCTAssertTrue(result.duplicates.isEmpty)
        XCTAssertTrue(result.missingFiles.isEmpty)
        XCTAssertEqual(reloaded.items.map(\.id), [item.id])
        XCTAssertTrue(reloaded.trashItems.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: managedURL.path))

        let restoredReload = makeStore(now: { now })
        restoredReload.load()
        XCTAssertEqual(restoredReload.items.map(\.id), [item.id])
        XCTAssertTrue(restoredReload.trashItems.isEmpty)
    }

    func testLoadReconcilesItemPresentInBothActiveAndTrashMetadata() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let store = makeStore(now: { now })
        let item = store.addText("recover from interrupted metadata write")
        try JSONTrashMetadataStore(fileURL: trashMetadataURL)
            .save([TrashedItem(item: item, trashedAt: now)])

        let reloaded = makeStore(now: { now })
        reloaded.load()

        XCTAssertEqual(reloaded.items.map(\.id), [item.id])
        XCTAssertTrue(reloaded.trashItems.isEmpty)
        XCTAssertTrue(try JSONTrashMetadataStore(fileURL: trashMetadataURL).load().isEmpty)
    }

    func testTrashPurgesItemAndFileAfterThirtyDays() throws {
        var currentDate = Date(timeIntervalSince1970: 1_700_000_000)
        let store = makeStore(now: { currentDate })
        let file = try makeSourceFile(named: "expired.txt", contents: "old")
        let item = try XCTUnwrap(store.addFiles(at: [file]).added.first)
        let managedURL = try XCTUnwrap(store.absoluteURL(for: item))
        store.remove(item)

        currentDate.addTimeInterval(29 * 24 * 60 * 60)
        XCTAssertEqual(store.purgeExpiredTrash(), 0)
        XCTAssertEqual(store.trashCount, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: managedURL.path))

        currentDate.addTimeInterval(24 * 60 * 60)
        XCTAssertEqual(store.purgeExpiredTrash(), 1)
        XCTAssertTrue(store.trashItems.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: managedURL.path))
    }

    func testRestoreKeepsDuplicateFileInTrash() throws {
        let store = makeStore()
        let source = try makeSourceFile(named: "same.txt", contents: "same")
        let trashed = try XCTUnwrap(store.addFiles(at: [source]).added.first)
        store.remove(trashed)
        let replacement = store.addFiles(at: [source])
        XCTAssertEqual(replacement.added.count, 1)

        let result = store.restoreFromTrash(ids: [trashed.id])

        XCTAssertTrue(result.restored.isEmpty)
        XCTAssertEqual(result.duplicates.map(\.id), [trashed.id])
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.trashItems.map(\.id), [trashed.id])
    }

    func testRestoreKeepsMissingFileInTrash() throws {
        let store = makeStore()
        let source = try makeSourceFile(named: "missing.txt", contents: "missing")
        let trashed = try XCTUnwrap(store.addFiles(at: [source]).added.first)
        store.remove(trashed)
        try store.fileStorage.remove(relativePath: try XCTUnwrap(trashed.relativePath))

        let result = store.restoreFromTrash(ids: [trashed.id])

        XCTAssertTrue(result.restored.isEmpty)
        XCTAssertEqual(result.missingFiles.map(\.id), [trashed.id])
        XCTAssertEqual(store.trashItems.map(\.id), [trashed.id])
    }

    // MARK: 锁定

    func testRemoveAllKeepsLockedItemsAndFiles() throws {
        let store = makeStore()
        let f = try makeSourceFile(named: "keep.txt", contents: "data")
        let fileItem = try XCTUnwrap(store.addFiles(at: [f]).added.first)
        let textItem = store.addText("unlocked")
        store.setLocked(true, for: [fileItem.id])

        store.removeAll()

        XCTAssertEqual(store.items.map(\.id), [fileItem.id])
        XCTAssertNotNil(store.absoluteURL(for: fileItem))
        XCTAssertTrue(FileManager.default.fileExists(atPath: try XCTUnwrap(store.absoluteURL(for: fileItem)).path))
        XCTAssertFalse(store.items.contains(where: { $0.id == textItem.id }))
    }

    func testRemoveSkipsLockedItems() throws {
        let store = makeStore()
        let locked = store.addText("locked")
        let normal = store.addText("normal")
        store.setLocked(true, for: [locked.id])

        let removed = store.remove(ids: [locked.id, normal.id])

        XCTAssertEqual(removed, 1)
        XCTAssertEqual(store.items.map(\.id), [locked.id])
        XCTAssertTrue(store.items[0].locked)
    }

    func testLockedStatePersistsAcrossReload() {
        let store = makeStore()
        let item = store.addText("pin me")
        store.setLocked(true, for: [item.id])
        store.setLocked(false, for: [item.id])
        store.setLocked(true, for: [item.id])

        let reloaded = makeStore()
        reloaded.load()
        XCTAssertEqual(reloaded.items.count, 1)
        XCTAssertEqual(reloaded.items.first?.locked, true)
    }

    func testLockedItemsStayAboveNewUnlockedItems() {
        let store = makeStore()
        let older = store.addText("older")
        let locked = store.addText("locked")
        store.setLocked(true, for: [locked.id])

        let newest = store.addText("newest")

        XCTAssertEqual(store.items.map(\.id), [locked.id, newest.id, older.id])
        XCTAssertEqual(store.items.map(\.locked), [true, false, false])
    }

    func testLoadRepairsLegacyOrderWithLockedItemsBelowUnlockedItems() throws {
        let locked = StashItem(kind: .text, displayName: "locked", locked: true, text: "locked")
        let normal = StashItem.makeText("normal")
        try JSONMetadataStore(fileURL: metadataURL).save([normal, locked])

        let store = makeStore()
        store.load()

        XCTAssertEqual(store.items.map(\.id), [locked.id, normal.id])
        XCTAssertEqual(try JSONMetadataStore(fileURL: metadataURL).load().map(\.id), [locked.id, normal.id])
    }

    func testRestoredItemAppearsBelowLockedItems() {
        let store = makeStore()
        let locked = store.addText("locked")
        store.setLocked(true, for: [locked.id])
        let recoverable = store.addText("recoverable")
        store.remove(recoverable)

        let result = store.restoreFromTrash(ids: [recoverable.id])

        XCTAssertEqual(result.restored.map(\.id), [recoverable.id])
        XCTAssertEqual(store.items.map(\.id), [locked.id, recoverable.id])
    }

    // MARK: 录音

    func testAddAudioStoresFileWithDuration() throws {
        let store = makeStore()
        let item = try store.addAudio(data: Data([0x01, 0x02, 0x03]), suggestedName: "录音-test", durationSeconds: 12.5)

        XCTAssertEqual(item.kind, .audio)
        XCTAssertEqual(item.durationSeconds, 12.5)
        XCTAssertEqual(item.originalFileName, "录音-test.m4a")
        XCTAssertTrue(item.displayName.hasPrefix("录音 · "))
        XCTAssertNotNil(item.contentHash)
        let url = try XCTUnwrap(store.absoluteURL(for: item))
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(try Data(contentsOf: url), Data([0x01, 0x02, 0x03]))
    }

    func testAudioPersistsAcrossReload() throws {
        let store = makeStore()
        let item = try store.addAudio(data: Data([0x00]), suggestedName: "录音-persist", durationSeconds: 3)
        store.setLocked(true, for: [item.id])

        let reloaded = makeStore()
        reloaded.load()
        XCTAssertEqual(reloaded.items.count, 1)
        XCTAssertEqual(reloaded.items.first?.kind, .audio)
        XCTAssertEqual(reloaded.items.first?.locked, true)
    }

    func testLegacyMetadataWithoutLockedKeyLoadsAsUnlocked() throws {
        let legacyJSON = """
        [
          {
            "id": "\(UUID().uuidString)",
            "kind": "text",
            "displayName": "旧数据",
            "createdAt": "2026-08-16T10:00:00Z",
            "text": "旧数据内容"
          }
        ]
        """
        try Data(legacyJSON.utf8).write(to: metadataURL)

        let store = makeStore()
        store.load()
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items.first?.locked, false)
        XCTAssertEqual(store.items.first?.text, "旧数据内容")
    }

    // MARK: 持久化（模拟重启）

    func testPersistenceSurvivesReload() throws {
        let store = makeStore()
        store.addText("persist me")
        let f = try makeSourceFile(named: "keep.txt", contents: "data")
        store.addFiles(at: [f])

        // 新建 store 实例、同一后端目录 —— 模拟应用/系统重启。
        let reloaded = makeStore()
        reloaded.load()
        XCTAssertEqual(reloaded.items.count, 2)
        XCTAssertTrue(reloaded.items.contains { $0.text == "persist me" })
        XCTAssertTrue(reloaded.items.contains { $0.displayName == "keep.txt" })
    }

    // MARK: helpers

    private func makeSourceFile(named name: String, contents: String, subfolder: String? = nil) throws -> URL {
        var dir = tempRoot.appendingPathComponent("src", isDirectory: true)
        if let subfolder { dir = dir.appendingPathComponent(subfolder, isDirectory: true) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(name)
        try Data(contents.utf8).write(to: url)
        return url
    }
}
