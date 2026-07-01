import XCTest
@testable import TokenWatchCore

final class CostEngineTests: XCTestCase {
    func testUsageRecordStoresFields() {
        let r = UsageRecord(id: "msg_1", timestamp: Date(timeIntervalSince1970: 0),
                            model: "claude-haiku-4-5", inputTokens: 100, outputTokens: 50,
                            cacheWriteTokens: 0, cacheReadTokens: 0,
                            promptPreview: "hi", project: "demo")
        XCTAssertEqual(r.model, "claude-haiku-4-5")
        XCTAssertEqual(r.inputTokens, 100)
    }

    func makeEngine() -> CostEngine {
        let rates = ["claude-haiku-4-5": Rates(input: 1.0, output: 5.0, cacheWrite: 1.25, cacheRead: 0.1)]
        return CostEngine(pricing: PricingTable(rates: rates,
            defaultRates: Rates(input: 3.0, output: 15.0, cacheWrite: 3.75, cacheRead: 0.3)))
    }

    func testCostForRecord() {
        // 1,000,000 input @ $1 + 1,000,000 output @ $5 = $6
        let r = UsageRecord(id: nil, timestamp: Date(), model: "claude-haiku-4-5",
                            inputTokens: 1_000_000, outputTokens: 1_000_000,
                            cacheWriteTokens: 0, cacheReadTokens: 0,
                            promptPreview: "", project: "p")
        XCTAssertEqual(makeEngine().cost(for: r), 6.0, accuracy: 1e-9)
    }

    func testMonthToDateExcludesLastMonth() {
        let cal = Calendar(identifier: .gregorian)
        let now = DateComponents(calendar: cal, year: 2026, month: 7, day: 15).date!
        let thisMonth = DateComponents(calendar: cal, year: 2026, month: 7, day: 2).date!
        let lastMonth = DateComponents(calendar: cal, year: 2026, month: 6, day: 30).date!
        func rec(_ d: Date) -> UsageRecord {
            UsageRecord(id: nil, timestamp: d, model: "claude-haiku-4-5",
                        inputTokens: 1_000_000, outputTokens: 0,
                        cacheWriteTokens: 0, cacheReadTokens: 0, promptPreview: "", project: "p")
        }
        let total = makeEngine().monthToDateTotal([rec(thisMonth), rec(lastMonth)], now: now, calendar: cal)
        XCTAssertEqual(total, 1.0, accuracy: 1e-9) // only thisMonth's $1 counts
    }
}
