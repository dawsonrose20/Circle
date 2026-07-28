import SwiftUI

// MARK: - TeamDetailView
//
// Shows a full team profile: hero section, record, portfolio value,
// and read-only roster list. Pushed from LeagueView standings rows.

struct TeamDetailView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let member: LeagueMember

    // Staggered reveal state
    @State private var revealPhase: Int = 0

    private var portfolioValue: Double {
        10_000 + member.totalWeeklyGainLoss * 10 + Double(member.wins) * 200
    }

    private var weeklyReturn: Double {
        member.totalWeeklyReturn
    }

    private var teamColor: CircleAvatar.TeamColor {
        member.isCurrentUser ? .selfBrand : CircleAvatar.TeamColor.forUserID(member.id.uuidString)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                CircleTopNav(
                    .titled(
                        eyebrow: "League · Team",
                        title: member.isCurrentUser ? "You" : member.name,
                        onBack: { dismiss() }
                    )
                ) {
                    EmptyView()
                }

                heroSection
                    .opacity(revealPhase >= 1 ? 1 : 0)
                    .offset(y: revealPhase >= 1 ? 0 : 12)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: revealPhase)

                CircleDivider(weight: .section)

                rosterSection
            }
        }
        .background(Color.cBg)
        .onAppear { startReveal() }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: CircleSpace.md) {
            // Avatar
            CircleAvatar(
                initials: String((member.isCurrentUser ? "ME" : member.name).prefix(2)).uppercased(),
                team: teamColor,
                diameter: CircleIcon.Avatar.xl
            )

            // Team name + owner name
            VStack(alignment: .leading, spacing: CircleSpace.xxs) {
                Text(member.teamName)
                    .font(.cTitleSection)
                    .foregroundStyle(Color.cTextPrimary)
                    .textCase(.uppercase)
                Text(member.isCurrentUser ? "You" : member.name)
                    .font(.cBody)
                    .foregroundStyle(Color.cTextSecondary)
            }

            // Record chip
            HStack(spacing: CircleSpace.xs) {
                Text("\(member.wins)W · \(member.losses)L")
                    .font(.cMeta)
                    .foregroundStyle(Color.cTextSecondary)
                    .padding(.horizontal, CircleSpace.base)
                    .padding(.vertical, CircleSpace.xxs)
                    .background(Color.cBgPanel)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(Color.cBorderChip, lineWidth: 1)
                    )
            }

            // Portfolio value with animated count-up
            HStack(alignment: .firstTextBaseline, spacing: CircleSpace.sm) {
                AnimatedNumber(
                    value: portfolioValue,
                    format: { v in String(format: "$%.0f", v) },
                    color: .cTextPrimary,
                    font: .cHeroMobile,
                    customFontTabular: true
                )
                DeltaPill(
                    value: weeklyReturn,
                    formatted: String(format: "%@%.1f%%", weeklyReturn >= 0 ? "+" : "", weeklyReturn * 100)
                )
            }
        }
        .padding(.horizontal, CircleSpace.lg)
        .padding(.top, CircleSpace.md)
        .padding(.bottom, CircleSpace.xl)
    }

    // MARK: - Roster Section

    private var rosterSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Roster", subtitle: "\(member.roster.count) picks")

            if member.roster.isEmpty {
                Text("No picks yet")
                    .font(.cBody)
                    .foregroundStyle(Color.cTextTertiary)
                    .padding(.horizontal, CircleSpace.lg)
                    .padding(.vertical, CircleSpace.lg)
            } else {
                ForEach(Array(member.roster.enumerated()), id: \.element.id) { idx, stock in
                    RosterRow(
                        symbol: stock.id,
                        companyName: stock.name,
                        metaText: stock.sector,
                        price: stock.currentPrice.formatted(.currency(code: "USD")),
                        deltaPercent: stock.weeklyReturn,
                        deltaPercentText: String(format: "%@%.1f%%", stock.weeklyReturn >= 0 ? "+" : "", stock.weeklyReturn * 100),
                        sparklineData: stock.sparkline,
                        tone: stock.weeklyReturn >= 0 ? .green : .red
                    )
                    .opacity(revealPhase >= 2 ? 1 : 0)
                    .offset(y: revealPhase >= 2 ? 0 : 8)
                    .animation(
                        .spring(response: 0.35, dampingFraction: 0.85)
                            .delay(Double(idx) * 0.06),
                        value: revealPhase
                    )

                    if idx < member.roster.count - 1 {
                        CircleDivider()
                            .padding(.leading, CircleSpace.lg + CircleIcon.Tile.md + CircleSpace.base)
                    }
                }
            }

            Spacer(minLength: CircleSpace.xl)
        }
    }

    // MARK: - Staggered Reveal

    private func startReveal() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation { revealPhase = 1 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation { revealPhase = 2 }
        }
    }
}

#Preview("Team Detail") {
    let member = LeagueMember(id: UUID(), name: "Opponent", teamName: "Dark Pool FC", roster: [], wins: 3, losses: 2, isCurrentUser: false)
    TeamDetailView(member: member)
        .environmentObject(AppState.preview)
        .preferredColorScheme(.dark)
}
