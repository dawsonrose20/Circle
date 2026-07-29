import SwiftUI

// MARK: - TradingView (single-page)

struct TradingView: View {
    @EnvironmentObject var appState: AppState
    // Store ID only — always resolve to the live roster copy so refreshed candles are visible
    @State private var selectedStockID: String? = nil
    @State private var sheetStock: Stock? = nil       // for detail sheet (separate from selected)
    @State private var selectedRange: ChartRange = .week
    @State private var tradeAmount: String = ""
    @State private var tradeMode: TradingMode = .buy
    @State private var tradeMessage: String? = nil
    @FocusState private var amountFocused: Bool

    private var roster: [Stock] {
        (appState.currentUser?.roster ?? [])
            .sorted { ($0.draftPickNumber ?? 99) < ($1.draftPickNumber ?? 99) }
    }

    // Unique symbols for the scrolling ticker — prefer ones with live prices,
    // fall back to the full pool so the tape is never empty before data loads.
    private var tickerStocks: [Stock] {
        var seen = Set<String>()
        let combined = (roster + appState.availableStocks).filter { seen.insert($0.id).inserted }
        let priced = combined.filter { $0.hasPriceData }
        return priced.isEmpty ? combined : priced
    }

    // nil = portfolio overview. Stores the ID only, so the live roster copy is
    // always resolved and refreshed candles are visible immediately.
    private var stock: Stock? {
        guard let id = selectedStockID else { return nil }
        return roster.first(where: { $0.id == id })
    }

    private var isPortfolioMode: Bool { selectedStockID == nil }

    private var isPos: Bool { (stock?.weeklyReturn ?? 0) >= 0 }
    private var lineColor: Color { isPos ? Color.cAccent : Color.cLoss }
    private var costBasis: Double {
        Double(stock?.draftCostPrice ?? stock?.weekStartPrice ?? 100)
    }
    private var owned: Double { appState.holdings[stock?.id ?? "", default: 0] }
    private var positionValue: Double { owned * (stock?.currentPrice ?? 0) }
    private var pnl: Double { positionValue - owned * costBasis }
    private var pnlPct: Double {
        guard owned > 0 else { return stock?.weeklyReturn ?? 0 }
        return ((stock?.currentPrice ?? 0) - costBasis) / costBasis
    }

    // MARK: - Portfolio-level figures

    private var portfolioSeries: [Double] { appState.portfolioSeries(range: selectedRange) }
    private var portfolioTotal: Double { appState.portfolioValue }
    private var portfolioGainLoss: Double { portfolioTotal - LeagueConfig.startingCapital }
    private var portfolioReturn: Double { appState.currentUser?.totalWeeklyReturn ?? 0 }
    private var investedValue: Double { appState.currentUser?.investedValue ?? 0 }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                navBar
                TickerTape(items: tickerStocks)
                if let s = stock {
                    stockBreadcrumb(s)
                    priceSection(s)
                    chartCard { chartSection(s) }
                    rangeSelector
                    CircleDivider(weight: .section)
                    positionStats(s)
                    CircleDivider(weight: .section)
                    tradePanel(s)
                } else {
                    portfolioSection
                    chartCard { portfolioChart }
                    rangeSelector
                    CircleDivider(weight: .section)
                    portfolioStats
                }
                CircleDivider(weight: .section)
                rosterHeader
                rosterList
                Spacer(minLength: 40)
            }
        }
        .background(Color.cBg.ignoresSafeArea())
        .ignoresSafeArea(edges: .top)
        // Dismiss keyboard on scroll (doesn't conflict with button taps)
        .scrollDismissesKeyboard(.interactively)
        .sheet(item: $sheetStock) { s in
            StockDetailSheet(stock: s, onTrade: {
                selectedStockID = s.id
                tradeAmount = ""
                tradeMessage = nil
                tradeMode = .buy
            })
            .environmentObject(appState)
        }
        .onAppear {
            Task { await appState.refreshPrices() }
        }
        // Load bars for the current selection + range, then keep them fresh.
        // Re-runs whenever either the stock or the range changes.
        .task(id: "\(stock?.id ?? "portfolio")|\(selectedRange.rawValue)") {
            let symbol = stock?.id
            await loadChartData(symbol: symbol)
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                await loadChartData(symbol: symbol)
            }
        }
    }

    // MARK: - Nav Bar

    private var navBar: some View {
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

    /// Loads bars for whichever chart is on screen: one symbol in stock mode,
    /// every held symbol in portfolio mode.
    private func loadChartData(symbol: String?) async {
        if let symbol {
            await appState.refreshCandles(for: symbol, range: selectedRange)
        } else {
            await appState.refreshPortfolioCandles(range: selectedRange)
        }
    }

    // MARK: - Chart Card
    //
    // Shared container that gives both the portfolio and per-stock charts the
    // same treatment as the draft clock card: tinted panel, 20pt radius,
    // accent hairline border.

    private func chartCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.vertical, CircleSpace.md)
            .frame(maxWidth: .infinity)
            .background(Color.cAccentTileBg)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.cAccentBorder25, lineWidth: 1)
            )
            .padding(.horizontal, CircleSpace.lg)
            .padding(.top, CircleSpace.sm)
    }

    // MARK: - Portfolio Overview (default view)

    private var portfolioSection: some View {
        let isPos = portfolioGainLoss >= 0
        return VStack(alignment: .leading, spacing: CircleSpace.base) {
            HeroNumber(
                dollars: "$\(Int(portfolioTotal).formatted())",
                cents: String(format: ".%02d", Int((portfolioTotal.truncatingRemainder(dividingBy: 1)) * 100)),
                eyebrow: "TOTAL PORTFOLIO",
                color: .cTextPrimary,
                size: .cHeroMobile
            )
            HStack(spacing: CircleSpace.base) {
                DeltaPill(
                    value: portfolioGainLoss,
                    formatted: String(format: "%@$%.2f", isPos ? "+" : "−", abs(portfolioGainLoss))
                )
                Text(String(format: "%@%.1f%%", portfolioReturn >= 0 ? "+" : "", portfolioReturn * 100))
                    .font(.cBodyEmphasis)
                    .foregroundStyle(isPos ? Color.cAccent : Color.cLoss)
                    .monospacedDigit()
                Text("all time")
                    .font(.cBody)
                    .foregroundStyle(Color.cTextSecondary)
            }
            .padding(.horizontal, CircleSpace.lg)
        }
        .padding(.leading, CircleSpace.lg)
        .padding(.bottom, CircleSpace.xs)
    }

    @ViewBuilder
    private var portfolioChart: some View {
        let series = portfolioSeries
        if series.count > 1 {
            HomeChartCanvas(userPoints: series, oppPoints: [], showOpponent: false)
                .frame(height: 180)
                .padding(.horizontal, CircleSpace.md)
        } else {
            VStack(spacing: CircleSpace.sm) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(Color.cAccent.opacity(0.5))
                Text("No positions yet")
                    .font(.cBodyEmphasis)
                    .foregroundStyle(Color.cTextPrimary)
                Text("Buy a stock from your roster to start\ntracking your portfolio.")
                    .font(.cMeta)
                    .foregroundStyle(Color.cTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(height: 180)
            .frame(maxWidth: .infinity)
        }
    }

    private var portfolioStats: some View {
        HStack(spacing: 0) {
            statCell(label: "Cash", value: String(format: "$%.0f", appState.cash), color: .cTextPrimary)
            Rectangle().fill(Color.cDividerSection).frame(width: CircleStroke.hairline, height: 32)
            statCell(label: "Invested", value: String(format: "$%.0f", investedValue), color: .cTextSecondary)
            Rectangle().fill(Color.cDividerSection).frame(width: CircleStroke.hairline, height: 32)
            statCell(
                label: "Total P&L",
                value: String(format: "%@$%.0f", portfolioGainLoss >= 0 ? "+" : "−", abs(portfolioGainLoss)),
                color: portfolioGainLoss >= 0 ? .cAccent : .cLoss,
                sub: String(format: "%.1f%%", portfolioReturn * 100)
            )
        }
        .padding(.vertical, CircleSpace.md)
    }

    // MARK: - Breadcrumb (stock mode → back to portfolio)

    private func stockBreadcrumb(_ s: Stock) -> some View {
        Button {
            Haptics.select()
            amountFocused = false
            selectedStockID = nil
            tradeAmount = ""
            tradeMessage = nil
        } label: {
            HStack(spacing: CircleSpace.xs) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .bold))
                Text("Portfolio")
                    .font(.cMeta)
                    .fontWeight(.semibold)
                Text("· \(s.id)")
                    .font(.cMeta)
                    .foregroundStyle(Color.cTextSecondary)
                Spacer()
            }
            .foregroundStyle(Color.cAccent)
            .padding(.horizontal, CircleSpace.lg)
            .padding(.bottom, CircleSpace.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Price Section

    private func priceSection(_ s: Stock) -> some View {
        let gain = s.currentPrice - s.weekStartPrice
        let isGainPos = gain >= 0
        let tone: TickerTile.Tone = isPos ? .green : .red

        return VStack(alignment: .leading, spacing: CircleSpace.base) {
            // Ticker identity row — tappable to see full detail sheet
            Button {
                Haptics.select()
                sheetStock = s
            } label: {
                HStack(spacing: CircleSpace.base) {
                    TickerTile(symbol: s.id, tone: tone, size: .lg)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.name)
                            .font(.cBodyEmphasis)
                            .foregroundStyle(Color.cTextPrimary)
                            .lineLimit(1)
                        Text(s.sector)
                            .font(.cMeta)
                            .foregroundStyle(Color.cTextSecondary)
                    }
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, CircleSpace.lg)

            // Big price
            HeroNumber(
                dollars: "$\(Int(s.currentPrice))",
                cents: String(format: ".%02d", Int((s.currentPrice.truncatingRemainder(dividingBy: 1)) * 100)),
                color: .cTextPrimary,
                size: .cHeroMobile
            )
            .padding(.leading, CircleSpace.lg)

            // Delta row
            HStack(spacing: CircleSpace.base) {
                DeltaPill(
                    value: gain,
                    formatted: String(format: "%@$%.2f", isGainPos ? "+" : "−", abs(gain))
                )
                Text(String(format: "%@%.1f%%", isPos ? "+" : "", s.weeklyReturn * 100))
                    .font(.cBodyEmphasis)
                    .foregroundStyle(lineColor)
                    .monospacedDigit()
                Text("this week")
                    .font(.cBody)
                    .foregroundStyle(Color.cTextSecondary)
            }
            .padding(.horizontal, CircleSpace.lg)
        }
        .padding(.bottom, CircleSpace.xs)
    }

    // MARK: - Chart

    private func chartSection(_ s: Stock) -> some View {
        // Priority: selected range → intraday 1-min bars → daily bars →
        // synthetic sparkline (only if varied)
        let chartCandles: [OHLCBar] = {
            let ranged = appState.candles(for: s.id, range: selectedRange)
            if ranged.count > 1 { return ranged }
            if s.intradayCandles.count > 1 { return s.intradayCandles }
            if s.candles.count > 1 { return s.candles }
            // Skip synthetic fallback if sparkline is flat (draft-pool placeholder data)
            guard s.sparkline.count > 1,
                  let mn = s.sparkline.min(), let mx = s.sparkline.max(),
                  mx - mn > mn * 0.001 else { return [] }
            return s.sparkline.indices.map { i in
                let close = s.sparkline[i]
                let open  = i > 0 ? s.sparkline[i - 1] : close
                let swing = abs(close - open)
                let wick  = max(swing * 0.35, close * 0.002)
                return OHLCBar(open: open, high: max(open, close) + wick,
                               low: min(open, close) - wick, close: close)
            }
        }()

        // Sits inside `chartCard`, so the canvases use tighter inset padding
        // than they would standalone.
        return ZStack(alignment: .topLeading) {
            if chartCandles.count > 1 {
                CandlestickChartCanvas(candles: chartCandles, costBasis: costBasis,
                                       horizontalPadding: CircleSpace.md)
                    .frame(height: 180)
            } else {
                let pts: [Double] = [s.weekStartPrice, s.currentPrice]
                TradingChartCanvas(points: pts, color: lineColor, costBasis: costBasis,
                                   horizontalPadding: CircleSpace.md)
                    .frame(height: 180)
            }

            Text("Cost $\(Int(costBasis))")
                .font(.cTiny)
                .foregroundStyle(Color.cGold.opacity(0.75))
                .padding(.horizontal, CircleSpace.lgMinus)
        }
    }

    // MARK: - Range Selector (flat segmented row)

    private var rangeSelector: some View {
        HStack(spacing: 0) {
            ForEach(ChartRange.allCases, id: \.self) { r in
                Button {
                    Haptics.select()
                    selectedRange = r
                } label: {
                    Text(r.rawValue)
                        .font(.system(size: 13, weight: selectedRange == r ? .semibold : .regular))
                        .foregroundStyle(selectedRange == r ? Color.cTextPrimary : Color.cTextSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, CircleSpace.base)
                        .background(
                            selectedRange == r
                                ? Color.cBgPanel
                                : Color.clear
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, CircleSpace.lg)
        .padding(.vertical, CircleSpace.xs)
    }

    // MARK: - Position Stats (flat 3-column row)

    private func positionStats(_ s: Stock) -> some View {
        let pnlDisplay = owned > 0 ? pnl : (s.currentPrice - costBasis)
        let pctDisplay = owned > 0 ? pnlPct : s.weeklyReturn

        return HStack(spacing: 0) {
            statCell(
                label: "Value",
                value: owned > 0 ? String(format: "$%.0f", positionValue) : String(format: "$%.2f", s.currentPrice),
                color: .cTextPrimary
            )
            Rectangle().fill(Color.cDividerSection).frame(width: CircleStroke.hairline, height: 32)
            statCell(
                label: "Cost basis",
                value: String(format: "$%.0f", costBasis),
                color: .cTextSecondary
            )
            Rectangle().fill(Color.cDividerSection).frame(width: CircleStroke.hairline, height: 32)
            statCell(
                label: "P&L",
                value: String(format: "%@$%.0f", pnlDisplay >= 0 ? "+" : "", pnlDisplay),
                color: pnlDisplay >= 0 ? .cAccent : .cLoss,
                sub: String(format: "%.1f%%", pctDisplay * 100)
            )
        }
        .padding(.vertical, CircleSpace.md)
    }

    private func statCell(label: String, value: String, color: Color, sub: String? = nil) -> some View {
        VStack(alignment: .center, spacing: 3) {
            Text(label)
                .font(.cMeta)
                .foregroundStyle(Color.cTextSecondary)
            Text(value)
                .font(.cBodyEmphasis)
                .foregroundStyle(color)
                .monospacedDigit()
                .minimumScaleFactor(0.75)
                .lineLimit(1)
            if let sub {
                Text(sub)
                    .font(.cMeta)
                    .foregroundStyle(color.opacity(0.7))
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Trade Panel (inline)

    private func tradePanel(_ s: Stock) -> some View {
        return VStack(spacing: CircleSpace.md) {
            // Buy / Sell toggle
            HStack(spacing: 0) {
                ForEach(TradingMode.allCases, id: \.self) { mode in
                    Button {
                        Haptics.select()
                        tradeMode = mode
                        tradeMessage = nil
                    } label: {
                        Text(mode.label)
                            .font(.cBodyEmphasis)
                            .foregroundStyle(tradeMode == mode ? mode.color : Color.cTextSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, CircleSpace.base)
                            .background(tradeMode == mode ? mode.color.opacity(0.18) : Color.clear)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color.cBgPanel)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(Color.cBorderChip, lineWidth: 1)
            )

            // Dollar amount input (flat, no border)
            HStack(spacing: CircleSpace.xs) {
                Text("$")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.cTextSecondary)
                TextField("0.00", text: $tradeAmount)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color.cTextPrimary)
                    .tint(Color.cAccent)
                    .focused($amountFocused)
            }
            .padding(.vertical, CircleSpace.sm)

            // Owned info — show dollar value only
            if owned > 0 {
                HStack(spacing: CircleSpace.xs) {
                    Text("You own")
                        .font(.cBody)
                        .foregroundStyle(Color.cTextSecondary)
                    Text(String(format: "$%.0f", positionValue))
                        .font(.cBodyEmphasis)
                        .foregroundStyle(Color.cAccent)
                        .monospacedDigit()
                    Spacer()
                }
                .font(.cBody)
            }

            // Cash available
            HStack(spacing: CircleSpace.xs) {
                Text("Cash available")
                    .font(.cBody)
                    .foregroundStyle(Color.cTextSecondary)
                Spacer()
                Text(String(format: "$%.2f", appState.cash))
                    .font(.cBodyEmphasis)
                    .foregroundStyle(Color.cTextPrimary)
                    .monospacedDigit()
            }

            // Feedback message
            if let msg = tradeMessage {
                Text(msg)
                    .font(.cBodyEmphasis)
                    .foregroundStyle(msg.hasPrefix("✓") ? Color.cAccent : Color.cLoss)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            }

            // Execute button
            if tradeMode == .sell {
                DestructiveButton(
                    title: "Sell \(s.id)",
                    trailing: owned > 0 ? String(format: "$%.0f", positionValue) : nil
                ) {
                    executeTrade(s)
                }
            } else {
                PrimaryButton(title: "Buy \(s.id)") {
                    executeTrade(s)
                }
            }
        }
        .padding(.horizontal, CircleSpace.lg)
        .padding(.vertical, CircleSpace.lgMinus)
        .animation(.easeOut(duration: 0.15), value: tradeAmount)
    }

    private func executeTrade(_ s: Stock) {
        amountFocused = false
        let dollars = Double(tradeAmount) ?? 0
        let error: String?
        if tradeMode == .buy {
            error = appState.buy(stock: s, dollars: dollars)
        } else {
            error = appState.sell(stock: s, dollars: dollars)
        }
        withAnimation {
            if let error {
                Haptics.error()
                tradeMessage = error
            } else {
                Haptics.success()
                tradeMessage = "✓ \(tradeMode == .buy ? "Bought" : "Sold") \(String(format: "$%.0f", dollars)) of \(s.id)"
                tradeAmount = ""
            }
        }
    }

    // MARK: - Roster Header

    private var rosterHeader: some View {
        SectionHeader(
            title: "Your Roster",
            subtitle: isPortfolioMode
                ? "Tap a stock to chart and trade it"
                : "Tap the active stock to return to portfolio"
        )
    }

    // MARK: - Roster List

    private var rosterList: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(roster.enumerated()), id: \.element.id) { idx, s in
                let isActive = stock?.id == s.id
                Button {
                    Haptics.select()
                    amountFocused = false
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        // Tapping the active stock again returns to the portfolio view.
                        selectedStockID = isActive ? nil : s.id
                        tradeAmount = ""
                        tradeMessage = nil
                        tradeMode = .buy
                    }
                } label: {
                    RosterRow(
                        symbol: s.id,
                        companyName: s.name,
                        metaText: s.draftPickNumber.map { "Pick \($0) · cost $\(Int(s.draftCostPrice ?? 0))" } ?? s.sector,
                        price: s.currentPrice.formatted(.currency(code: "USD")),
                        deltaPercent: s.weeklyReturn,
                        deltaPercentText: String(format: "%@%.1f%%", s.weeklyReturn >= 0 ? "+" : "", s.weeklyReturn * 100),
                        sparklineData: s.sparkline,
                        tags: isActive ? [TagChip("ACTIVE", style: .yours)] : [],
                        selected: isActive,
                        tone: s.weeklyReturn >= 0 ? .green : .red
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if idx < roster.count - 1 {
                    CircleDivider().padding(.leading, CircleSpace.lg + CircleIcon.Tile.md + CircleSpace.base)
                }
            }
        }
    }
}

// MARK: - Ticker Tape

/// Seamless, always-scrolling stock ticker.
///
/// Design decisions that keep it smooth:
///  • Two identical copies of the content are laid out end to end, so when the
///    first scrolls fully off-screen the second is already in its place — the
///    wrap is invisible (no snap-back).
///  • The offset is derived from absolute elapsed time via `TimelineView(.animation)`,
///    not an implicit repeating animation. Price refreshes (every 60s) therefore
///    can't cancel/restart the scroll — a common source of stutter.
///  • Width is captured through a `PreferenceKey` (updates only when it changes),
///    avoiding GeometryReader layout feedback loops.
///  • The moving row is `.fixedSize(horizontal: true, vertical: false)` so it
///    overflows instead of being compressed/truncated — but it lives in an
///    `.overlay` over a flexible-width `Color.clear`, not in a `ZStack`. A ZStack
///    sizes itself to its largest child, which let the row's multi-thousand-point
///    ideal width propagate up and push the app's tab bar off-screen. Overlay
///    content cannot grow its parent, so the tape stays a 34pt strip.
struct TickerTape: View {
    let items: [Stock]
    var speed: Double = 40   // points per second

    @State private var unitWidth: CGFloat = 0

    var body: some View {
        if items.isEmpty {
            EmptyView()
        } else {
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let offsetX: CGFloat = unitWidth > 0
                    ? -CGFloat((t * speed).truncatingRemainder(dividingBy: Double(unitWidth)))
                    : 0

                // Color.clear adopts the width the container proposes, and the
                // marquee rides in an overlay so its far larger ideal width can't
                // grow the parent. A ZStack can't do this: it sizes to its largest
                // child, so the row's width leaked upward and blew out the layout.
                Color.clear
                    .frame(height: 34)
                    .overlay(alignment: .leading) {
                        HStack(spacing: 0) {
                            row
                                .background(
                                    GeometryReader { geo in
                                        Color.clear.preference(key: TickerWidthKey.self, value: geo.size.width)
                                    }
                                )
                            row   // duplicate for the seamless loop
                        }
                        .fixedSize(horizontal: true, vertical: false)
                        .offset(x: offsetX)
                    }
                    .clipped()
            }
            .frame(height: 34)
            .onPreferenceChange(TickerWidthKey.self) { unitWidth = $0 }
            .background(Color.cBg)
            .overlay(alignment: .top)    { CircleDivider(weight: .section) }
            .overlay(alignment: .bottom) { CircleDivider(weight: .section) }
        }
    }

    private var row: some View {
        HStack(spacing: 0) {
            ForEach(items) { cell($0) }
        }
    }

    private func cell(_ s: Stock) -> some View {
        let up = s.weeklyReturn >= 0
        return HStack(spacing: 6) {
            Text(s.id)
                .font(.cBodyEmphasis)
                .foregroundStyle(Color.cTextPrimary)
            Text(s.currentPrice, format: .currency(code: "USD"))
                .font(.cMeta)
                .foregroundStyle(Color.cTextSecondary)
                .monospacedDigit()
            HStack(spacing: 2) {
                Image(systemName: up ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                    .font(.system(size: 7))
                Text(String(format: "%.2f%%", abs(s.weeklyReturn * 100)))
                    .font(.cMeta)
                    .monospacedDigit()
            }
            .foregroundStyle(s.hasPriceData ? (up ? Color.cAccent : Color.cLoss) : Color.cTextTertiary)
        }
        .padding(.horizontal, CircleSpace.md)
        .overlay(alignment: .trailing) {
            Rectangle().fill(Color.cDividerRow).frame(width: CircleStroke.hairline, height: 14)
        }
    }
}

private struct TickerWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        // First copy's width wins; ignore the (equal) second copy.
        if value == 0 { value = nextValue() }
    }
}

// MARK: - Trade Mode

enum TradingMode: CaseIterable {
    case buy, sell
    var label: String { self == .buy ? "Buy" : "Sell" }
    var color: Color { self == .buy ? Color.cAccent : Color.cLoss }
}

// MARK: - Candlestick Chart Canvas

struct CandlestickChartCanvas: View {
    let candles: [OHLCBar]
    let costBasis: Double
    var horizontalPadding: CGFloat = CircleSpace.lg

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let allPrices = candles.flatMap { [$0.high, $0.low] } + [costBasis]
            let rawMin = allPrices.min() ?? 0
            let rawMax = allPrices.max() ?? 1
            let pad = (rawMax - rawMin) * 0.08
            let minV = rawMin - pad
            let maxV = rawMax + pad
            let range = max(maxV - minV, 0.001)
            let n = candles.count

            Canvas { ctx, size in
                func py(_ price: Double) -> CGFloat {
                    h - CGFloat((price - minV) / range) * h * 0.88 - h * 0.06
                }

                let slotW  = w / CGFloat(n)
                let bodyW  = max(slotW * 0.55, 4)

                for (i, c) in candles.enumerated() {
                    let cx = slotW * CGFloat(i) + slotW / 2
                    let isGreen = c.close >= c.open
                    let color: Color = isGreen ? .cAccent : .cLoss

                    // Wick
                    var wick = Path()
                    wick.move(to: CGPoint(x: cx, y: py(c.high)))
                    wick.addLine(to: CGPoint(x: cx, y: py(c.low)))
                    ctx.stroke(wick, with: .color(color.opacity(0.8)),
                               style: StrokeStyle(lineWidth: 1.5, lineCap: .round))

                    // Body
                    let bodyTop = py(max(c.open, c.close))
                    let bodyBot = py(min(c.open, c.close))
                    let bodyH   = max(bodyBot - bodyTop, 2)
                    let rect = CGRect(x: cx - bodyW / 2, y: bodyTop, width: bodyW, height: bodyH)
                    ctx.fill(Path(roundedRect: rect, cornerSize: CGSize(width: 2, height: 2)),
                             with: .color(color))
                }

                // Cost basis dashed line
                let cbY = py(costBasis)
                var dash = Path()
                dash.move(to: CGPoint(x: 0, y: cbY))
                dash.addLine(to: CGPoint(x: w, y: cbY))
                ctx.stroke(dash, with: .color(Color.cGold.opacity(0.6)),
                           style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
            }

            // Y-axis labels: high / current / low
            let highY = h - CGFloat((rawMax - minV) / range) * h * 0.88 - h * 0.06
            let lowY  = h - CGFloat((rawMin - minV) / range) * h * 0.88 - h * 0.06

            let priceRange = rawMax - rawMin
            let fmt: (Double) -> String = priceRange < 5
                ? { String(format: "$%.2f", $0) }
                : { "$\(Int($0))" }
            Text(fmt(rawMax))
                .font(.cTiny).foregroundStyle(Color.cTextTertiary)
                .position(x: w - 24, y: max(highY + 8, 10))
            Text(fmt(rawMin))
                .font(.cTiny).foregroundStyle(Color.cTextTertiary)
                .position(x: w - 24, y: min(lowY - 8, h - 10))
        }
        .padding(.horizontal, horizontalPadding)
    }
}

// MARK: - Fallback Line Chart Canvas (used when candle data not yet loaded)

struct TradingChartCanvas: View {
    let points: [Double]
    let color: Color
    let costBasis: Double
    var horizontalPadding: CGFloat = CircleSpace.lg

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let minV = min((points.min() ?? 0), costBasis) * 0.98
            let maxV = max((points.max() ?? 1), costBasis) * 1.02
            let range = max(maxV - minV, 0.001)

            Canvas { ctx, size in
                func cx(_ i: Int) -> CGFloat { CGFloat(i) / CGFloat(points.count - 1) * w }
                func cy(_ v: Double) -> CGFloat { h - CGFloat((v - minV) / range) * h * 0.85 - h * 0.05 }

                var fill = Path()
                fill.move(to: CGPoint(x: cx(0), y: h))
                for i in 0..<points.count { fill.addLine(to: CGPoint(x: cx(i), y: cy(points[i]))) }
                fill.addLine(to: CGPoint(x: cx(points.count - 1), y: h))
                fill.closeSubpath()
                ctx.fill(fill, with: .linearGradient(
                    Gradient(colors: [color.opacity(0.35), color.opacity(0)]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: h)
                ))

                var line = Path()
                line.move(to: CGPoint(x: cx(0), y: cy(points[0])))
                for i in 1..<points.count { line.addLine(to: CGPoint(x: cx(i), y: cy(points[i]))) }
                ctx.stroke(line, with: .color(color),
                           style: StrokeStyle(lineWidth: CircleStroke.chartHero, lineCap: .round, lineJoin: .round))

                let cbY = cy(costBasis)
                var dash = Path()
                dash.move(to: CGPoint(x: 0, y: cbY))
                dash.addLine(to: CGPoint(x: w, y: cbY))
                ctx.stroke(dash, with: .color(Color.cGold.opacity(0.55)),
                           style: StrokeStyle(lineWidth: CircleStroke.spark, dash: [6, 4]))
            }
        }
        .padding(.horizontal, horizontalPadding)
    }
}

#Preview {
    TradingView()
        .environmentObject(AppState.preview)
        .preferredColorScheme(.dark)
}
