import SwiftUI
import Combine

// MARK: - BuzzHeroContest
//
// "Today's play" — the featured contest card at the top of the Buzz tab.
// Styled as a floating card matching the Draft clock card pattern:
// RoundedRectangle(cornerRadius: panelHero) on cBgPanel, with horizontal margin.

struct BuzzHeroContest: View {
    let contest: Contest
    var onEnter: () -> Void = {}

    // Live countdown timer state
    @State private var secondsRemaining: Int = 0
    @State private var timerCancellable: AnyCancellable?

    private var closesColor: Color {
        secondsRemaining < 60 ? Color.cLoss : Color.cAccent
    }

    private var closesFormatted: String {
        let h = secondsRemaining / 3600
        let m = (secondsRemaining % 3600) / 60
        let s = secondsRemaining % 60
        if h > 0 {
            return "\(h)h \(m)m"
        } else if m > 0 {
            return "\(m)m \(s)s"
        } else {
            return "\(s)s"
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Card surface — green-tinted like the draft countdown card
            content
                .background(Color.cAccentTileBg)
                .clipShape(RoundedRectangle(cornerRadius: CircleRadius.panelHero, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: CircleRadius.panelHero, style: .continuous)
                        .strokeBorder(Color.cAccentBorder25, lineWidth: CircleStroke.hairline)
                )

            // Decorative concentric rings clipped to card
            concentricRings
                .clipShape(RoundedRectangle(cornerRadius: CircleRadius.panelHero, style: .continuous))
        }
        .padding(.horizontal, CircleSpace.lg)
        .padding(.vertical, CircleSpace.mdPlus)
        .onAppear { startTimer() }
        .onDisappear { timerCancellable?.cancel() }
    }

    // MARK: Concentric ring decoration

    private var concentricRings: some View {
        Canvas { ctx, size in
            let cx = size.width + 8
            let cy: CGFloat = 8
            for r in [CGFloat(40), 80, 120] {
                let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
                ctx.stroke(
                    Path(ellipseIn: rect),
                    with: .color(Color.cAccent.opacity(0.08)),
                    lineWidth: 1
                )
            }
        }
        .frame(width: 140, height: 140)
        .allowsHitTesting(false)
    }

    // MARK: Content

    private var content: some View {
        VStack(alignment: .leading, spacing: CircleSpace.md) {
            // Eyebrow with pulsing live dot
            EyebrowLabel("Today's play · live", style: .live)

            // Contest title
            Text(contest.title)
                .font(.cTitle)
                .foregroundStyle(Color.cTextPrimary)
                .textCase(.uppercase)

            // Description
            Text("PICK 3 stocks that'll beat the S&P today. Highest combined return wins.")
                .font(.cBody)
                .foregroundStyle(Color.cTextSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            // Divider
            Rectangle()
                .fill(Color.cDividerSection)
                .frame(height: CircleStroke.hairline)

            // Stats row
            HStack(spacing: 0) {
                statGroup(eyebrow: "Prize", value: "$\(contest.prizePool ?? 0)", color: .cGold)

                Spacer()

                statGroup(
                    eyebrow: "Players",
                    valueView: AnyView(
                        AnimatedNumber(
                            value: Double(contest.players),
                            format: { v in
                                let n = Int(v)
                                return n >= 1000
                                    ? String(format: "%.1fk", Double(n) / 1000)
                                    : "\(n)"
                            },
                            color: .cTextPrimary,
                            font: .cBodyEmphasis
                        )
                    )
                )

                Spacer()

                statGroup(
                    eyebrow: "Closes in",
                    valueView: AnyView(
                        Text(closesFormatted)
                            .font(.cBodyEmphasis)
                            .foregroundStyle(closesColor)
                            .monospacedDigit()
                    )
                )
            }

            // CTA button
            PrimaryButton(title: "Enter for $\(contest.entryFee ?? 0)", trailingArrow: true) {
                Haptics.confirm()
                onEnter()
            }
        }
        .padding(CircleSpace.lg)
    }

    // MARK: Stat group helpers

    private func statGroup(eyebrow: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: CircleSpace.xxs) {
            Text(eyebrow.uppercased())
                .font(.cTiny)
                .foregroundStyle(Color.cTextSecondary)
                .tracking(CircleTracking.eyebrowTight)
            Text(value)
                .font(.cBodyEmphasis)
                .foregroundStyle(color)
                .monospacedDigit()
        }
    }

    private func statGroup(eyebrow: String, valueView: AnyView) -> some View {
        VStack(alignment: .leading, spacing: CircleSpace.xxs) {
            Text(eyebrow.uppercased())
                .font(.cTiny)
                .foregroundStyle(Color.cTextSecondary)
                .tracking(CircleTracking.eyebrowTight)
            valueView
        }
    }

    // MARK: Timer

    private func startTimer() {
        if let closes = contest.closesAt {
            secondsRemaining = max(0, Int(closes.timeIntervalSinceNow))
        } else {
            secondsRemaining = 3 * 3600 + 14 * 60
        }
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                if secondsRemaining > 0 { secondsRemaining -= 1 }
            }
    }
}

#Preview("BuzzHeroContest") {
    ScrollView {
        BuzzHeroContest(contest: Contest(
            id: "preview",
            title: "Beat the S&P",
            kind: .elimination,
            prizePool: 500,
            entryFee: 5,
            players: 1247,
            closesAt: Date().addingTimeInterval(3 * 3600 + 14 * 60),
            opensAt: nil,
            isLive: true,
            isFeatured: true,
            isOpen: true
        ))
    }
    .background(Color.cBg)
    .preferredColorScheme(.dark)
}
