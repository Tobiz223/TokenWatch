import SwiftUI

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
            ForEach(byModel(), id: \.0) { name, cost in
                HStack { Text(name); Spacer(); Text(String(format: "$%.4f", cost)) }
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    private func byModel() -> [(String, Double)] {
        var totals: [String: Double] = [:]
        for item in store.history { totals[item.record.model, default: 0] += item.cost }
        return totals.sorted { $0.value > $1.value }
    }
}
