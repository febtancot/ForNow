import AppKit
import UniformTypeIdentifiers
import XCTest
@testable import ForNowKit

final class DropFileURLDecoderTests: XCTestCase {
    func testDecodesFinderUTF8FileURLPayload() {
        let data = Data("file:///tmp/ForNow%20Note.txt".utf8)

        let url = DropFileURLDecoder.decode(data)

        XCTAssertEqual(url?.path, "/tmp/ForNow Note.txt")
    }

    func testRejectsPlainTextAndWebURLs() {
        XCTAssertNil(DropFileURLDecoder.decode(Data("ordinary text".utf8)))
        XCTAssertNil(DropFileURLDecoder.decode("https://example.com/note.txt"))
    }

    func testLoaderPrefersFileURLWhenProviderAlsoOffersPlainText() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ForNow Drop Provider \(UUID().uuidString).txt")
        try Data("same content".utf8).write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let provider = NSItemProvider()
        provider.registerDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier,
                                            visibility: .all) { completion in
            completion(Data(fileURL.absoluteString.utf8), nil)
            return nil
        }
        provider.registerObject("same content" as NSString, visibility: .all)

        let loadedURL = await DropFileURLLoader.load(from: provider)

        XCTAssertEqual(loadedURL?.standardizedFileURL, fileURL.standardizedFileURL)
    }
}
