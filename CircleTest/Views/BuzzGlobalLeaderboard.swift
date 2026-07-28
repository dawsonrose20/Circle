import SwiftUI

// MARK: - BuzzGlobalLeaderboard
//
// Top 3 rankers + ellipsis gap + self row + "See full leaderboard" link.

struct BuzzGlobalLeaderboard: View {
    let rankers: [GlobalRanker]
    var onSeeAll: () -> Void = {}

    // Stagger for row count-up animations
    @State private var visibleRows: Int = 0

    private var topThree: [GlobalRanker] { rankers.filter { !$0.isSelf } }
    private var selfRow: GlobalRanker? { rankers.first { $0.isSelf } }

    var body: some View {
        VStack(spacing: 0) {
            // Top 3 rows
            ForEach(Array(topThree.enumerated()), id: \.element.id) { idx, ranker in
                leaderRow(ranker, visible: visibleRows > idx)
                CircleDivider(weight: .row)
            }

            // Ellipsis truncation indicator
            truncationDots

            CircleDivider(weight: .row)

            // Self row
            if let self_ = selfRow {
                selfLeaderRow(self_, visible: visibleRows > topThree.count)
            }

            // Divider + see all link
            CircleDivider(weight: .row)
            seeAllLink
        }
        .onAppear {
            // Stagger row reveal after external phase delay
            for i in 0...(topThree.count + 1) {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.05) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        visibleRows = i + 1
                    }
                }
            }
        }
    }

    // MARK: Standard leaderboard row

    private func leaderRow(_ ranker: GlobalRanker, visible: Bool) -> some View {
        Button {
            Haptics.tap()
        } label: {
            HStack(spacing: CircleSpace.base) {
                // Rank number (22pt column)
                Text("\(ranker.rank)")
                    .font(rankFont(ranker.rank))
                    .foregroundStyle(rankColor(ranker.rank))
                    .monospacedDigit()
                    .frame(width: 22, alignment: .center)

                // Avatar
                CircleAvatar(
                    initials: ranker.initials,
                    team: avatarTeamColor(ranker.rank, base: ranker.teamColor),
                    diameter: 32,
                    crown: ranker.rank == 1
                )

                // Name + title
                VStack(alignment: .leading, spacing: 2) {
                    Text(ranker.username)
                        .font(.cBodyEmphasis)
                        .foregroundStyle(Color.cTextPrimary)
                        .lineLimit(1)
                    Text(ranker.title)
                        .font(.cMeta)
                        .foregroundStyle(Color.cTextSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Portfolio value
                Text("$\(ranker.portfolioValue.formatted())")
                    .font(.cBodyEmphasis)
                    .foregroundStyle(Color.cTextPrimary)
                    .monospacedDigit()
            }
            .padding(.horizontal, CircleSpace.lg)
            .padding(.vertical, CircleSpace.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(visible ? 1 : 0)
        .offset(y: visible ? 0 : 8)
    }

    // MARK: Self row (highlighted)

    private func selfLeaderRow(_ ranker: GlobalRanker, visible: Bool) -> some View {
        Button {
            Haptics.tap()
        } label: {
            HStack(spacing: CircleSpace.base) {
                // Rank — accent colored
                Text("\(ranker.rank)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.cAccent)
                    .monospacedDigit()
                    .frame(width: 22, alignment: .center)

                // Avatar
                CircleAvatar(
                    initials: ranker.initials,
                    team: .selfBrand,
                    diameter: 32
                )

                // "You" + subtitle
                VStack(alignment: .leading, spacing: 2) {
                    Text("You")
                        .font(.cBodyEmphasis)
                        .foregroundStyle(Color.cAccent)
                    Text(ranker.title)
                        .font(.cMeta)
                        .foregroundStyle(Color.cTextSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Animated portfolio value
                AnimatedNumber(
                    value: Double(ranker.portfolioValue),
                    format: { "$\(Int($0).formatted())" },
                    color: .cTextPrimary,
                    font: .cBodyEmphasis
                )
                .monospacedDigit()
            }
            .padding(.horizontal, CircleSpace.lg)
            .padding(.vertical, CircleSpace.md)
            .background(Color.cBgYours)
            .overlay(alignment: .top) {
                Rectangle().fill(Color.cAccentBorder25).frame(height: CircleStroke.hairline)
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.cAccentBorder25).frame(height: CircleStroke.hairline)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(visible ? 1 : 0)
        .offset(y: visible ? 0 : 8)
    }

    // MARK: Truncation dots

    private var truncationDots: some View {
        HStack(spacing: CircleSpace.xs) {
            ForEach(0..<3, id: \.self) { _ in
                Circle()
                    .fill(Color.cTextTertiary)
                    .frame(width: 4, height: 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CircleSpace.smPlus)
    }

    // MARK: See all link

    private var seeAllLink: some View {
        Button {
            Haptics.tap()
            onSeeAll()
        } label: {
            Text("See full leaderboard →")
                .font(.cMeta)
                .fontWeight(.medium)
                .foregroundStyle(Color.cAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, CircleSpace.mdPlus)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Rank styling helpers

    private func rankFont(_ rank: Int) -> Font {
        switch rank {
        case 1:        return .cBodyEmphasis
        default:       return .system(size: 15)
        }
    }

    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1:  return Color.cGold
        case 2:  return Color.cTextOpponent
        case 3:  return Color.cTeamOrange
        default: return Color.cTextSecondary
        }
    }

    private func avatarTeamColor(_ rank: Int, base: CircleAvatar.TeamColor) -> CircleAvatar.TeamColor {
        // Override to match rank theme; fall back to base for others
        switch rank {
        case 1:  return .yellow   // gold-ish
        case 2:  return .purple
        case 3:  return .orange
        default: return base
        }
    }
}

#Preview("BuzzGlobalLeaderboard") {
    ScrollView {
        BuzzGlobalLeaderboard(rankers: [])
    }
    .background(Color.cBg)
    .preferredColorScheme(.dark)
}
