import XCTest
@testable import ForNowKit

final class StashItemTests: XCTestCase {
    func testSummaryTrimsAndJoinsFirstTwoLines() {
        XCTAssertEqual(StashItem.summary(from: "  hi  "), "hi")
        XCTAssertEqual(StashItem.summary(from: "a\nb\nc"), "a b")
        XCTAssertEqual(StashItem.summary(from: "\n\nfirst real\nsecond"), "first real second")
    }

    func testSummaryCapsLength() {
        let long = String(repeating: "x", count: 500)
        XCTAssertEqual(StashItem.summary(from: long).count, 120)
    }

    func testInferredKindDetectsImages() {
        XCTAssertEqual(StashItem.inferredKind(forFileName: "a.png", isDirectory: false), .image)
        XCTAssertEqual(StashItem.inferredKind(forFileName: "a.JPG", isDirectory: false), .image)
        XCTAssertEqual(StashItem.inferredKind(forFileName: "a.heic", isDirectory: false), .image)
        XCTAssertEqual(StashItem.inferredKind(forFileName: "a.pdf", isDirectory: false), .file)
        XCTAssertEqual(StashItem.inferredKind(forFileName: "noext", isDirectory: false), .file)
        XCTAssertEqual(StashItem.inferredKind(forFileName: "folder.png", isDirectory: true), .file)
    }

    func testCodableRoundTrip() throws {
        let item = StashItem.makeText("hello\nworld")
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(StashItem.self, from: data)
        XCTAssertEqual(item, decoded)
    }

    func testDisplayHelpers() {
        let img = StashItem.makeImage(
            stored: StoredFile(relativePath: "x/y.png", byteSize: 2048, originalName: "y.png"),
            pixelSize: CGSize(width: 1920, height: 1080))
        XCTAssertEqual(img.pixelSizeText, "1920 × 1080")
        // ByteCountFormatter 使用不换行空格，比较时忽略空白。
        XCTAssertEqual(img.byteSizeText?.filter { !$0.isWhitespace }, "2KB")
    }

    func testTxtFileNameSanitizesAndCaps() {
        let slashed = StashItem.makeText("a/b:c")
        XCTAssertEqual(slashed.txtFileName, "a b c.txt")

        let long = StashItem.makeText(String(repeating: "长", count: 100))
        XCTAssertEqual(long.txtFileName.count, 44) // 40 字符 + ".txt"
        XCTAssertTrue(long.txtFileName.hasSuffix(".txt"))

        let blank = StashItem.makeText("   \n  ")
        XCTAssertEqual(blank.txtFileName, "暂存文本.txt")
    }
}
