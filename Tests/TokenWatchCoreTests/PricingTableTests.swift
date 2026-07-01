import XCTest
@testable import TokenWatchCore

final class PricingTableTests: XCTestCase {
    let json = """
    {
      "claude-haiku-4-5": { "input": 1.0, "output": 5.0, "cacheWrite": 1.25, "cacheRead": 0.1 },
      "default":          { "input": 3.0, "output": 15.0, "cacheWrite": 3.75, "cacheRead": 0.3 }
    }
    """.data(using: .utf8)!

    func testLoadsKnownModel() throws {
        let t = try PricingTable.load(from: json)
        XCTAssertEqual(t.rates(for: "claude-haiku-4-5").output, 5.0)
        XCTAssertTrue(t.isKnown("claude-haiku-4-5"))
    }

    func testUnknownModelFallsBackToDefault() throws {
        let t = try PricingTable.load(from: json)
        XCTAssertEqual(t.rates(for: "mystery-model").input, 3.0)
        XCTAssertFalse(t.isKnown("mystery-model"))
    }

    func testBundledLoads() {
        let t = PricingTable.bundled()
        XCTAssertTrue(t.isKnown("claude-opus-4-8"))
    }
}
