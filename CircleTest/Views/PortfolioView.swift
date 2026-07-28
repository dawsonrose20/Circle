import SwiftUI

struct PortfolioView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let user = appState.currentUser {
                    heroHeader(user)
                    rosterList(user.roster)
                        .padding(.bottom, 40)
                } else {
                    ContentUnavailableView("No Team Found", systemImage: "person.slash")
                        .padding(.top, 120)
                }
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Hero Header

    private func heroHeader(_ user: LeagueMember) -> some View {
        let gainLoss = user.totalWeeklyGainLoss
        let ret = user.totalWeeklyReturn
        let isPositive = gainLoss >= 0

        return ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [
                    isPositive ? Theme.green.opacity(0.5) : Theme.negative.opacity(0.4),
                    Theme.background
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 300)

            Circle()
                .fill(isPositive ? Theme.green.opacity(0.12) : Theme.negative.opacity(0.1))
                .frame(width: 260, height: 260)
                .offset(x: 160, y: -40)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.teamName)
                            .font(.system(size: 32, weight: .black))
                            .foregroundStyle(.white)
                        Text("\(user.name)  ·  \(user.wins)W–\(user.losses)L")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                    let rank = appState.league.standings.firstIndex(where: { $0.id == user.id }).map { $0 + 1 } ?? 0
                    VStack(spacing: 2) {
                        ZStack {
                            Circle()
                                .fill(rank == 1 ? Theme.green : Theme.surfaceRaised)
                                .frame(width: 50, height: 50)
                            Text("#\(rank)")
                                .font(.system(size: 17, weight: .black))
                                .foregroundStyle(rank == 1 ? .black : .white)
                        }
                        Text("RANK")
                            .font(.system(size: 9, weight: .black))
                            .tracking(1)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }

                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(gainLoss >= 0 ? "+" : "")
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(isPositive ? Theme.green : Theme.negative)
                    + Text(abs(gainLoss), format: .currency(code: "USD"))
                        .font(.system(size: 44, weight: .black))
                        .foregroundStyle(isPositive ? Theme.green : Theme.negative)

                    Text(String(format: "(%@%.2f%%)", ret >= 0 ? "+" : "", ret * 100))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(isPositive ? Theme.green.opacity(0.8) : Theme.negative.opacity(0.8))
                        .padding(.bottom, 4)
                }

                Text("THIS WEEK")
                    .font(.system(size: 10, weight: .black))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
    }

    // MARK: - Roster

    private func rosterList(_ roster: [Stock]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Roster")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(.white)
                    .textCase(.uppercase)
                Spacer()
                Text("\(roster.count) stocks")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 16)

            if roster.isEmpty {
                ContentUnavailableView(
                    "No Stocks Drafted",
                    systemImage: "plus.circle.dashed",
                    description: Text("Head to the Draft tab to pick your stocks.")
                )
            } else {
                ForEach(Array(roster.enumerated()), id: \.element.id) { index, stock in
                    portfolioStockRow(stock)
                    if index < roster.count - 1 {
                        Divider()
                            .background(Theme.surfaceRaised)
                            .padding(.leading, 20)
                    }
                }
            }
        }
    }

    private func portfolioStockRow(_ stock: Stock) -> some View {
        let isPositive = stock.weeklyGainLoss >= 0
        let barWidth = min(1.0, abs(stock.weeklyReturn) / 0.08)

        return HStack(spacing: 16) {
            Text(stock.id)
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(Theme.green)
                .frame(width: 46)

            VStack(alignment: .leading, spacing: 5) {
                Text(stock.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Theme.surfaceRaised)
                            .frame(height: 3)
                        Rectangle()
                            .fill(isPositive ? Theme.green : Theme.negative)
                            .frame(width: geo.size.width * barWidth, height: 3)
                    }
                }
                .frame(height: 3)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(stock.currentPrice, format: .currency(code: "USD"))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                HStack(spacing: 2) {
                    Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 9))
                    Text(String(format: "%@%.2f%%", isPositive ? "+" : "", stock.weeklyReturn * 100))
                        .font(.caption)
                        .fontWeight(.bold)
                }
                .foregroundStyle(isPositive ? Theme.positive : Theme.negative)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}

#Preview {
    PortfolioView()
        .environmentObject(AppState.preview)
        .preferredColorScheme(.dark)
}
