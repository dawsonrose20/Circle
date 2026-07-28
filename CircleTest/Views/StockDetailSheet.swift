import SwiftUI

// MARK: - Stock Detail Sheet
//
// Presented as a .sheet() from any view that has a tappable stock surface.
// Shows price, sparkline/chart, weekly stats, and a deep-link to Trading.

struct StockDetailSheet: View {
    let stock: Stock
    var onTrade: (() -> Void)? = nil   // called when user taps "Trade" button

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    private var isPos: Bool { stock.weeklyReturn >= 0 }
    private var lineColor: Color { isPos ? .cAccent : .cLoss }
    private var tone: TickerTile.Tone {
        if stock.tag == .star { return .gold }
        if stock.tag == .hot  { return .orange }
        return isPos ? .green : .red
    }
    private var ownedShares: Double { appState.holdings[stock.id, default: 0] }
    private var posValue: Double { ownedShares * stock.currentPrice }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // ── Identity row ────────────────────────────────────
                    HStack(spacing: CircleSpace.base) {
                        TickerTile(symbol: stock.id, tone: tone, size: .lg)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(stock.name)
                                .font(.cBodyEmphasis)
                                .foregroundStyle(Color.cTextPrimary)
                            Text(stock.sector)
                                .font(.cMeta)
                                .foregroundStyle(Color.cTextSecondary)
                        }
                        Spacer()
                        // Tag badge
                        if stock.tag != .none {
                            let isHot = stock.tag == .hot
                            Text(isHot ? "🔥 HOT" : "⭐ STAR")
                                .font(.cTiny)
                                .fontWeight(.semibold)
                                .foregroundStyle(isHot ? Color.cHot : Color.cGold)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(isHot ? Color.cHotTileBg : Color.cGoldTileBg)
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        }
                    }
                    .padding(.horizontal, CircleSpace.lg)
                    .padding(.top, CircleSpace.lg)
                    .padding(.bottom, CircleSpace.md)

                    // ── Hero price ──────────────────────────────────────
                    HeroNumber(
                        dollars: "$\(Int(stock.currentPrice))",
                        cents: String(format: ".%02d", Int((stock.currentPrice.truncatingRemainder(dividingBy: 1)) * 100)),
                        color: .cTextPrimary,
                        size: .cHeroMobile
                    )
                    .padding(.horizontal, CircleSpace.lg)

                    // ── Delta row ───────────────────────────────────────
                    HStack(spacing: CircleSpace.base) {
                        DeltaPill(
                            value: stock.weeklyGainLoss,
                            formatted: String(format: "%@$%.2f", isPos ? "+" : "−", abs(stock.weeklyGainLoss))
                        )
                        Text(String(format: "%@%.2f%%", isPos ? "+" : "", stock.weeklyReturn * 100))
                            .font(.cBodyEmphasis)
                            .foregroundStyle(lineColor)
                            .monospacedDigit()
                        Text("this week")
                            .font(.cBody)
                            .foregroundStyle(Color.cTextSecondary)
                    }
                    .padding(.horizontal, CircleSpace.lg)
                    .padding(.top, CircleSpace.xs)
                    .padding(.bottom, CircleSpace.md)

                    // ── Sparkline chart ─────────────────────────────────
                    if !stock.sparkline.isEmpty {
                        TradingChartCanvas(
                            points: stock.sparkline,
                            color: lineColor,
                            costBasis: stock.draftCostPrice ?? stock.weekStartPrice
                        )
                        .frame(height: 160)
                        .padding(.vertical, CircleSpace.md)
                    }

                    CircleDivider(weight: .section)

                    // ── Stats grid ──────────────────────────────────────
                    VStack(spacing: 0) {
                        statRow(label: "Current Price",
                                value: stock.currentPrice.formatted(.currency(code: "USD")))
                        CircleDivider()
                        statRow(label: "Week Open",
                                value: stock.weekStartPrice.formatted(.currency(code: "USD")))
                        CircleDivider()
                        statRow(label: "Weekly Change",
                                value: String(format: "%@$%.2f (%@%.1f%%)",
                                              isPos ? "+" : "−",
                                              abs(stock.weeklyGainLoss),
                                              isPos ? "+" : "",
                                              stock.weeklyReturn * 100),
                                valueColor: lineColor)
                        if let cost = stock.draftCostPrice {
                            CircleDivider()
                            statRow(label: "Draft Cost", value: cost.formatted(.currency(code: "USD")))
                        }
                        if ownedShares > 0 {
                            CircleDivider()
                            statRow(label: "You Own",
                                    value: String(format: "%.4g shares · $%.0f", ownedShares, posValue),
                                    valueColor: .cAccent)
                        }
                    }
                    .padding(.vertical, CircleSpace.sm)

                    CircleDivider(weight: .section)

                    // ── CTA ─────────────────────────────────────────────
                    PrimaryButton(title: "Trade \(stock.id)") {
                        dismiss()
                        onTrade?()
                    }
                    .padding(.horizontal, CircleSpace.lg)
                    .padding(.top, CircleSpace.lg)
                    .padding(.bottom, CircleSpace.xl)
                }
            }
            .background(Color.cBg.ignoresSafeArea())
            .navigationTitle(stock.id)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.cAccent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func statRow(label: String, value: String, valueColor: Color = .cTextPrimary) -> some View {
        HStack {
            Text(label)
                .font(.cBody)
                .foregroundStyle(Color.cTextSecondary)
            Spacer()
            Text(value)
                .font(.cBodyEmphasis)
                .foregroundStyle(valueColor)
                .monospacedDigit()
        }
        .padding(.horizontal, CircleSpace.lg)
        .padding(.vertical, CircleSpace.base)
    }
}
