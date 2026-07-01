import XCTest
@testable import TokenWatchCore

final class AdvisorTests: XCTestCase {
    func makeAdvisor() -> Advisor {
        Advisor(costEngine: CostEngine(pricing: PricingTable.bundled()))
    }

    func testRecommendsHaikuForSimplePrompt() {
        let rec = makeAdvisor().recommend(prompt: "rename this variable")
        XCTAssertEqual(rec.tier, .haiku)
        XCTAssertEqual(rec.modelId, "claude-haiku-4-5")
        XCTAssertEqual(rec.cliAlias, "haiku")
        XCTAssertGreaterThan(rec.estimatedCost, 0)
    }

    func testRecommendsOpusForHardPrompt() {
        XCTAssertEqual(makeAdvisor().recommend(prompt: "refactor the module").tier, .opus)
    }

    func testRunCommandShape() {
        let cmd = makeAdvisor().runCommand(prompt: "do a thing", alias: "haiku")
        XCTAssertEqual(cmd, ["claude", "-p", "do a thing", "--model", "haiku"])
    }
}
