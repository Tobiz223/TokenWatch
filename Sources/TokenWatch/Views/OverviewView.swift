import SwiftUI

struct OverviewView: View {
    @EnvironmentObject var store: UsageStore
    @EnvironmentObject var settings: Settings

    private var meterFraction: CGFloat {
        guard store.allTime > 0 else { return 0 }
        return max(0.03, CGFloat(store.monthToDate / store.allTime))
    }
    private var meterPct: Int { Int(meterFraction * 100) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SectionLabel(settings.t("month_to_date")).padding(.top, 16)

                Text(settings.money(store.monthToDate))
                    .font(.system(size: 42, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.text)
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.5), value: store.monthToDate)
                    .padding(.top, 12)

                meter.padding(.top, 14)

                HStack(spacing: 10) {
                    card(settings.t("all_time"), settings.money(store.allTime))
                    card(settings.t("requests"), settings.num(store.history.count))
                }
                .padding(.top, 18)

                if store.totalOverpay > 0.0001 { notice.padding(.top, 14) }

                SectionLabel(settings.t("by_model")).padding(.top, 20)
                VStack(spacing: 11) {
                    ForEach(store.byModel) { m in bar(m) }
                }
                .padding(.top, 12)

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 18).padding(.bottom, 18)
        }
    }

    private var meter: some View {
        VStack(spacing: 5) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Theme.track)
                    RoundedRectangle(cornerRadius: 3).fill(Theme.accent.opacity(0.9))
                        .frame(width: geo.size.width * meterFraction)
                }
            }
            .frame(height: 5)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Theme.line, lineWidth: 1))

            HStack {
                Text(settings.t("meter_run"))
                Spacer()
                Text("\(meterPct)% \(settings.t("of_all_time"))")
            }
            .font(.system(size: 10, design: .monospaced))
            .foregroundColor(Theme.faint)
        }
    }

    private func card(_ key: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(key.uppercased())
                .font(.system(size: 10, weight: .medium)).tracking(0.8)
                .foregroundColor(Theme.faint)
            Text(value).font(.system(size: 19, weight: .bold, design: .monospaced))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface2))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
    }

    private var notice: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2).fill(Theme.red).frame(width: 3)
            Text(settings.overkillMessage(amount: settings.money(store.totalOverpay, precise: true),
                                          count: store.overkillCount))
                .font(.system(size: 12)).foregroundColor(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.red.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.red.opacity(0.28), lineWidth: 1))
    }

    private func bar(_ m: ModelSpend) -> some View {
        let maxCost = store.byModel.map(\.cost).max() ?? 1
        let frac = maxCost > 0 ? max(0.03, CGFloat(m.cost / maxCost)) : 0
        return HStack(spacing: 12) {
            HStack(spacing: 7) {
                Circle().fill(Theme.familyColor(m.short)).frame(width: 7, height: 7)
                Text(m.short).font(.system(size: 12.5))
            }
            .frame(width: 78, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Theme.track)
                    RoundedRectangle(cornerRadius: 3).fill(Theme.familyColor(m.short))
                        .frame(width: geo.size.width * frac)
                }
            }
            .frame(height: 6)
            Text(settings.money(m.cost, precise: true))
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Theme.muted)
                .frame(width: 76, alignment: .trailing)
        }
    }
}
