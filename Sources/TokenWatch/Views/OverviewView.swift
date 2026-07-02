import SwiftUI

struct OverviewView: View {
    @EnvironmentObject var store: UsageStore

    private var meterFraction: CGFloat {
        guard store.allTime > 0 else { return 0 }
        return max(0.04, CGFloat(store.monthToDate / store.allTime))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Eyebrow("Month to date")
                    .padding(.top, 16)

                Text(usd(store.monthToDate))
                    .font(.system(size: 52, weight: .heavy, design: .monospaced))
                    .foregroundColor(Theme.amber)
                    .shadow(color: Theme.amber.opacity(0.28), radius: 18)
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.5), value: store.monthToDate)
                    .padding(.top, 6)

                meter.padding(.top, 14)

                HStack(spacing: 10) {
                    statCard("All-time spend", usd(store.allTime))
                    statCard("Requests", store.history.count.formatted())
                }
                .padding(.top, 16)

                if store.totalOverpay > 0.0001 { overkillAlert.padding(.top, 14) }

                Eyebrow("Spend by model").padding(.top, 20)
                VStack(spacing: 10) {
                    ForEach(store.byModel) { m in modelBar(m) }
                }
                .padding(.top, 10)

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
    }

    private var meter: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.track)
                    Capsule()
                        .fill(LinearGradient(colors: [Theme.amberDk, Theme.amber],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * meterFraction)
                }
            }
            .frame(height: 6)
            .overlay(Capsule().stroke(Theme.hair, lineWidth: 1))

            HStack {
                Text("● meter running")
                    .foregroundColor(Theme.mint)
                Spacer()
                Text("\(Int(meterFraction * 100))% of all-time")
                    .foregroundColor(Theme.muted)
            }
            .font(.system(size: 10, design: .monospaced))
        }
    }

    private func statCard(_ key: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(key.uppercased())
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .tracking(1.2)
                .foregroundColor(Theme.muted)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 11).fill(Theme.slate2))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(Theme.hair, lineWidth: 1))
    }

    private var overkillAlert: some View {
        HStack(alignment: .top, spacing: 11) {
            Text("⚠").foregroundColor(Theme.coral)
            (Text("You overpaid ")
             + Text(usd(store.totalOverpay)).foregroundColor(Theme.coral).bold()
             + Text(" on \(store.overkillCount) simple task\(store.overkillCount == 1 ? "" : "s") — Haiku would have covered them."))
                .font(.system(size: 12.5))
                .foregroundColor(Theme.text)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 11).fill(Theme.coral.opacity(0.09)))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(Theme.coral.opacity(0.30), lineWidth: 1))
    }

    private func modelBar(_ m: ModelSpend) -> some View {
        let maxCost = store.byModel.map(\.cost).max() ?? 1
        let frac = maxCost > 0 ? max(0.03, CGFloat(m.cost / maxCost)) : 0
        return HStack(spacing: 10) {
            Text(m.short)
                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                .frame(width: 60, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.track)
                    Capsule().fill(Theme.barGradient(for: m.short))
                        .frame(width: geo.size.width * frac)
                }
            }
            .frame(height: 9)
            Text(usd(m.cost))
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Theme.muted)
                .frame(width: 68, alignment: .trailing)
        }
    }
}
