import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var store: UsageStore
    var body: some View {
        VStack(alignment: .leading) {
            Text("Month to date: \(store.monthToDateText)").font(.headline).padding(.horizontal)
            List(store.history) { item in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(shortModel(item.record.model)).bold()
                        Text(String(format: "$%.4f", item.cost)).foregroundColor(.secondary)
                        if item.isOverkill {
                            Text("⚠️ overkill −$\(String(format: "%.4f", item.overpay))")
                                .font(.caption).foregroundColor(.orange)
                        }
                    }
                    Text("\(item.record.inputTokens)→\(item.record.outputTokens) tok")
                        .font(.caption).foregroundColor(.secondary)
                    if !item.record.promptPreview.isEmpty {
                        Text(item.record.promptPreview).font(.caption).lineLimit(1)
                    }
                }
            }
        }
    }
    private func shortModel(_ m: String) -> String {
        if m.contains("opus") { return "Opus" }
        if m.contains("sonnet") { return "Sonnet" }
        if m.contains("haiku") { return "Haiku" }
        return m
    }
}
