import XCTest
@testable import TokenWatchCore

final class ComplexityHeuristicsTests: XCTestCase {
    let h = ComplexityHeuristics()

    func testShortSimplePromptIsHaiku() {
        XCTAssertEqual(h.recommend(prompt: "rename this variable"), .haiku)
    }

    func testHardKeywordIsOpus() {
        XCTAssertEqual(h.recommend(prompt: "refactor the auth layer"), .opus)
    }

    func testCodeBlockIsAtLeastSonnet() {
        XCTAssertEqual(h.recommend(prompt: "explain ```func foo() {}```"), .sonnet)
    }

    func testSimpleTaskDetection() {
        XCTAssertTrue(h.isSimpleTask(outputTokens: 40, contextTokens: 120, previewLength: 20))
        XCTAssertFalse(h.isSimpleTask(outputTokens: 900, contextTokens: 120, previewLength: 20))
    }
}
