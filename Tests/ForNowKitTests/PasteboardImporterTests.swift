import XCTest
@testable import ForNowKit

/// 可注入的假剪贴板。
private struct FakeReader: PasteboardReading {
    var files: [URL] = []
    var image: (data: Data, fileExtension: String)?
    var url: String?
    var text: String?

    func fileURLs() -> [URL] { files }
    func imageData() -> (data: Data, fileExtension: String)? { image }
    func webURL() -> String? { url }
    func plainText() -> String? { text }
}

final class PasteboardImporterTests: XCTestCase {
    func testFilesWinOverEverything() {
        let reader = FakeReader(
            files: [URL(fileURLWithPath: "/tmp/a.txt")],
            image: (Data([1]), "png"),
            url: "https://example.com",
            text: "hello")
        XCTAssertEqual(PasteboardImporter.classify(reader),
                       .files([URL(fileURLWithPath: "/tmp/a.txt")]))
    }

    func testImageWinsOverLinkAndText() {
        let reader = FakeReader(image: (Data([1, 2]), "png"), url: "https://example.com", text: "hello")
        XCTAssertEqual(PasteboardImporter.classify(reader), .image(data: Data([1, 2]), fileExtension: "png"))
    }

    func testLinkWinsOverText() {
        let reader = FakeReader(url: "https://example.com/x", text: "hello")
        XCTAssertEqual(PasteboardImporter.classify(reader), .link(url: "https://example.com/x", title: nil))
    }

    func testPlainTextWhenOnlyText() {
        let reader = FakeReader(text: "just text")
        XCTAssertEqual(PasteboardImporter.classify(reader), .text("just text"))
    }

    func testWhitespaceOnlyTextIsEmpty() {
        let reader = FakeReader(text: "   \n  ")
        XCTAssertEqual(PasteboardImporter.classify(reader), .empty)
    }

    func testNothingIsEmpty() {
        XCTAssertEqual(PasteboardImporter.classify(FakeReader()), .empty)
    }
}
