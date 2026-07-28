import SwiftUI

// MARK: - BuzzContestRow
//
// Single row in the "More contests" list. Tappable full-row with press state.

struct BuzzContestRow: View {
    let contest: Contest
    var onEnter: () -> Void = {}
    var onRemind: () -> Void = {}

    var body: some View {
        Button {
            Haptics.tap()
            if contest.isOpen { onEnter() }
            else { onRemind() }
        } label: {
            HStack(spacing: CircleSpace.base) {
                // Column 1: Kind icon tile (36×36)
                kindIcon

                // Column 2: Title + meta (flexible)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: CircleSpace.xs) {
                        Text(contest.title)
                            .font(.cBodyEmphasis)
                            .foregroundStyle(Color.cTextPrimary)
                            .lineLimit(1)
                        if contest.isLive {
                            TagChip("LIVE", style: .live, pulses: true)
                        }
                    }
                    Text(contest.metaString)
                        .font(.cMeta)
                        .foregroundStyle(Color.cTextSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Column 3: Action circle (36×36)
                actionCircle
            }
            .padding(.horizontal, CircleSpace.lg)
            .padding(.vertical, CircleSpace.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: Kind icon

    private var kindIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: CircleRadius.icon, style: .continuous)
                .fill(iconBg)
                .frame(width: 36, height: 36)
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(iconFg)
        }
    }

    private var iconBg: Color {
        switch contest.kind {
        case .elimination: return Color.cLossTileBg
        case .streak:      return Color(hex: 0x2A1A2E)
        case .bracket:     return Color.cGoldTileBg
        case .longShort:   return Color(hex: 0x1A2820)
        }
    }

    private var iconFg: Color {
        switch contest.kind {
        case .elimination: return Color.cLoss
        case .streak:      return Color.cTeamPurple
        case .bracket:     return Color.cGold
        case .longShort:   return Color.cTeamGreen
        }
    }

    private var iconName: String {
        switch contest.kind {
        case .elimination: return "bolt.fill"
        case .streak:      return "chevron.up.2"
        case .bracket:     return "square.grid.2x2.fill"
        case .longShort:   return "arrow.up.arrow.down"
        }
    }

    // MARK: Action circle

    private var actionCircle: some View {
        Group {
            if contest.isOpen {
                // Enter arrow — filled accent circle
                ZStack {
                    Circle()
                        .fill(Color.cAccent)
                        .frame(width: 36, height: 36)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.cBg)
                }
            } else {
                // Reminder star — outlined circle
                ZStack {
                    Circle()
                        .strokeBorder(Color.cAccentBorder40, lineWidth: CircleStroke.hairline)
                        .frame(width: 36, height: 36)
                    Image(systemName: "star")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.cAccent)
                }
            }
        }
    }
}

#Preview("BuzzContestRow") {
    VStack(spacing: 0) {
        BuzzContestRow(contest: Contest(
            id: "preview",
            title: "Beat the S&P",
            kind: .elimination,
            prizePool: 500,
            entryFee: 5,
            players: 1247,
            closesAt: Date().addingTimeInterval(3 * 3600),
            opensAt: nil,
            isLive: true,
            isFeatured: false,
            isOpen: true
        ))
    }
    .background(Color.cBg)
    .preferredColorScheme(.dark)
}
