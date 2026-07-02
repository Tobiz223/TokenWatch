import Foundation

public struct Rates: Codable, Equatable {
    public let input: Double
    public let output: Double
    public let cacheWrite: Double
    public let cacheRead: Double
    public init(input: Double, output: Double, cacheWrite: Double, cacheRead: Double) {
        self.input = input; self.output = output
        self.cacheWrite = cacheWrite; self.cacheRead = cacheRead
    }
}

public enum PricingError: Error { case missingDefault }

public struct PricingTable: Equatable {
    public let rates: [String: Rates]
    public let defaultRates: Rates

    public init(rates: [String: Rates], defaultRates: Rates) {
        self.rates = rates
        self.defaultRates = defaultRates
    }

    /// Resolves rates for a model id. Tries an exact match first, then a model-family
    /// match (opus/sonnet/haiku found as a substring), then the default. Family matching
    /// keeps versioned ids like "claude-sonnet-4-6" priced correctly.
    public func rates(for model: String) -> Rates {
        if let exact = rates[model] { return exact }
        if let family = Self.familyKey(for: model), let familyRates = rates[family] { return familyRates }
        return defaultRates
    }

    public func isKnown(_ model: String) -> Bool {
        if rates[model] != nil { return true }
        if let family = Self.familyKey(for: model) { return rates[family] != nil }
        return false
    }

    static func familyKey(for model: String) -> String? {
        let m = model.lowercased()
        for family in ["opus", "sonnet", "haiku"] where m.contains(family) { return family }
        return nil
    }

    public static func load(from data: Data) throws -> PricingTable {
        var all = try JSONDecoder().decode([String: Rates].self, from: data)
        guard let def = all.removeValue(forKey: "default") else { throw PricingError.missingDefault }
        return PricingTable(rates: all, defaultRates: def)
    }

    public static func bundled() -> PricingTable {
        if let url = Bundle.module.url(forResource: "pricing", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let table = try? load(from: data) {
            return table
        }
        // Safe fallback if the resource is missing — keeps family pricing correct
        // even when the bundled JSON can't be located (e.g. a hand-assembled .app).
        return PricingTable(
            rates: [
                "opus":   Rates(input: 15.0, output: 75.0, cacheWrite: 18.75, cacheRead: 1.5),
                "sonnet": Rates(input: 3.0,  output: 15.0, cacheWrite: 3.75,  cacheRead: 0.3),
                "haiku":  Rates(input: 1.0,  output: 5.0,  cacheWrite: 1.25,  cacheRead: 0.1),
            ],
            defaultRates: Rates(input: 3.0, output: 15.0, cacheWrite: 3.75, cacheRead: 0.3))
    }
}
