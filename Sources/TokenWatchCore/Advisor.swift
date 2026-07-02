import Foundation

public struct Recommendation: Equatable {
    public let tier: ModelTier
    public let modelId: String
    public let cliAlias: String
    public let estimatedCost: Double
    public init(tier: ModelTier, modelId: String, cliAlias: String, estimatedCost: Double) {
        self.tier = tier; self.modelId = modelId; self.cliAlias = cliAlias
        self.estimatedCost = estimatedCost
    }
}

public struct Advisor {
    public let costEngine: CostEngine
    public let heuristics: ComplexityHeuristics
    public let assumedOutputTokens: Int

    public init(costEngine: CostEngine,
                heuristics: ComplexityHeuristics = ComplexityHeuristics(),
                assumedOutputTokens: Int = 500) {
        self.costEngine = costEngine
        self.heuristics = heuristics
        self.assumedOutputTokens = assumedOutputTokens
    }

    private func ids(for tier: ModelTier) -> (modelId: String, alias: String) {
        switch tier {
        case .haiku:  return ("claude-haiku-4-5", "haiku")
        case .sonnet: return ("claude-sonnet-5", "sonnet")
        case .opus:   return ("claude-opus-4-8", "opus")
        }
    }

    public func recommend(prompt: String) -> Recommendation {
        recommendation(tier: heuristics.recommend(prompt: prompt), prompt: prompt)
    }

    /// Builds a recommendation for an explicit tier (e.g. one chosen by the LLM analyzer),
    /// mapping it to a model id/alias and estimating the cost for this prompt.
    public func recommendation(tier: ModelTier, prompt: String) -> Recommendation {
        let (modelId, alias) = ids(for: tier)
        let cost = costEngine.cost(inputTokens: prompt.count / 4,
                                   outputTokens: assumedOutputTokens,
                                   cacheWriteTokens: 0, cacheReadTokens: 0, model: modelId)
        return Recommendation(tier: tier, modelId: modelId, cliAlias: alias, estimatedCost: cost)
    }

    /// Estimated cost of running this prompt on Opus — used to show savings.
    public func opusCost(prompt: String) -> Double {
        costEngine.cost(inputTokens: prompt.count / 4, outputTokens: assumedOutputTokens,
                        cacheWriteTokens: 0, cacheReadTokens: 0, model: "claude-opus-4-8")
    }

    public func runCommand(prompt: String, alias: String) -> [String] {
        ["claude", "-p", prompt, "--model", alias]
    }
}
