import XCTest
@testable import TokenWatchCore

final class LogParserTests: XCTestCase {
    func loadFixture() throws -> String {
        let url = Bundle.module.url(forResource: "sample", withExtension: "jsonl", subdirectory: "Fixtures")!
        return try String(contentsOf: url, encoding: .utf8)
    }

    func testParsesTwoRecordsSkippingGarbage() throws {
        let records = LogParser().parse(fileContents: try loadFixture(), project: "fallback")
        XCTAssertEqual(records.count, 2)
    }

    func testFirstRecordFieldsAndPreview() throws {
        let records = LogParser().parse(fileContents: try loadFixture(), project: "fallback")
        let first = records[0]
        XCTAssertEqual(first.model, "claude-opus-4-8")
        XCTAssertEqual(first.inputTokens, 2300)
        XCTAssertEqual(first.outputTokens, 800)
        XCTAssertEqual(first.project, "myapp")            // from cwd lastPathComponent
        XCTAssertTrue(first.promptPreview.contains("login bug"))
        XCTAssertEqual(first.id, "msg_1")
    }

    func testMissingCacheFieldsDefaultToZero() throws {
        let records = LogParser().parse(fileContents: try loadFixture(), project: "fallback")
        XCTAssertEqual(records[1].cacheReadTokens, 0)
        XCTAssertEqual(records[1].cacheWriteTokens, 0)
    }
}
