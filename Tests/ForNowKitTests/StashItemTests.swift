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
        XCTAssertEqual(StashItem.inferredKind(forFileName: "memo.m4a", isDirectory: false), .audio)
        XCTAssertEqual(StashItem.inferredKind(forFileName: "voice.MP3", isDirectory: false), .audio)
        XCTAssertEqual(StashItem.inferredKind(forFileName: "a.pdf", isDirectory: false), .file)
        XCTAssertEqual(StashItem.inferredKind(forFileName: "noext", isDirectory: false), .file)
        XCTAssertEqual(StashItem.inferredKind(forFileName: "folder.png", isDirectory: true), .file)
    }

    func testCodableRoundTrip() throws {
        var item = StashItem.makeText("hello\nworld")
        item.note = "稍后发送给设计师"
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(StashItem.self, from: data)
        XCTAssertEqual(item, decoded)
    }

    func testNoteNormalizationAndPreview() {
        XCTAssertNil(StashItem.normalizedNote(" \n "))
        XCTAssertEqual(StashItem.normalizedNote("  第一行\n第二行  "), "第一行\n第二行")
        XCTAssertEqual(StashItem.normalizedNote(String(repeating: "备", count: 501))?.count, 500)

        let item = StashItem(kind: .file,
                             displayName: "brief.pdf",
                             note: "客户 最终版\n周五发送")
        XCTAssertEqual(item.notePreview, "客户 最终版 周五发送")
    }

    func testLegacyMetadataWithoutNoteDecodesAsNil() throws {
        let original = StashItem.makeText("旧内容")
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        json.removeValue(forKey: "note")

        let decoded = try JSONDecoder().decode(StashItem.self,
                                               from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(decoded.note)
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

    func testAudioDurationTextFormats() {
        let audio = StashItem.makeAudio(
            stored: StoredFile(relativePath: "x/a.m4a", byteSize: 100, originalName: "a.m4a"),
            durationSeconds: 65.0)
        XCTAssertEqual(audio.durationText, "1:05")
        XCTAssertEqual(audio.kind, .audio)
        XCTAssertEqual(audio.kind.symbolName, "waveform")
        XCTAssertEqual(audio.kind.localizedName, "录音")

        let short = StashItem.makeAudio(
            stored: StoredFile(relativePath: "x/b.m4a", byteSize: 100, originalName: "b.m4a"),
            durationSeconds: 8.0)
        XCTAssertEqual(short.durationText, "0:08")
    }

    func testDurationTextStaticFormatter() {
        XCTAssertEqual(StashItem.durationText(seconds: 0), "0:00")
        XCTAssertEqual(StashItem.durationText(seconds: 5), "0:05")
        XCTAssertEqual(StashItem.durationText(seconds: 65.9), "1:05")
        XCTAssertEqual(StashItem.durationText(seconds: 3_605), "60:05")
    }
}
