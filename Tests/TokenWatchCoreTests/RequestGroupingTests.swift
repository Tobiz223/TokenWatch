import XCTest
@testable import TokenWatchCore

final class RequestGroupingTests: XCTestCase {
    private func grouper() -> RequestGrouper {
        let engine = CostEngine(pricing: PricingTable.bundled())
        return RequestGrouper(costEngine: engine, detector: OverkillDetector(costEngine: engine))
    }

    private func rec(turn: String, preview: String, out: Int) -> UsageRecord {
        UsageRecord(id: nil, timestamp: Date(timeIntervalSince1970: 0), model: "claude-opus-4-8",
                    inputTokens: 100, outputTokens: out, cacheWriteTokens: 0, cacheReadTokens: 0,
                    promptPreview: preview, project: "p", turnId: turn)
    }

    func testGroupsAssistantCallsByTurn() {
        let records = [
            rec(turn: "f#1", preview: "fix bug", out: 100),
            rec(turn: "f#1", preview: "fix bug", out: 50),
            rec(turn: "f#2", preview: "add test", out: 20),
        ]
        let groups = grouper().groups(from: records)
        XCTAssertEqual(groups.count, 2)
        let g = groups.first { $0.id == "f#1" }!
        XCTAssertEqual(g.callCount, 2)
        XCTAssertEqual(g.title, "fix bug")
        XCTAssertEqual(g.models, ["Opus"])
    }

    func testShortModelName() {
        XCTAssertEqual(shortModelName("claude-sonnet-4-6"), "Sonnet")
        XCTAssertEqual(shortModelName("claude-haiku-4-5-20251001"), "Haiku")
    }
}
