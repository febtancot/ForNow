import XCTest
@testable import ForNowKit

@MainActor
final class StashStoreTests: XCTestCase {
    private var tempRoot: URL!
    private var metadataURL: URL!
    private var filesDir: URL!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("ForNowTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        metadataURL = tempRoot.appendingPathComponent("metadata.json")
        filesDir = tempRoot.appendingPathComponent("Files", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    private func makeStore() -> StashStore {
        StashStore(metadataStore: JSONMetadataStore(fileURL: metadataURL),
                   fileStorage: DiskFileStorage(rootDirectory: filesDir))
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
        let (added, errors) = store.addFiles(at: [f])
        XCTAssertTrue(errors.isEmpty)
        let item = try XCTUnwrap(added.first)
        XCTAssertEqual(item.kind, .file)
        XCTAssertEqual(item.byteSize, 5)
        XCTAssertEqual(item.originalFileName, "note.txt")
        let url = try XCTUnwrap(store.absoluteURL(for: item))
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testDuplicateNamesGetUniqueStorageButShowOriginalName() throws {
        let store = makeStore()
        let f1 = try makeSourceFile(named: "dup.txt", contents: "one")
        let f2 = try makeSourceFile(named: "dup.txt", contents: "two", subfolder: "sub")
        let (added, _) = store.addFiles(at: [f1, f2])
        XCTAssertEqual(added.count, 2)
        XCTAssertEqual(Set(added.map(\.displayName)), ["dup.txt"])       // 界面仍显示原名
        XCTAssertNotEqual(added[0].relativePath, added[1].relativePath)  // 内部唯一
        for item in added {
            let url = try XCTUnwrap(store.absoluteURL(for: item))
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        }
    }

    func testUnreadableSourceProducesError() {
        let store = makeStore()
        let missing = tempRoot.appendingPathComponent("does-not-exist.txt")
        let (added, errors) = store.addFiles(at: [missing])
        XCTAssertTrue(added.isEmpty)
        XCTAssertEqual(errors.count, 1)
    }

    // MARK: 删除

    func testRemoveDeletesItemAndUnderlyingFile() throws {
        let store = makeStore()
        let f = try makeSourceFile(named: "gone.txt", contents: "x")
        let item = try XCTUnwrap(store.addFiles(at: [f]).added.first)
        let url = try XCTUnwrap(store.absoluteURL(for: item))
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        store.remove(item)
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testRemoveAllClearsItemsAndFiles() throws {
        let store = makeStore()
        let f = try makeSourceFile(named: "z.txt", contents: "zzz")
        store.addFiles(at: [f])
        store.addText("t")
        XCTAssertGreaterThan(store.totalByteSize, 0)
        store.removeAll()
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertEqual(store.totalByteSize, 0)
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

    // MARK: 录音

    func testAddAudioStoresFileWithDuration() throws {
        let store = makeStore()
        let item = try store.addAudio(data: Data([0x01, 0x02, 0x03]), suggestedName: "录音-test", durationSeconds: 12.5)

        XCTAssertEqual(item.kind, .audio)
        XCTAssertEqual(item.durationSeconds, 12.5)
        XCTAssertEqual(item.originalFileName, "录音-test.m4a")
        XCTAssertTrue(item.displayName.hasPrefix("录音 · "))
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
