import Foundation

public struct CostEngine {
    public let pricing: PricingTable
    public init(pricing: PricingTable) { self.pricing = pricing }

    public func cost(inputTokens: Int, outputTokens: Int,
                     cacheWriteTokens: Int, cacheReadTokens: Int, model: String) -> Double {
        let r = pricing.rates(for: model)
        let raw = Double(inputTokens) * r.input
                + Double(outputTokens) * r.output
                + Double(cacheWriteTokens) * r.cacheWrite
                + Double(cacheReadTokens) * r.cacheRead
        return raw / 1_000_000.0
    }

    public func cost(for record: UsageRecord) -> Double {
        cost(inputTokens: record.inputTokens, outputTokens: record.outputTokens,
             cacheWriteTokens: record.cacheWriteTokens, cacheReadTokens: record.cacheReadTokens,
             model: record.model)
    }

    public func total(_ records: [UsageRecord]) -> Double {
        records.reduce(0) { $0 + cost(for: $1) }
    }

    public func totalByModel(_ records: [UsageRecord]) -> [String: Double] {
        var out: [String: Double] = [:]
        for r in records { out[r.model, default: 0] += cost(for: r) }
        return out
    }

    public func totalByProject(_ records: [UsageRecord]) -> [String: Double] {
        var out: [String: Double] = [:]
        for r in records { out[r.project, default: 0] += cost(for: r) }
        return out
    }

    public func monthToDateTotal(_ records: [UsageRecord], now: Date, calendar: Calendar) -> Double {
        let comps = calendar.dateComponents([.year, .month], from: now)
        return total(records.filter {
            let c = calendar.dateComponents([.year, .month], from: $0.timestamp)
            return c.year == comps.year && c.month == comps.month
        })
    }
}
