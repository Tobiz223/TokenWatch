import XCTest
@testable import TokenWatchCore

final class OverkillDetectorTests: XCTestCase {
    func makeDetector() -> OverkillDetector {
        let rates = [
            "claude-opus-4-8":  Rates(input: 15.0, output: 75.0, cacheWrite: 18.75, cacheRead: 1.5),
            "claude-haiku-4-5": Rates(input: 1.0,  output: 5.0,  cacheWrite: 1.25,  cacheRead: 0.1),
        ]
        let engine = CostEngine(pricing: PricingTable(rates: rates,
            defaultRates: Rates(input: 3, output: 15, cacheWrite: 3.75, cacheRead: 0.3)))
        return OverkillDetector(costEngine: engine)
    }

    func testSimpleTaskOnOpusIsOverkill() {
        let r = UsageRecord(id: nil, timestamp: Date(), model: "claude-opus-4-8",
                            inputTokens: 200, outputTokens: 50, cacheWriteTokens: 0,
                            cacheReadTokens: 0, promptPreview: "rename var", project: "p")
        let result = makeDetector().evaluate(r)
        XCTAssertTrue(result.isOverkill)
        XCTAssertGreaterThan(result.overpay, 0)
    }

    func testBigTaskOnOpusIsNotOverkill() {
        let r = UsageRecord(id: nil, timestamp: Date(), model: "claude-opus-4-8",
                            inputTokens: 50_000, outputTokens: 5_000, cacheWriteTokens: 0,
                            cacheReadTokens: 0, promptPreview: "big refactor", project: "p")
        XCTAssertFalse(makeDetector().evaluate(r).isOverkill)
    }

    func testSimpleTaskOnHaikuIsNotOverkill() {
        let r = UsageRecord(id: nil, timestamp: Date(), model: "claude-haiku-4-5",
                            inputTokens: 200, outputTokens: 50, cacheWriteTokens: 0,
                            cacheReadTokens: 0, promptPreview: "hi", project: "p")
        XCTAssertFalse(makeDetector().evaluate(r).isOverkill)
    }
}
