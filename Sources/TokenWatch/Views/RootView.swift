import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: UsageStore
    @EnvironmentObject var settings: Settings
    @State private var tab: Tab = .overview

    enum Tab: String, CaseIterable { case overview, history, advisor }

    private func tabTitle(_ t: Tab) -> String {
        switch t {
        case .overview: return settings.t("tab_overview")
        case .history:  return settings.t("tab_history")
        case .advisor:  return settings.t("tab_advisor")
        }
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                tabBar
                Rectangle().fill(Theme.line).frame(height: 1)
                content.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(width: 460, height: 540)
        .foregroundColor(Theme.text)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("TW")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(Theme.accent)
                .frame(width: 26, height: 26)
                .background(RoundedRectangle(cornerRadius: 7).fill(Theme.surface2))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.line, lineWidth: 1))
            VStack(alignment: .leading, spacing: 1) {
                Text("TokenWatch").font(.system(size: 14, weight: .semibold))
                Text(settings.t("tagline")).font(.system(size: 10.5)).foregroundColor(Theme.faint)
            }
            Spacer()
            langSeg
            currencySeg
        }
        .padding(.horizontal, 18).padding(.vertical, 13)
    }

    private var langSeg: some View {
        segBox {
            segButton("EN", active: settings.lang == .en) { settings.lang = .en }
            segButton("UK", active: settings.lang == .uk) { settings.lang = .uk }
        }
    }

    private var currencySeg: some View {
        segBox {
            segButton("$", active: settings.currency == .usd) { settings.currency = .usd }
            segButton("₴", active: settings.currency == .uah) { settings.currency = .uah }
        }
    }

    private func segBox<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 2) { content() }
            .padding(2)
            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.track))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 1))
    }

    private func segButton(_ label: String, active: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(active ? Theme.text : Theme.muted)
                .padding(.horizontal, 9).padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6).fill(active ? Theme.surface2 : Color.clear))
        }
        .buttonStyle(.plain)
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(Tab.allCases, id: \.self) { t in
                Button { tab = t } label: {
                    VStack(spacing: 8) {
                        Text(tabTitle(t))
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundColor(tab == t ? Theme.text : Theme.muted)
                        Rectangle().fill(tab == t ? Theme.accent : .clear).frame(height: 2)
                    }
                    .padding(.horizontal, 12).padding(.top, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 10)
    }

    @ViewBuilder private var content: some View {
        switch tab {
        case .overview: OverviewView()
        case .history:  HistoryView()
        case .advisor:  AdvisorView()
        }
    }
}
