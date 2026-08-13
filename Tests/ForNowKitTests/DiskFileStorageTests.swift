import XCTest
@testable import ForNowKit

final class DiskFileStorageTests: XCTestCase {
    private var root: URL!
    private var storage: DiskFileStorage!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ForNowStorage-\(UUID().uuidString)", isDirectory: true)
        storage = DiskFileStorage(rootDirectory: root)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testImportFileKeepsOriginalNameUnderUUIDFolder() throws {
        let src = try tempFile(named: "photo.png", bytes: 10)
        let stored = try storage.importFile(at: src)
        XCTAssertEqual(stored.originalName, "photo.png")
        XCTAssertEqual(stored.byteSize, 10)
        // relativePath 形如 <uuid>/photo.png
        let parts = stored.relativePath.split(separator: "/")
        XCTAssertEqual(parts.count, 2)
        XCTAssertEqual(String(parts[1]), "photo.png")
        XCTAssertNotNil(UUID(uuidString: String(parts[0])))
    }

    func testImportDataAppendsExtensionWhenMissing() throws {
        let stored = try storage.importData(Data([1, 2, 3]), suggestedName: "clip", fileExtension: "png")
        XCTAssertEqual(stored.originalName, "clip.png")
        XCTAssertEqual(stored.byteSize, 3)
        XCTAssertTrue(FileManager.default.fileExists(atPath: storage.absoluteURL(for: stored.relativePath).path))
    }

    func testImportDataDoesNotDoubleAppendExtension() throws {
        let stored = try storage.importData(Data([1]), suggestedName: "clip.png", fileExtension: "png")
        XCTAssertEqual(stored.originalName, "clip.png")
    }

    func testTotalByteSizeSumsAllItems() throws {
        _ = try storage.importData(Data(count: 100), suggestedName: "a", fileExtension: "bin")
        _ = try storage.importData(Data(count: 50), suggestedName: "b", fileExtension: "bin")
        XCTAssertEqual(storage.totalByteSize(), 150)
    }

    func testRemoveDeletesItemFolderOnly() throws {
        let a = try storage.importData(Data(count: 10), suggestedName: "a", fileExtension: "bin")
        let b = try storage.importData(Data(count: 20), suggestedName: "b", fileExtension: "bin")
        try storage.remove(relativePath: a.relativePath)
        XCTAssertFalse(FileManager.default.fileExists(atPath: storage.absoluteURL(for: a.relativePath).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: storage.absoluteURL(for: b.relativePath).path))
    }

    func testRemoveAllEmptiesRoot() throws {
        _ = try storage.importData(Data(count: 10), suggestedName: "a", fileExtension: "bin")
        try storage.removeAll()
        XCTAssertEqual(storage.totalByteSize(), 0)
    }

    func testImportDirectoryComputesRecursiveSize() throws {
        // 建一个含两文件的目录并整体导入。
        let dir = root.appendingPathComponent("src-folder", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data(count: 30).write(to: dir.appendingPathComponent("one.bin"))
        try Data(count: 40).write(to: dir.appendingPathComponent("two.bin"))
        let stored = try storage.importFile(at: dir)
        XCTAssertEqual(stored.byteSize, 70)
        XCTAssertEqual(stored.originalName, "src-folder")
    }

    private func tempFile(named name: String, bytes: Int) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("src-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(name)
        try Data(count: bytes).write(to: url)
        return url
    }
}
