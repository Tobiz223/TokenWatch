import Foundation

/// The structured result of analyzing a coding task for model selection.
public struct TaskAnalysis: Equatable {
    public let tier: ModelTier
    public let situation: String
    public let reasoning: String
    public let confidence: Double
    public init(tier: ModelTier, situation: String, reasoning: String, confidence: Double) {
        self.tier = tier
        self.situation = situation
        self.reasoning = reasoning
        self.confidence = confidence
    }
}

/// Builds the classifier prompt and parses Claude's response. Pure and unit-tested;
/// the actual `claude -p` invocation lives in the app layer (needs a subprocess).
public enum TaskAnalyzer {
    public static let classifyInstructions = """
    You are a model-selection classifier for Claude coding tasks. Analyze the TASK \
    and choose the CHEAPEST Claude model that can still do it well: \
    "haiku" (trivial edits, renames, typos, simple lookups, tiny snippets), \
    "sonnet" (standard coding, moderate reasoning, multi-file edits), \
    "opus" (hard debugging, architecture/design, deep multi-step reasoning, subtle \
    concurrency/security). Respond with ONLY a compact JSON object and nothing else: \
    {"model":"haiku|sonnet|opus","situation":"2-4 word task type",\
    "reasoning":"one short sentence","confidence":0.0-1.0}. TASK:
    """

    public static func classificationPrompt(for task: String) -> String {
        classifyInstructions + task
    }

    /// Extracts the classifier JSON from raw model output (handles ```json fences).
    public static func parse(response: String) -> TaskAnalysis? {
        guard let start = response.firstIndex(of: "{"),
              let end = response.lastIndex(of: "}"), start < end else { return nil }
        let jsonStr = String(response[start...end])
        guard let data = jsonStr.data(using: .utf8),
              let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let modelRaw = obj["model"] as? String else { return nil }

        let tierStr = modelRaw.lowercased().trimmingCharacters(in: .whitespaces)
        let tier: ModelTier
        switch tierStr {
        case "haiku":  tier = .haiku
        case "sonnet": tier = .sonnet
        case "opus":   tier = .opus
        default:       return nil
        }

        let conf: Double
        if let d = obj["confidence"] as? Double { conf = d }
        else if let n = obj["confidence"] as? NSNumber { conf = n.doubleValue }
        else { conf = 0 }

        return TaskAnalysis(
            tier: tier,
            situation: (obj["situation"] as? String) ?? "",
            reasoning: (obj["reasoning"] as? String) ?? "",
            confidence: max(0, min(1, conf)))
    }
}
