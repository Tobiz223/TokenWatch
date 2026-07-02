import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var store: UsageStore
    @EnvironmentObject var settings: Settings
    @State private var expanded = Set<String>()

    private let cols: [GridItem] = [
        GridItem(.fixed(15)),
        GridItem(.fixed(66)),
        GridItem(.flexible(), alignment: .leading),
        GridItem(.fixed(78), alignment: .trailing),
        GridItem(.fixed(70), alignment: .trailing),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
            Rectangle().fill(Theme.line).frame(height: 1)
            if store.history.isEmpty {
                Text(settings.t("empty"))
                    .font(.system(size: 12)).foregroundColor(Theme.faint)
                    .frame(maxWidth: .infinity).padding(.vertical, 30)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.history.prefix(120)) { item in row(item) }
                    }
                }
            }
        }
        .padding(.horizontal, 18).padding(.top, 16)
    }

    private var headerRow: some View {
        LazyVGrid(columns: cols, alignment: .leading, spacing: 10) {
            Text("")
            colTitle(settings.t("col_time"))
            colTitle(settings.t("col_model"))
            colTitle(settings.t("col_tokens"))
            colTitle(settings.t("col_cost"))
        }
        .padding(.bottom, 8).padding(.horizontal, 2)
    }

    private func colTitle(_ s: String) -> some View {
        Text(s.uppercased())
            .font(.system(size: 10, weight: .medium)).tracking(0.6)
            .foregroundColor(Theme.faint)
    }

    private func row(_ item: HistoryItem) -> some View {
        let isOpen = expanded.contains(item.id)
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                if isOpen { expanded.remove(item.id) } else { expanded.insert(item.id) }
            } label: {
                LazyVGrid(columns: cols, alignment: .leading, spacing: 10) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Theme.faint)
                        .rotationEffect(.degrees(isOpen ? 90 : 0))
                    Text(when(item)).font(.system(size: 11, design: .monospaced)).foregroundColor(Theme.faint)
                    HStack(spacing: 7) {
                        Circle().fill(Theme.familyColor(shortModel(item.record.model))).frame(width: 7, height: 7)
                        Text(shortModel(item.record.model)).font(.system(size: 12)).lineLimit(1)
                    }
                    Text("\(settings.num(item.record.inputTokens))→\(settings.num(item.record.outputTokens))")
                        .font(.system(size: 11.5, design: .monospaced)).foregroundColor(Theme.muted)
                    Text(settings.money(item.cost, precise: true))
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundColor(item.isOverkill ? Theme.red : Theme.text)
                }
                .padding(.vertical, 9).padding(.horizontal, 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isOpen { detail(item).padding(.leading, 21).padding(.bottom, 12) }
            Rectangle().fill(Theme.lineSoft).frame(height: 1)
        }
        .overlay(alignment: .leading) {
            if item.isOverkill {
                RoundedRectangle(cornerRadius: 2).fill(Theme.red).frame(width: 2).padding(.vertical, 8)
            }
        }
    }

    private func detail(_ item: HistoryItem) -> some View {
        let r = item.record
        return VStack(alignment: .leading, spacing: 6) {
            kv(settings.t("col_model"), r.model)
            kv(settings.t("col_tokens"),
               "in \(settings.num(r.inputTokens)) · out \(settings.num(r.outputTokens)) · cache r \(settings.num(r.cacheReadTokens)) · cache w \(settings.num(r.cacheWriteTokens))")
            kv(settings.t("col_cost"), settings.money(item.cost, precise: true))
            kv("Project", r.project)
            if !r.promptPreview.isEmpty {
                Text(r.promptPreview)
                    .font(.system(size: 11.5)).foregroundColor(Color(hex: 0xBFCADC))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.track))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 1))
                    .padding(.top, 2)
            }
            if item.isOverkill {
                Text(settings.overkillFlag(amount: settings.money(item.overpay, precise: true)))
                    .font(.system(size: 11)).foregroundColor(Theme.red).padding(.top, 2)
            }
        }
        .padding(.top, 4)
    }

    private func kv(_ k: String, _ v: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(k).font(.system(size: 11.5)).foregroundColor(Theme.faint)
                .frame(width: 58, alignment: .leading)
            Text(v).font(.system(size: 11.5, design: .monospaced))
                .foregroundColor(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private func when(_ item: HistoryItem) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM dd  HH:mm"
        return f.string(from: item.record.timestamp)
    }
}
