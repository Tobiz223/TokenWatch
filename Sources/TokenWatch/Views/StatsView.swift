import SwiftUI

private struct ModelSpend: Identifiable {
    let id: String       // model name
    let cost: Double
}

struct StatsView: View {
    @EnvironmentObject var store: UsageStore
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Statistics").font(.headline)
            Text("Month to date: \(store.monthToDateText)")
            Text("Requests this session: \(store.history.count)")
            Text(String(format: "Overkill overpay: $%.4f", store.totalOverpay))
                .foregroundColor(.orange)
            Divider()
            Text("By model").font(.subheadline).bold()
            ForEach(byModel()) { spend in
                HStack {
                    Text(shortModel(spend.id))
                    Spacer()
                    Text(String(format: "$%.4f", spend.cost))
                }
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func byModel() -> [ModelSpend] {
        var totals: [String: Double] = [:]
        for item in store.history { totals[item.record.model, default: 0] += item.cost }
        return totals
            .map { ModelSpend(id: $0.key, cost: $0.value) }
            .sorted { $0.cost > $1.cost }
    }

    private func shortModel(_ m: String) -> String {
        if m.contains("opus") { return "Opus" }
        if m.contains("sonnet") { return "Sonnet" }
        if m.contains("haiku") { return "Haiku" }
        return m
    }
}
