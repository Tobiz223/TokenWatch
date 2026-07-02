import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: UsageStore
    @State private var tab: Tab = .overview

    enum Tab: String, CaseIterable {
        case overview = "Overview"
        case receipt  = "Receipt"
        case advisor  = "Advisor"
    }

    var body: some View {
        ZStack {
            Theme.ink.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                tabBar
                Rectangle().fill(Theme.hair).frame(height: 1)
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(width: 420, height: 520)
        .foregroundColor(Theme.text)
    }

    private var header: some View {
        HStack {
            HStack(spacing: 9) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(LinearGradient(colors: [Theme.amber, Theme.amberDk],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 22, height: 22)
                    .overlay(Text("👁").font(.system(size: 12)))
                Text("TokenWatch")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            Spacer()
            HStack(spacing: 5) {
                Circle().fill(Theme.mint).frame(width: 6, height: 6)
                Text("live · updated \(store.updatedAt)")
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundColor(Theme.muted)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var tabBar: some View {
        HStack(spacing: 2) {
            ForEach(Tab.allCases, id: \.self) { t in
                Button {
                    withAnimation(.easeOut(duration: 0.18)) { tab = t }
                } label: {
                    VStack(spacing: 8) {
                        Text(t.rawValue)
                            .font(.system(size: 12.5, weight: .medium, design: .rounded))
                            .foregroundColor(tab == t ? Theme.text : Theme.muted)
                        Rectangle()
                            .fill(tab == t ? Theme.amber : .clear)
                            .frame(height: 2)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 11)
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
        case .receipt:  ReceiptView()
        case .advisor:  AdvisorView()
        }
    }
}
