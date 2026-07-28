import SwiftUI

// MARK: - BuzzTrendingBlocks
//
// Three deliberately distinct trending mini-blocks separated by row dividers.
// Intentionally varied layouts — do not unify into one pattern.

struct BuzzTrendingBlocks: View {
    let trade: TrendingTrade
    let trader: TopTrader
    let hotStock: HotStock

    var body: some View {
        VStack(spacing: 0) {
            blockA
            CircleDivider(weight: .row)
            blockB
            CircleDivider(weight: .row)
            blockC
        }
    }

    // MARK: Block A — Biggest trade today

    private var blockA: some View {
        VStack(alignment: .leading, spacing: CircleSpace.base) {
            Text("BIGGEST TRADE TODAY")
                .font(.cEyebrowSmall)
                .tracking(CircleTracking.eyebrow)
                .foregroundStyle(Color.cTextSecondary)

            HStack(alignment: .top, spacing: CircleSpace.base) {
                CircleAvatar(
                    initials: trade.userInitials,
                    team: trade.userTeamColor,
                    diameter: 38
                )

                VStack(alignment: .leading, spacing: CircleSpace.xxs) {
                    // Line 1: username + time
                    HStack(spacing: 0) {
                        Text(trade.username)
                            .font(.cBodyEmphasis)
                            .foregroundStyle(Color.cTextPrimary)
                        Text(" · \(trade.timeAgo)")
                            .font(.cBody)
                            .foregroundStyle(Color.cTextSecondary)
                    }

                    // Line 2: ticker swap
                    HStack(spacing: CircleSpace.xxs) {
                        Text(trade.from)
                            .font(.cBodyDense)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.cTextOpponent)
                        Text("→")
                            .font(.cBodyDense)
                            .foregroundStyle(Color.cTextTertiary)
                        Text(trade.to)
                            .font(.cBodyDense)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.cTextPrimary)
                    }

                    // Line 3: animated gain + label
                    HStack(alignment: .firstTextBaseline, spacing: CircleSpace.xs) {
                        AnimatedNumber(
                            value: trade.percentSinceTrade,
                            format: { String(format: "+%.1f%%", $0) },
                            color: .cAccent,
                            font: .cTitleStat,
                            customFontTabular: true
                        )
                        .tracking(CircleTracking.title)

                        Text("since trade")
                            .font(.cMeta)
                            .foregroundStyle(Color.cTextSecondary)
                    }
                }
            }
        }
        .padding(.horizontal, CircleSpace.lg)
        .padding(.vertical, CircleSpace.mdPlus)
    }

    // MARK: Block B — Top trader this week

    private var blockB: some View {
        VStack(alignment: .leading, spacing: CircleSpace.base) {
            Text("TOP TRADER THIS WEEK")
                .font(.cEyebrowSmall)
                .tracking(CircleTracking.eyebrow)
                .foregroundStyle(Color.cTextSecondary)

            HStack(alignment: .center, spacing: CircleSpace.base) {
                CircleAvatar(
                    initials: trader.initials,
                    team: trader.teamColor,
                    diameter: 38,
                    crown: true
                )

                VStack(alignment: .leading, spacing: CircleSpace.xxs) {
                    Text(trader.username)
                        .font(.cBodyEmphasis)
                        .foregroundStyle(Color.cTextPrimary)
                    Text(trader.summary)
                        .font(.cMeta)
                        .foregroundStyle(Color.cTextSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 2) {
                    AnimatedNumber(
                        value: trader.weekPercent,
                        format: { String(format: "+%.1f%%", $0) },
                        color: .cAccent,
                        font: .cTitleSub,
                        customFontTabular: true
                    )
                    .tracking(CircleTracking.subtitle)

                    Text("this week")
                        .font(.cTiny)
                        .foregroundStyle(Color.cTextSecondary)
                }
            }
        }
        .padding(.horizontal, CircleSpace.lg)
        .padding(.vertical, CircleSpace.mdPlus)
    }

    // MARK: Block C — Hottest stock

    private var blockC: some View {
        VStack(alignment: .leading, spacing: CircleSpace.base) {
            Text("HOTTEST STOCK")
                .font(.cEyebrowSmall)
                .tracking(CircleTracking.eyebrow)
                .foregroundStyle(Color.cTextSecondary)

            HStack(alignment: .center, spacing: CircleSpace.base) {
                TickerTile(symbol: hotStock.symbol, tone: .green, size: .md)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: CircleSpace.xs) {
                        Text(hotStock.companyName)
                            .font(.cBodyEmphasis)
                            .foregroundStyle(Color.cTextPrimary)
                        TagChip("HOT", style: .hot, leadingIcon: "flame.fill")
                    }
                    Text("Drafted \(hotStock.timesDraftedThisWeek.formatted())× this week")
                        .font(.cMeta)
                        .foregroundStyle(Color.cTextSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Sparkline(
                    values: hotStock.sparklineValues,
                    size: CGSize(width: 64, height: 26)
                )

                VStack(alignment: .trailing, spacing: 2) {
                    Text("$\(Int(hotStock.price))")
                        .font(.cBodyEmphasis)
                        .foregroundStyle(Color.cTextPrimary)
                        .monospacedDigit()
                    Text(String(format: "+%.1f%%", hotStock.percent))
                        .font(.cMeta)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.cAccent)
                        .monospacedDigit()
                }
            }
        }
        .padding(.horizontal, CircleSpace.lg)
        .padding(.vertical, CircleSpace.mdPlus)
    }
}

#Preview("BuzzTrendingBlocks") {
    BuzzTrendingBlocks(
        trade: TrendingTrade(
            username: "kaiwave",
            userInitials: "KW",
            userTeamColor: .purple,
            from: "TSLA",
            to: "NVDA",
            percentSinceTrade: 4.7,
            timeAgo: "3h"
        ),
        trader: TopTrader(
            username: "stockwizard",
            initials: "SW",
            teamColor: .yellow,
            summary: "5 picks · 3 beat S&P",
            weekPercent: 12.3
        ),
        hotStock: HotStock(
            symbol: "NVDA",
            companyName: "Nvidia",
            timesDraftedThisWeek: 847,
            sparklineValues: [100, 108, 105, 112, 118, 122, 130],
            price: 875.0,
            percent: 6.2
        )
    )
    .background(Color.cBg)
    .preferredColorScheme(.dark)
}
