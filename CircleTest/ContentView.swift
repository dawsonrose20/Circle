import SwiftUI

enum Tab {
    case home, buzz, trading, league
}

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: Tab = .home
    @State private var showSettings = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Group {
                    switch selectedTab {
                    case .home:
                        HomeView()
                    case .buzz:
                        BuzzView()
                    case .trading:
                        TradingView()
                    case .league:
                        LeagueView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                CustomTabBar(selectedTab: $selectedTab)
            }
            // Keep the tab bar anchored to the bottom instead of riding up
            // with the keyboard when typing in a field (e.g. the Trading tab).
            .ignoresSafeArea(.keyboard, edges: .bottom)

            ConfettiOverlay()
        }
        .ignoresSafeArea(edges: .top)
        .preferredColorScheme(.dark)
        .environment(\.openSettings, { showSettings = true })
        .sheet(isPresented: $showSettings) {
            SettingsView(isPresented: $showSettings)
                .environmentObject(appState)
        }
        .fullScreenCover(isPresented: $appState.draftActive) {
            DraftView()
                .environmentObject(appState)
        }
        .onAppear {
            let navAppearance = UINavigationBarAppearance()
            navAppearance.configureWithOpaqueBackground()
            navAppearance.backgroundColor = UIColor(Color.cBg)
            navAppearance.titleTextAttributes = [.foregroundColor: UIColor(Color.cTextPrimary)]
            navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor(Color.cTextPrimary)]
            UINavigationBar.appearance().standardAppearance = navAppearance
            UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        }
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: Tab

    private let items: [(tab: Tab, icon: String, label: String)] = [
        (.home,    "house.fill",                   "Home"),
        (.buzz,    "bolt.fill",                    "Buzz"),
        (.trading, "chart.line.uptrend.xyaxis",    "Trading"),
        (.league,  "person.3.fill",                "League"),
    ]

    var body: some View {
        HStack(spacing: CircleSpace.xxs) {
            ForEach(items, id: \.tab.hashValue) { item in
                Button {
                    selectedTab = item.tab
                } label: {
                    let active = selectedTab == item.tab
                    VStack(spacing: 5) {
                        Image(systemName: item.icon)
                            .font(.system(size: CircleIcon.tabBar, weight: .medium))
                        Text(item.label)
                            .font(.system(size: 10, weight: active ? .medium : .regular))
                    }
                    .foregroundStyle(active ? Color.cAccent : Color.cTextSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, CircleSpace.xs)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, CircleSpace.mdPlus)
        .padding(.vertical, CircleSpace.md)
        .background(Color.cBg)
        .overlay(alignment: .top) {
            CircleDivider(weight: .section)
        }
        .background(Color.cBg.ignoresSafeArea(edges: .bottom))
    }
}

extension Tab: Hashable {}

#Preview {
    ContentView()
        .environmentObject(AppState.preview)
}
