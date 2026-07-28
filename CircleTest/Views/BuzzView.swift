import SwiftUI

// MARK: - BuzzView
//
// Root scroll view for the Buzz tab. Sections assemble in order:
//   1. Nav bar with notification button
//   2. BuzzHeroContest — "Today's play" featured contest
//   3. SectionHeader — "More Contests" / live count badge
//   4. Contest list rows
//   5. SectionHeader — "Trending Now"
//   6. BuzzTrendingBlocks (biggest trade, top trader, hottest stock)
//   7. SectionHeader — "Global Leaderboard"
//   8. BuzzGlobalLeaderboard

struct BuzzView: View {
    @EnvironmentObject var appState: AppState

    @State private var revealPhase: Int = 0

    // Real data — populated when API is connected
    @State private var featuredContest: Contest? = nil
    @State private var contests: [Contest] = []
    @State private var leaderboardRankers: [GlobalRanker] = []
    @State private var trendingTrade: TrendingTrade? = nil
    @State private var topTrader: TopTrader? = nil
    @State private var hotStock: HotStock? = nil

    private var liveCount: Int { contests.filter { $0.isLive }.count }

    var body: some View {
        VStack(spacing: 0) {
            nav

            ScrollView {
                LazyVStack(spacing: 0) {

                    // --- Hero contest ---
                    Group {
                        if let featured = featuredContest {
                            BuzzHeroContest(contest: featured)
                        } else {
                            heroPlaceholder
                        }
                    }
                    .opacity(revealPhase >= 1 ? 1 : 0)
                    .offset(y: revealPhase >= 1 ? 0 : 12)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: revealPhase)

                    CircleDivider(weight: .section)

                    // --- More contests ---
                    SectionHeader(
                        title: "More Contests",
                        subtitle: "Open now",
                        trailing: liveCount > 0 ? "\(liveCount) live" : nil
                    )
                    .opacity(revealPhase >= 2 ? 1 : 0)
                    .animation(.easeOut(duration: 0.25).delay(0.05), value: revealPhase)

                    contestList
                        .opacity(revealPhase >= 2 ? 1 : 0)
                        .animation(.easeOut(duration: 0.3).delay(0.1), value: revealPhase)

                    CircleDivider(weight: .section)

                    // --- Trending now ---
                    SectionHeader(title: "Trending Now", subtitle: "Last 24 hours")
                        .opacity(revealPhase >= 3 ? 1 : 0)
                        .animation(.easeOut(duration: 0.25).delay(0.05), value: revealPhase)

                    trendingSection
                        .opacity(revealPhase >= 3 ? 1 : 0)
                        .animation(.easeOut(duration: 0.3).delay(0.1), value: revealPhase)

                    CircleDivider(weight: .section)

                    // --- Global leaderboard ---
                    SectionHeader(title: "Global Leaderboard", subtitle: "All-time standings")
                        .opacity(revealPhase >= 4 ? 1 : 0)
                        .animation(.easeOut(duration: 0.25).delay(0.05), value: revealPhase)

                    BuzzGlobalLeaderboard(rankers: leaderboardRankers)
                        .opacity(revealPhase >= 4 ? 1 : 0)
                        .animation(.easeOut(duration: 0.3).delay(0.1), value: revealPhase)

                    // Bottom safe-area buffer
                    Spacer().frame(height: CircleSpace.xl)
                }
            }
            .background(Color.cBg)
        }
        .background(Color.cBg)
        .onAppear { startReveal() }
    }

    // MARK: Nav bar

    private var nav: some View {
        HStack {
            Spacer()
            NavTrailingChrome(
                userInitials: String((appState.currentUser?.name.prefix(2) ?? "ME").uppercased())
            )
        }
        .padding(.horizontal, CircleSpace.lg)
        .padding(.top, 60)
        .padding(.bottom, CircleSpace.base)
    }

    // MARK: Hero placeholder

    private var heroPlaceholder: some View {
        VStack(spacing: CircleSpace.base) {
            Image(systemName: "trophy")
                .font(.system(size: 32))
                .foregroundStyle(Color.cTextTertiary)
            Text("No active contest right now")
                .font(.cBodyEmphasis)
                .foregroundStyle(Color.cTextSecondary)
            Text("Check back when markets open")
                .font(.cMeta)
                .foregroundStyle(Color.cTextTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CircleSpace.xl)
        .padding(.horizontal, CircleSpace.lg)
    }

    // MARK: Contest list

    private var contestList: some View {
        Group {
            if contests.isEmpty {
                Text("No contests available")
                    .font(.cBody)
                    .foregroundStyle(Color.cTextTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, CircleSpace.xl)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(contests.enumerated()), id: \.element.id) { idx, contest in
                        BuzzContestRow(contest: contest)
                        if idx < contests.count - 1 {
                            CircleDivider(weight: .row)
                        }
                    }
                }
            }
        }
    }

    // MARK: Trending section

    private var trendingSection: some View {
        Group {
            if let trade = trendingTrade, let trader = topTrader, let stock = hotStock {
                BuzzTrendingBlocks(trade: trade, trader: trader, hotStock: stock)
            } else {
                Text("Trending data unavailable")
                    .font(.cBody)
                    .foregroundStyle(Color.cTextTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, CircleSpace.xl)
            }
        }
    }

    // MARK: Staggered reveal

    private func startReveal() {
        for phase in 1...4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(phase - 1) * 0.12) {
                withAnimation {
                    revealPhase = phase
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Buzz") {
    BuzzView()
        .environmentObject(AppState.preview)
        .preferredColorScheme(.dark)
}
