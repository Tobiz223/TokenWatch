import Foundation

public func shortModelName(_ m: String) -> String {
    let l = m.lowercased()
    if l.contains("opus") { return "Opus" }
    if l.contains("sonnet") { return "Sonnet" }
    if l.contains("haiku") { return "Haiku" }
    return m
}

/// One assistant API call within a request.
public struct RequestCall: Identifiable {
    public let id: String
    public let short: String
    public let model: String
    public let cost: Double
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheReadTokens: Int
    public let cacheWriteTokens: Int
    public let isOverkill: Bool
    public let overpay: Double
    public let timestamp: Date
}

/// One of *our* requests (a user turn) with all the model calls it triggered.
public struct RequestGroup: Identifiable {
    public let id: String        // turnId
    public let title: String
    public let timestamp: Date
    public let project: String
    public let models: [String]
    public let cost: Double
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheReadTokens: Int
    public let cacheWriteTokens: Int
    public let isOverkill: Bool
    public let overpay: Double
    public let calls: [RequestCall]
    public var callCount: Int { calls.count }
}

/// Groups assistant records under the user request that triggered them.
public struct RequestGrouper {
    public let costEngine: CostEngine
    public let detector: OverkillDetector

    public init(costEngine: CostEngine, detector: OverkillDetector) {
        self.costEngine = costEngine
        self.detector = detector
    }

    public func groups(from records: [UsageRecord], limit: Int = 200) -> [RequestGroup] {
        final class Acc {
            var title = ""
            var timestamp = Date.distantFuture
            var project = ""
            var cost = 0.0
            var inTok = 0, outTok = 0, cRead = 0, cWrite = 0
            var over = false
            var overpay = 0.0
            var models: [String] = []
            var calls: [RequestCall] = []
        }

        var accs: [String: Acc] = [:]
        var order: [String] = []

        for r in records {
            let key = r.turnId
            let a: Acc
            if let existing = accs[key] {
                a = existing
            } else {
                a = Acc()
                a.timestamp = r.timestamp
                a.title = r.promptPreview
                a.project = r.project
                accs[key] = a
                order.append(key)
            }
            let cost = costEngine.cost(for: r)
            let res = detector.evaluate(r)
            a.cost += cost
            a.inTok += r.inputTokens
            a.outTok += r.outputTokens
            a.cRead += r.cacheReadTokens
            a.cWrite += r.cacheWriteTokens
            if res.isOverkill { a.over = true; a.overpay += res.overpay }
            if a.title.isEmpty, !r.promptPreview.isEmpty { a.title = r.promptPreview }
            let sm = shortModelName(r.model)
            if !a.models.contains(sm) { a.models.append(sm) }
            if r.timestamp < a.timestamp { a.timestamp = r.timestamp }
            a.calls.append(RequestCall(
                id: r.id ?? UUID().uuidString, short: sm, model: r.model, cost: cost,
                inputTokens: r.inputTokens, outputTokens: r.outputTokens,
                cacheReadTokens: r.cacheReadTokens, cacheWriteTokens: r.cacheWriteTokens,
                isOverkill: res.isOverkill, overpay: res.overpay, timestamp: r.timestamp))
        }

        var result = order.map { key -> RequestGroup in
            let a = accs[key]!
            return RequestGroup(id: key, title: a.title, timestamp: a.timestamp, project: a.project,
                                models: a.models, cost: a.cost, inputTokens: a.inTok, outputTokens: a.outTok,
                                cacheReadTokens: a.cRead, cacheWriteTokens: a.cWrite,
                                isOverkill: a.over, overpay: a.overpay, calls: a.calls)
        }
        result.sort { $0.timestamp > $1.timestamp }
        return Array(result.prefix(limit))
    }
}
