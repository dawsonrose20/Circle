import Combine
import Supabase
import SwiftUI

/// Central observable state shared across all tabs.
@MainActor
class AppState: ObservableObject {
    @Published var league: League
    @Published var availableStocks: [Stock] = []
    @Published var draftPicks: [String] = []
    @Published var draftActive: Bool = false
    @Published var hasLeague: Bool = false

    /// Cached OHLC series keyed by "SYMBOL:RANGE" so switching ranges is instant
    /// after the first fetch.
    @Published var rangeCandles: [String: [OHLCBar]] = [:]

    private let supabase: SupabaseClient
    private var refreshTimer: AnyCancellable?
    private var draftWatchTimer: AnyCancellable?
    /// Ensures the draft room auto-opens only once per scheduled draft, so
    /// closing it doesn't immediately reopen it.
    private var hasAutoOpenedDraft = false

    init(profile: UserProfile, supabase: SupabaseClient) {
        self.supabase = supabase
        let member = LeagueMember(
            id: profile.id,
            name: profile.username,
            teamName: profile.teamName,
            roster: [],
            wins: 0,
            losses: 0,
            isCurrentUser: true
        )
        self.league = League(
            id: UUID(),
            name: "",
            members: [member],
            currentWeek: 1,
            draftComplete: false,
            commissionerId: profile.id
        )
        loadDraftPool()
        startRefreshTimer()
    }

    // MARK: - Computed conveniences (delegate to current member)

    var currentUser: LeagueMember? { league.currentUser }

    var cash: Double { league.currentUser?.cash ?? LeagueConfig.startingCapital }

    var holdings: [String: Double] { league.currentUser?.holdings ?? [:] }

    var portfolioValue: Double { league.currentUser?.portfolioValue ?? LeagueConfig.startingCapital }

    var isCommissioner: Bool {
        guard let user = currentUser else { return false }
        return league.commissionerId == user.id
    }

    // MARK: - Draft pool

    func loadDraftPool() {
        availableStocks = Stock.draftPool().filter { !draftPicks.contains($0.id) }
    }

    // MARK: - Price refresh

    private func startRefreshTimer() {
        Task { await refreshPrices() }

        refreshTimer = Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in Task { await self?.refreshPrices() } }
    }

    func refreshPrices() async {
        guard let session = try? await supabase.auth.session else { return }
        let token = session.accessToken

        let rosterStocks = league.currentUser?.roster ?? []
        let allSymbols = Array(Set(availableStocks.map(\.id) + rosterStocks.map(\.id)))
        guard !allSymbols.isEmpty else { return }

        // Fetch independently so a bars failure doesn't block price updates (and
        // vice versa). Log rather than swallow: `try?` here meant a failing fetch
        // or a rejected decode looked identical to a market with no movement,
        // leaving every stock on its placeholder price with no clue why.
        var snaps: [String: AlpacaService.Snapshot] = [:]
        do {
            snaps = try await AlpacaService.snapshots(symbols: allSymbols, authToken: token)
        } catch {
            print("refreshPrices: snapshots failed — \(error.localizedDescription)")
        }

        var bars: [String: [AlpacaService.Bar]] = [:]
        do {
            bars = try await AlpacaService.dailyBars(symbols: allSymbols, limit: 7, authToken: token)
        } catch {
            print("refreshPrices: daily bars failed — \(error.localizedDescription)")
        }

        // Update available stocks — weekStartPrice from previous close
        for i in availableStocks.indices {
            let sym = availableStocks[i].id
            // Only claim live data once a real price actually arrived, so a
            // partial snapshot can't mark the placeholder as genuine.
            if let snap = snaps[sym], let price = snap.price {
                availableStocks[i].currentPrice = price
                // The baseline must never stay at the draft-pool placeholder, or
                // weeklyReturn is measured against a fictional price. Fall back to
                // today's open, then to the latest trade (which reads as 0% rather
                // than a bogus number). Non-positive values are skipped so the
                // division in weeklyReturn can't blow up.
                if let baseline = snap.returnBaseline {
                    availableStocks[i].weekStartPrice = baseline
                }
                availableStocks[i].hasPriceData = true
            }
            if let stockBars = bars[sym] {
                availableStocks[i].sparkline = stockBars.map(\.c)
                availableStocks[i].candles   = stockBars.map { OHLCBar(open: $0.o, high: $0.h, low: $0.l, close: $0.c) }
            }
        }

        // Update roster stocks — weekStartPrice stays as draft cost (return since draft)
        guard let userIdx = league.members.firstIndex(where: { $0.isCurrentUser }) else { return }
        for j in league.members[userIdx].roster.indices {
            let sym = league.members[userIdx].roster[j].id
            if let snap = snaps[sym], let price = snap.price {
                let firstRealPrice = !league.members[userIdx].roster[j].hasPriceData
                league.members[userIdx].roster[j].currentPrice = price
                league.members[userIdx].roster[j].hasPriceData = true
                if firstRealPrice {
                    // Replace draft-pool placeholder cost basis with first real market price
                    league.members[userIdx].roster[j].draftCostPrice = price
                    league.members[userIdx].roster[j].weekStartPrice = snap.returnBaseline ?? price
                }
            }
            if let stockBars = bars[sym] {
                league.members[userIdx].roster[j].sparkline = stockBars.map(\.c)
                league.members[userIdx].roster[j].candles   = stockBars.map { OHLCBar(open: $0.o, high: $0.h, low: $0.l, close: $0.c) }
            }
        }
    }

    // MARK: - Range-based candles

    private func rangeKey(_ symbol: String, _ range: ChartRange) -> String {
        "\(symbol):\(range.rawValue)"
    }

    func candles(for symbol: String, range: ChartRange) -> [OHLCBar] {
        rangeCandles[rangeKey(symbol, range)] ?? []
    }

    /// Fetches (and caches) the bar series backing one range for one symbol.
    func refreshCandles(for symbol: String, range: ChartRange) async {
        guard let session = try? await supabase.auth.session else { return }
        let token = session.accessToken
        guard let map = try? await AlpacaService.bars(
                symbols: [symbol], timeframe: range.timeframe,
                limit: range.barCount, authToken: token),
              let bars = map[symbol], !bars.isEmpty else { return }
        rangeCandles[rangeKey(symbol, range)] = bars.map {
            OHLCBar(open: $0.o, high: $0.h, low: $0.l, close: $0.c)
        }
    }

    /// Fetches every currently held symbol for a range — backs the portfolio chart.
    func refreshPortfolioCandles(range: ChartRange) async {
        let held = (currentUser?.roster ?? []).filter { (holdings[$0.id] ?? 0) > 0 }
        for stock in held {
            await refreshCandles(for: stock.id, range: range)
        }
    }

    /// Portfolio value over the selected range: uninvested cash plus each
    /// holding valued at that bar's close. Falls back to a stock's 7-day
    /// sparkline when range data hasn't arrived yet.
    func portfolioSeries(range: ChartRange) -> [Double] {
        guard let user = currentUser else { return [] }
        var series: [(shares: Double, closes: [Double])] = []
        for stock in user.roster {
            let shares = user.holdings[stock.id] ?? 0
            guard shares > 0 else { continue }
            let ranged = candles(for: stock.id, range: range).map(\.close)
            let closes = ranged.count > 1 ? ranged : stock.sparkline
            guard closes.count > 1 else { continue }
            series.append((shares, closes))
        }
        guard let n = series.map(\.closes.count).min(), n > 1 else { return [] }
        var out = [Double](repeating: user.cash, count: n)
        for entry in series {
            // Align on the most recent n bars so all series share an end date.
            for (i, close) in entry.closes.suffix(n).enumerated() {
                out[i] += entry.shares * close
            }
        }
        return out
    }

    func refreshIntradayBars(for symbol: String) async {
        guard let session = try? await supabase.auth.session else { return }
        let token = session.accessToken
        guard let barsMap = try? await AlpacaService.intradayBars(symbols: [symbol], authToken: token),
              let bars = barsMap[symbol], !bars.isEmpty else { return }
        guard let userIdx = league.members.firstIndex(where: { $0.isCurrentUser }) else { return }
        for j in league.members[userIdx].roster.indices where league.members[userIdx].roster[j].id == symbol {
            league.members[userIdx].roster[j].intradayCandles = bars.map {
                OHLCBar(open: $0.o, high: $0.h, low: $0.l, close: $0.c)
            }
            if let last = bars.last {
                let firstRealPrice = !league.members[userIdx].roster[j].hasPriceData
                league.members[userIdx].roster[j].currentPrice = last.c
                league.members[userIdx].roster[j].hasPriceData = true
                if firstRealPrice {
                    league.members[userIdx].roster[j].draftCostPrice = last.c
                    league.members[userIdx].roster[j].weekStartPrice = bars.first?.o ?? last.c
                }
            }
        }
    }

    // MARK: - Profile update

    func updateCurrentUserProfile(username: String, teamName: String) {
        guard let idx = league.members.firstIndex(where: { $0.isCurrentUser }) else { return }
        league.members[idx].name = username
        league.members[idx].teamName = teamName
    }

    // MARK: - League management

    func createLeague(name: String, startingCapital: Double = LeagueConfig.startingCapital) {
        league.name = name.isEmpty ? "My League" : name
        league.commissionerId = currentUser?.id ?? UUID()
        league.weekStartDate = Date()

        // Apply the chosen per-team starting cash and reset every member's
        // bankroll so cash, portfolio value, and returns stay consistent.
        LeagueConfig.startingCapital = startingCapital
        for idx in league.members.indices {
            league.members[idx].cash = startingCapital
        }

        hasLeague = true
    }

    func scheduleDraft(date: Date) {
        league.nextDraftDate = date
        // A new date is a new opportunity to auto-open.
        hasAutoOpenedDraft = false
        startDraftWatch()
    }

    /// Watches for the scheduled draft time to arrive while the app is running,
    /// then opens the draft room automatically. Only armed when a draft is
    /// actually pending, and cancels itself once it fires.
    private func startDraftWatch() {
        draftWatchTimer?.cancel()
        guard league.nextDraftDate != nil, !league.draftComplete, !hasAutoOpenedDraft else { return }
        draftWatchTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in Task { await self?.checkDraftAutoStart() } }
    }

    private func checkDraftAutoStart() {
        guard !hasAutoOpenedDraft, !league.draftComplete, draftTimeHasArrived else { return }
        hasAutoOpenedDraft = true
        draftActive = true
        draftWatchTimer?.cancel()
        draftWatchTimer = nil
    }

    /// The draft may only open once its scheduled time has arrived.
    var draftTimeHasArrived: Bool {
        guard let date = league.nextDraftDate else { return false }
        return Date() >= date
    }

    /// Commissioner-facing gate for the "Start Draft" control.
    var canStartDraft: Bool {
        isCommissioner && !league.draftComplete && draftTimeHasArrived
    }

    /// Opens the draft room, but only when the scheduled time has passed.
    /// Returns false if it's still too early.
    @discardableResult
    func startDraftIfDue() -> Bool {
        guard draftTimeHasArrived, !league.draftComplete else { return false }
        draftActive = true
        return true
    }

    // MARK: - Draft

    var draftPicksRemaining: Int {
        max(0, LeagueConfig.rosterSize * league.members.count - draftPicks.count)
    }

    func draftStock(_ stock: Stock) {
        guard draftPicksRemaining > 0 else { return }
        guard let idx = league.members.firstIndex(where: { $0.isCurrentUser }) else { return }
        var drafted = stock
        drafted.draftPickNumber  = draftPicks.count + 1
        drafted.draftCostPrice   = stock.currentPrice
        league.members[idx].roster.append(drafted)
        availableStocks.removeAll { $0.id == stock.id }
        draftPicks.append(stock.id)

        if draftPicksRemaining == 0 {
            league.draftComplete = true
        }
    }

    func undraftStock(_ stock: Stock) {
        guard let idx = league.members.firstIndex(where: { $0.isCurrentUser }) else { return }
        league.members[idx].roster.removeAll { $0.id == stock.id }
        availableStocks.append(stock)
        draftPicks.removeAll { $0 == stock.id }
        league.draftComplete = false
    }

    // MARK: - Paper trading (modifies current member's cash and holdings)

    func buy(stock: Stock, dollars: Double) -> String? {
        guard dollars > 0 else { return "Enter a valid amount" }
        guard let idx = league.members.firstIndex(where: { $0.isCurrentUser }) else { return "Error" }
        guard dollars <= league.members[idx].cash else { return "Insufficient cash" }
        let shares = dollars / stock.currentPrice
        league.members[idx].cash -= dollars
        league.members[idx].holdings[stock.id, default: 0] += shares
        return nil
    }

    func sell(stock: Stock, dollars: Double) -> String? {
        guard let idx = league.members.firstIndex(where: { $0.isCurrentUser }) else { return "Error" }
        let owned = league.members[idx].holdings[stock.id] ?? 0
        let ownedValue = owned * stock.currentPrice
        guard dollars > 0 else { return "Enter a valid amount" }
        guard dollars <= ownedValue else {
            return "You only own \(stock.currentPrice * owned < 1 ? "< $1" : String(format: "$%.0f", ownedValue))"
        }
        let shares = dollars / stock.currentPrice
        league.members[idx].cash += dollars
        league.members[idx].holdings[stock.id, default: 0] -= shares
        if (league.members[idx].holdings[stock.id] ?? 0) <= 0.00001 {
            league.members[idx].holdings.removeValue(forKey: stock.id)
        }
        return nil
    }
}

#if DEBUG
extension AppState {
    static var preview: AppState {
        let profile = UserProfile(id: UUID(), username: "Preview", teamName: "Preview FC")
        let state = AppState(profile: profile, supabase: SupabaseService().client)
        state.createLeague(name: "Preview League")
        state.scheduleDraft(date: Date().addingTimeInterval(86400 * 3))

        // Fake opponents so matchups and standings are populated in previews
        let opp1 = LeagueMember(id: UUID(), name: "Alice", teamName: "Bulls FC",
                                roster: [], wins: 1, losses: 0, isCurrentUser: false,
                                cash: 8_750, holdings: [:])
        let opp2 = LeagueMember(id: UUID(), name: "Bob", teamName: "Bears Co",
                                roster: [], wins: 0, losses: 1, isCurrentUser: false,
                                cash: 10_320, holdings: [:])
        state.league.members.append(contentsOf: [opp1, opp2])
        return state
    }
}
#endif
