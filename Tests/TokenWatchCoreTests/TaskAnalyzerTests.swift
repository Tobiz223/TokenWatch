import XCTest
@testable import TokenWatchCore

final class TaskAnalyzerTests: XCTestCase {
    func testParsesFencedJSON() {
        let raw = "```json\n{\"model\":\"opus\",\"situation\":\"arch design\",\"reasoning\":\"hard\",\"confidence\":0.9}\n```"
        let a = TaskAnalyzer.parse(response: raw)
        XCTAssertEqual(a?.tier, .opus)
        XCTAssertEqual(a?.situation, "arch design")
        XCTAssertEqual(a?.confidence ?? 0, 0.9, accuracy: 1e-9)
    }

    func testParsesPlainJSONWithProse() {
        let raw = "Sure! {\"model\":\"haiku\",\"situation\":\"rename\",\"reasoning\":\"trivial\",\"confidence\":0.97}"
        XCTAssertEqual(TaskAnalyzer.parse(response: raw)?.tier, .haiku)
    }

    func testRejectsUnknownModel() {
        XCTAssertNil(TaskAnalyzer.parse(response: "{\"model\":\"gpt-4\",\"confidence\":1}"))
    }

    func testRejectsNonJSON() {
        XCTAssertNil(TaskAnalyzer.parse(response: "no json here"))
    }

    func testClampsConfidence() {
        let a = TaskAnalyzer.parse(response: "{\"model\":\"sonnet\",\"confidence\":5}")
        XCTAssertEqual(a?.confidence, 1.0)
    }

    func testClassificationPromptContainsTask() {
        let p = TaskAnalyzer.classificationPrompt(for: "rename foo")
        XCTAssertTrue(p.contains("rename foo"))
        XCTAssertTrue(p.contains("haiku|sonnet|opus"))
    }
}
