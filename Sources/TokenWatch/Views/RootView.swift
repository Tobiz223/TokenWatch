import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: UsageStore
    var body: some View {
        TabView {
            HistoryView().tabItem { Text("History") }
            StatsView().tabItem { Text("Stats") }
            AdvisorView().tabItem { Text("Advisor") }
        }
        .frame(width: 380, height: 460)
        .padding(.top, 4)
    }
}
