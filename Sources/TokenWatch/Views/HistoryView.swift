import SwiftUI
import TokenWatchCore

struct HistoryView: View {
    @EnvironmentObject var store: UsageStore
    @EnvironmentObject var settings: Settings
    @State private var expanded = Set<String>()

    private let cols: [GridItem] = [
        GridItem(.fixed(15)),
        GridItem(.fixed(60), alignment: .leading),
        GridItem(.flexible(), alignment: .leading),
        GridItem(.fixed(72), alignment: .trailing),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
            Rectangle().fill(Theme.line).frame(height: 1)
            if store.requests.isEmpty {
                Text(settings.t("empty"))
                    .font(.system(size: 12)).foregroundColor(Theme.faint)
                    .frame(maxWidth: .infinity).padding(.vertical, 30)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.requests) { g in row(g) }
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
            colTitle(settings.t("col_request"))
            colTitle(settings.t("col_cost"))
        }
        .padding(.bottom, 8).padding(.horizontal, 2)
    }

    private func colTitle(_ s: String) -> some View {
        Text(s.uppercased())
            .font(.system(size: 10, weight: .medium)).tracking(0.6)
            .foregroundColor(Theme.faint)
    }

    private func row(_ g: RequestGroup) -> some View {
        let isOpen = expanded.contains(g.id)
        let title = g.title.isEmpty ? settings.t("no_prompt") : g.title
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                if isOpen { expanded.remove(g.id) } else { expanded.insert(g.id) }
            } label: {
                LazyVGrid(columns: cols, alignment: .leading, spacing: 10) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold)).foregroundColor(Theme.faint)
                        .rotationEffect(.degrees(isOpen ? 90 : 0))
                    Text(when(g.timestamp)).font(.system(size: 11, design: .monospaced)).foregroundColor(Theme.faint)
                    HStack(spacing: 7) {
                        HStack(spacing: 3) {
                            ForEach(g.models, id: \.self) { m in
                                Circle().fill(Theme.familyColor(m)).frame(width: 7, height: 7)
                            }
                        }
                        Text(title).font(.system(size: 12)).lineLimit(1)
                        Text("\(g.callCount)×")
                            .font(.system(size: 9.5, design: .monospaced)).foregroundColor(Theme.faint)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Theme.line, lineWidth: 1))
                    }
                    Text(settings.money(g.cost, precise: true))
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundColor(g.isOverkill ? Theme.red : Theme.text)
                }
                .padding(.vertical, 9).padding(.horizontal, 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isOpen { detail(g).padding(.leading, 21).padding(.bottom, 12) }
            Rectangle().fill(Theme.lineSoft).frame(height: 1)
        }
        .overlay(alignment: .leading) {
            if g.isOverkill {
                RoundedRectangle(cornerRadius: 2).fill(Theme.red).frame(width: 2).padding(.vertical, 8)
            }
        }
    }

    private func detail(_ g: RequestGroup) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            kv(settings.t("models_label"), g.models.joined(separator: " · "))
            kv(settings.t("col_tokens"),
               "in \(settings.num(g.inputTokens)) · out \(settings.num(g.outputTokens)) · cache r \(settings.num(g.cacheReadTokens)) · cache w \(settings.num(g.cacheWriteTokens))")
            kv(settings.t("col_cost"), settings.money(g.cost, precise: true))
            kv("Project", g.project)

            if !g.title.isEmpty {
                Text(g.title)
                    .font(.system(size: 11.5)).foregroundColor(Color(hex: 0xBFCADC))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.track))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 1))
                    .padding(.top, 2)
            }
            if g.isOverkill {
                Text(settings.overkillFlag(amount: settings.money(g.overpay, precise: true)))
                    .font(.system(size: 11)).foregroundColor(Theme.red).padding(.top, 2)
            }

            VStack(spacing: 0) {
                ForEach(g.calls) { c in callRow(c) }
            }
            .padding(.top, 6)
        }
        .padding(.top, 4)
    }

    private func callRow(_ c: RequestCall) -> some View {
        HStack(spacing: 10) {
            Text(callTime(c.timestamp)).font(.system(size: 11, design: .monospaced))
                .foregroundColor(Theme.faint).frame(width: 62, alignment: .leading)
            HStack(spacing: 6) {
                Circle().fill(Theme.familyColor(c.short)).frame(width: 6, height: 6)
                Text("\(c.short) · \(settings.num(c.inputTokens))→\(settings.num(c.outputTokens))")
                    .font(.system(size: 11, design: .monospaced)).foregroundColor(Theme.muted)
            }
            Spacer()
            Text(settings.money(c.cost, precise: true))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(c.isOverkill ? Theme.red : Theme.text)
        }
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.lineSoft).frame(height: 1) }
    }

    private func kv(_ k: String, _ v: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(k).font(.system(size: 11.5)).foregroundColor(Theme.faint)
                .frame(width: 58, alignment: .leading)
            Text(v).font(.system(size: 11.5, design: .monospaced)).foregroundColor(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private func when(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MMM dd  HH:mm"; return f.string(from: d)
    }
    private func callTime(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; return f.string(from: d)
    }
}
