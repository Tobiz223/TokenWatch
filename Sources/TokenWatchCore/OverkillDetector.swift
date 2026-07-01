import Foundation

public struct OverkillResult: Equatable {
    public let isOverkill: Bool
    public let overpay: Double
    public init(isOverkill: Bool, overpay: Double) {
        self.isOverkill = isOverkill; self.overpay = overpay
    }
}

public struct OverkillDetector {
    public let costEngine: CostEngine
    public let heuristics: ComplexityHeuristics
    public let haikuModelId: String
    public let expensiveModelSubstrings: [String]

    public init(costEngine: CostEngine,
                heuristics: ComplexityHeuristics = ComplexityHeuristics(),
                haikuModelId: String = "claude-haiku-4-5",
                expensiveModelSubstrings: [String] = ["opus", "sonnet"]) {
        self.costEngine = costEngine
        self.heuristics = heuristics
        self.haikuModelId = haikuModelId
        self.expensiveModelSubstrings = expensiveModelSubstrings
    }

    public func evaluate(_ record: UsageRecord) -> OverkillResult {
        let modelLower = record.model.lowercased()
        let expensive = expensiveModelSubstrings.contains { modelLower.contains($0) }
        let simple = heuristics.isSimpleTask(
            outputTokens: record.outputTokens,
            contextTokens: record.inputTokens + record.cacheReadTokens,
            previewLength: record.promptPreview.count)

        guard expensive && simple else { return OverkillResult(isOverkill: false, overpay: 0) }

        let actual = costEngine.cost(for: record)
        let asHaiku = costEngine.cost(inputTokens: record.inputTokens,
                                      outputTokens: record.outputTokens,
                                      cacheWriteTokens: record.cacheWriteTokens,
                                      cacheReadTokens: record.cacheReadTokens,
                                      model: haikuModelId)
        return OverkillResult(isOverkill: true, overpay: max(0, actual - asHaiku))
    }
}
