import XCTest
@testable import ForNowKit

final class ExternalFileImportContractTests: XCTestCase {
    func testResolvesContainingApplicationFromEmbeddedFinderExtension() {
        let extensionURL = URL(
            fileURLWithPath: "/Applications/ForNow.app/Contents/PlugIns/ForNowFinderExtension.appex"
        )

        XCTAssertEqual(
            ExternalFileImportContract.containingApplicationURL(
                forExtensionBundleURL: extensionURL
            ),
            URL(fileURLWithPath: "/Applications/ForNow.app")
        )
    }

    func testRejectsExtensionOutsideApplicationBundle() {
        XCTAssertNil(
            ExternalFileImportContract.containingApplicationURL(
                forExtensionBundleURL: URL(fileURLWithPath: "/tmp/ForNowFinderExtension.appex")
            )
        )
    }

    func testNormalizesUniqueFileURLsWithoutChangingOrder() {
        let first = URL(fileURLWithPath: "/tmp/first.txt")
        let second = URL(fileURLWithPath: "/tmp/second.pdf")

        XCTAssertEqual(
            ExternalFileImportContract.normalizedFileURLs([
                first,
                URL(string: "https://example.com")!,
                first,
                second
            ]),
            [first, second]
        )
    }

    func testFeedbackReportsMixedOutcome() {
        XCTAssertEqual(
            ExternalFileImportContract.feedbackMessage(
                addedCount: 2,
                duplicateCount: 1,
                failureCount: 1
            ),
            "已暂存 2 项，1 项已存在，1 项失败"
        )
    }

    func testFeedbackReportsEmptyRequest() {
        XCTAssertEqual(
            ExternalFileImportContract.feedbackMessage(
                addedCount: 0,
                duplicateCount: 0,
                failureCount: 0
            ),
            "没有可暂存的文件"
        )
    }
}
