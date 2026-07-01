import Foundation

public enum ModelTier: String, Equatable { case haiku, sonnet, opus }

public struct ComplexityHeuristics {
    public static let defaultHardKeywords = ["refactor","architecture","debug","design",
        "prove","optimize","concurrency","security","migrate","threading"]
    public let hardKeywords: [String]

    public init(hardKeywords: [String] = ComplexityHeuristics.defaultHardKeywords) {
        self.hardKeywords = hardKeywords
    }

    public func recommend(prompt: String) -> ModelTier {
        let lower = prompt.lowercased()
        if hardKeywords.contains(where: { lower.contains($0) }) || prompt.count > 2000 {
            return .opus
        }
        let codeMarkers = ["```", "func ", "class ", "{"]
        if codeMarkers.contains(where: { prompt.contains($0) }) || prompt.count >= 280 {
            return .sonnet
        }
        return .haiku
    }

    public func isSimpleTask(outputTokens: Int, contextTokens: Int, previewLength: Int) -> Bool {
        outputTokens < 400 && contextTokens < 3000 && previewLength < 200
    }
}
