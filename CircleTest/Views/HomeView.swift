import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var showMatchupDetail = false
    @State private var barProgress: CGFloat = 0
    @State private var revealPhase: Int = 0
    @State private var chartProgress: CGFloat = 0
    @State private var bannerIndex: Int = 0
    @State private var selectedStock: Stock? = nil
    @State private var bannerTimer: Timer? = nil

    // MARK: - Derived data

    private var pricedRoster: [Stock] {
        (appState.currentUser?.roster ?? []).filter { $0.hasPriceData }
    }

    // Portfolio chart: uses actual holdings × sparklines when invested, otherwise
    // falls back to normalized roster average so the chart is never blank.
    private var portfolioChartData: [Double]? {
        if let user = appState.currentUser {
            let investedStocks = pricedRoster.filter {
                (user.holdings[$0.id] ?? 0) > 0 && $0.sparkline.count > 1
            }
            if !investedStocks.isEmpty {
                let minCount = investedStocks.map(\.sparkline.count).min()!
                var result = [Double](repeating: user.cash, count: minCount)
                for stock in investedStocks {
                    let shares = user.holdings[stock.id] ?? 0
                    for i in 0..<minCount { result[i] += shares * stock.sparkline[i] }
                }
                return result
            }
        }
        // Fallback: normalized average of all roster picks (shows what returns could be)
        let stocks = pricedRoster.filter { $0.sparkline.count > 1 }
        guard !stocks.isEmpty else { return nil }
        let minCount = stocks.map(\.sparkline.count).min()!
        var result = [Double](repeating: 0, count: minCount)
        var validCount = 0
        for stock in stocks {
            guard let first = stock.sparkline.first, first > 0 else { continue }
            for i in 0..<minCount { result[i] += stock.sparkline[i] / first }
            validCount += 1
        }
        guard validCount > 0 else { return nil }
        let n = Double(validCount)
        return result.map { LeagueConfig.startingCapital * $0 / n }
    }

    private var teamValue: Double {
        appState.currentUser?.portfolioValue ?? LeagueConfig.startingCapital
    }

    private var teamGainLoss: Double { teamValue - LeagueConfig.startingCapital }

    // Banner content is derived from live prices when available; falls back to
    // generic messages so the banner is never blank.
    private var bannerEvents: [(tag: String, text: AttributedString)] {
        var events: [(tag: String, text: AttributedString)] = []
        func ev(_ tag: String, _ raw: String) -> (tag: String, text: AttributedString) {
            (tag, (try? AttributedString(markdown: raw)) ?? AttributedString(raw))
        }

        let pricedAvail = appState.availableStocks.filter { $0.hasPriceData }

        if let mvp = pricedRoster.max(by: { $0.weeklyReturn < $1.weeklyReturn }), mvp.weeklyReturn > 0.001 {
            events.append(ev("ROSTER", "**\(mvp.id)** is your top pick at \(String(format: "+%.1f%%", mvp.weeklyReturn * 100)) this week"))
        }
        if pricedRoster.count > 1, let lag = pricedRoster.min(by: { $0.weeklyReturn < $1.weeklyReturn }), lag.weeklyReturn < -0.001 {
            events.append(ev("WATCH", "**\(lag.id)** is your weakest at \(String(format: "%.1f%%", lag.weeklyReturn * 100)) — watch for a bounce"))
        }
        if let top = pricedAvail.max(by: { $0.weeklyReturn < $1.weeklyReturn }), top.weeklyReturn > 0.001 {
            events.append(ev("MARKET", "**\(top.id)** is the market leader at \(String(format: "+%.1f%%", top.weeklyReturn * 100)) this week"))
        }
        if let down = pricedAvail.filter({ $0.weeklyReturn < -0.005 }).min(by: { $0.weeklyReturn < $1.weeklyReturn }) {
            events.append(ev("MARKET", "**\(down.id)** is down \(String(format: "%.1f%%", down.weeklyReturn * 100)) — sliding this week"))
        }
        if events.isEmpty {
            events.append(ev("LIVE", "Market data refreshes every 60 seconds"))
            if appState.hasLeague, appState.league.nextDraftDate != nil {
                events.append(ev("DRAFT", "Your draft is coming up — prepare your picks!"))
            } else if !appState.hasLeague {
                events.append(ev("START", "Create a league in the League tab to get started"))
            }
        }
        return events
    }

    private var safeBannerIndex: Int {
        let count = bannerEvents.count
        return count > 0 ? bannerIndex % count : 0
    }

    // MARK: - Body

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                navBar
                eventBanner

                if appState.hasLeague {
                    liveWeekRow
                        .opacity(revealPhase >= 2 ? 1 : 0)
                        .offset(y: revealPhase >= 2 ? 0 : 8)
                }

                if appState.league.draftComplete || !pricedRoster.isEmpty {
                    teamValueSection
                        .opacity(revealPhase >= 3 ? 1 : 0)
                        .offset(y: revealPhase >= 3 ? 0 : 12)
                }

                if let chartData = portfolioChartData {
                    HomeChartCanvas(
                        userPoints: chartData,
                        oppPoints: [],
                        showOpponent: false,
                        drawProgress: chartProgress
                    )
                    .frame(height: 140)
                    .padding(.top, 20)
                    .padding(.bottom, 4)
                    .opacity(revealPhase >= 4 ? 1 : 0)

                    chartLabels
                        .opacity(revealPhase >= 4 ? 1 : 0)
                }

                matchupSection
                    .opacity(revealPhase >= 5 ? 1 : 0)
                    .offset(y: revealPhase >= 5 ? 0 : 12)

                if showMatchupDetail {
                    expandedMatchupDetail
                } else {
                    rosterSection
                }

                homeActionCard

                Spacer(minLength: 32)
            }
        }
        .background(Color.cBg.ignoresSafeArea())
        .ignoresSafeArea(edges: .top)
        .onAppear { startRevealSequence() }
        .sheet(item: $selectedStock) { stock in
            StockDetailSheet(stock: stock)
                .environmentObject(appState)
        }
    }

    private func startRevealSequence() {
        withAnimation(.easeOut(duration: 0.2)) { revealPhase = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.25)) { revealPhase = 2 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { revealPhase = 3 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            revealPhase = 4
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.easeInOut(duration: 1.0)) { chartProgress = 1 }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { revealPhase = 5 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            withAnimation(.easeOut(duration: 0.2)) { revealPhase = 6 }
        }
    }

    // MARK: - Nav Bar

    private var navBar: some View {
        HStack {
            BrandLockup()
            Spacer()
            NavTrailingChrome(
                userInitials: String((appState.currentUser?.name.prefix(2) ?? "ME").uppercased())
            )
        }
        .padding(.horizontal, CircleSpace.lg)
        .padding(.top, 60)
        .padding(.bottom, 12)
    }

    // MARK: - Event Banner

    private var eventBanner: some View {
        ZStack {
            let events = bannerEvents
            ForEach(events.indices, id: \.self) { i in
                if i == safeBannerIndex {
                    HStack(spacing: CircleSpace.sm) {
                        Text(events[i].tag)
                            .font(.cTiny)
                            .fontWeight(.semibold)
                            .tracking(CircleTracking.eyebrow)
                            .foregroundStyle(Color.cTextSecondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.cBgPanel)
                            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .strokeBorder(Color.cBorderChip, lineWidth: 1))
                        Text(events[i].text)
                            .font(.cMeta)
                            .foregroundStyle(Color.cTextSecondary)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, CircleSpace.lg)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal:   .move(edge: .top).combined(with: .opacity)
                    ))
                }
            }
        }
        .frame(height: 32)
        .clipped()
        .background(Color.cBg)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.cDividerSection).frame(height: 0.5)
        }
        .onAppear {
            bannerTimer?.invalidate()
            bannerTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.35)) {
                    let count = bannerEvents.count
                    if count > 0 { bannerIndex = (bannerIndex + 1) % count }
                }
            }
        }
        .onDisappear {
            bannerTimer?.invalidate()
            bannerTimer = nil
        }
    }

    // MARK: - Live Week Row

    private var liveWeekRow: some View {
        HStack {
            HStack(spacing: CircleSpace.sm) {
                LiveDot(color: .cAccent, pulses: true)
                Text("Live · week \(appState.league.currentWeek)")
                    .font(.cBodyEmphasis)
                    .foregroundStyle(Color.cAccent)
            }
            Spacer()
            if let rank = appState.league.standings.firstIndex(where: { $0.isCurrentUser }).map({ $0 + 1 }) {
                HStack(spacing: CircleSpace.xxs) {
                    Text("★").font(.system(size: 11)).foregroundStyle(Color.cGold)
                    Text("#\(rank) of \(appState.league.members.count)")
                        .font(.cBodyEmphasis)
                        .foregroundStyle(Color.cTextPrimary)
                        .monospacedDigit()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.cBgPanel)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(Color.cBorderChip, lineWidth: 1))
            }
        }
        .padding(.horizontal, CircleSpace.lg)
        .padding(.bottom, CircleSpace.md)
    }

    // MARK: - Team Value

    private var teamValueSection: some View {
        let ret = appState.currentUser?.totalWeeklyReturn ?? 0
        let value = teamValue
        let gainLoss = teamGainLoss
        let isPos = gainLoss >= 0

        let dollars = "$\(Int(value).formatted())"
        let centsVal = Int((value.truncatingRemainder(dividingBy: 1)) * 100)
        let cents = String(format: ".%02d", centsVal)

        return VStack(alignment: .leading, spacing: CircleSpace.sm) {
            HeroNumber(
                dollars: dollars,
                cents: cents,
                eyebrow: "\(appState.currentUser?.teamName ?? "Your Team") · week \(appState.league.currentWeek)",
                color: .cTextPrimary,
                size: .cHeroMobile
            )
            HStack(spacing: CircleSpace.base) {
                DeltaPill(
                    value: gainLoss,
                    formatted: String(format: "%@$%.2f", isPos ? "+" : "−", abs(gainLoss))
                )
                Text(String(format: "%@%.1f%%", ret >= 0 ? "+" : "", ret * 100))
                    .font(.cBodyEmphasis)
                    .foregroundStyle(isPos ? Color.cAccent : Color.cLoss)
                    .monospacedDigit()
                Text("this week")
                    .font(.cBody)
                    .foregroundStyle(Color.cTextSecondary)
            }
        }
        .padding(.leading, CircleSpace.lg)
    }

    // MARK: - Chart Labels

    private var chartLabels: some View {
        let days = ["7d", "6d", "5d", "4d", "3d", "2d", "Now"]
        return VStack(alignment: .leading, spacing: CircleSpace.sm) {
            HStack(spacing: 0) {
                ForEach(days, id: \.self) { d in
                    Text(d)
                        .font(.cTiny)
                        .foregroundStyle(d == "Now" ? Color.cAccent : Color.cTextSecondary)
                        .fontWeight(d == "Now" ? .medium : .regular)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, CircleSpace.lg)
        }
        .padding(.top, CircleSpace.base)
        .padding(.bottom, CircleSpace.sm)
    }

    // MARK: - Matchup Section

    private var matchupSection: some View {
        Group {
            if let matchup = appState.league.currentMatchup {
                let userVal   = matchup.userScore
                let oppVal    = matchup.opponentScore
                let lead      = userVal - oppVal
                let leadPct   = oppVal > 0 ? lead / oppVal * 100 : 0
                let total     = userVal + oppVal
                let frac      = max(0.05, min(0.95, userVal / total))
                let isWinning = matchup.userIsWinning

                VStack(alignment: .leading, spacing: 0) {
                    CircleDivider(weight: .section)

                    Button {
                        Haptics.tap()
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                            showMatchupDetail.toggle()
                        }
                    } label: {
                        HStack {
                            HStack(spacing: CircleSpace.xs) {
                                LiveDot(color: .cAccent, pulses: true, size: 6)
                                Text("MATCHUP · WEEK \(matchup.weekNumber)")
                                    .font(.cEyebrow)
                                    .tracking(CircleTracking.eyebrow)
                                    .foregroundStyle(Color.cTextSecondary)
                            }
                            Spacer()
                            Image(systemName: showMatchupDetail ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.cTextSecondary)
                        }
                        .padding(.horizontal, CircleSpace.lg)
                        .padding(.top, CircleSpace.base)
                        .padding(.bottom, CircleSpace.sm)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(appState.currentUser?.teamName ?? "You")
                                .font(.cMeta).foregroundStyle(Color.cTextSecondary).lineLimit(1)
                            Text(String(format: "$%d", Int(userVal)))
                                .font(.cTitleStat).foregroundStyle(Color.cAccent)
                        }
                        Spacer()
                        Text("VS").font(.cMeta).foregroundStyle(Color.cTextSecondary)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(matchup.opponentTeam.teamName)
                                .font(.cMeta).foregroundStyle(Color.cTextSecondary).lineLimit(1)
                            Text(String(format: "$%d", Int(oppVal)))
                                .font(.cTitleStat).foregroundStyle(Color.cTextSecondary)
                        }
                    }
                    .padding(.horizontal, CircleSpace.lg)
                    .padding(.bottom, CircleSpace.base)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(Color.cDividerSection).frame(height: 3)
                            Rectangle()
                                .fill(isWinning ? Color.cAccent : Color.cLoss)
                                .frame(width: geo.size.width * frac * barProgress, height: 3)
                        }
                    }
                    .frame(height: 3)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { barProgress = 1 }
                        }
                    }

                    HStack(spacing: CircleSpace.xxs) {
                        Text(isWinning ? "You lead by" : "Trailing by")
                            .font(.cMeta).foregroundStyle(Color.cTextSecondary)
                        Text(String(format: "$%.0f (%.1f%%)", abs(lead), abs(leadPct)))
                            .font(.cMeta)
                            .foregroundStyle(isWinning ? Color.cAccent : Color.cLoss)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, CircleSpace.lg)
                    .padding(.top, CircleSpace.xs)
                    .padding(.bottom, CircleSpace.base)
                }
            }
        }
    }

    // MARK: - Expanded Matchup Detail

    private var expandedMatchupDetail: some View {
        Group {
            if let matchup = appState.league.currentMatchup, showMatchupDetail {
                VStack(alignment: .leading, spacing: 0) {
                    h2hSection(matchup)
                    matchupNotes(matchup)
                    matchupButtons
                }
                .transition(.opacity)
            }
        }
    }

    private func h2hSection(_ matchup: Matchup) -> some View {
        let userRoster = matchup.userTeam.roster.sorted { $0.weeklyReturn > $1.weeklyReturn }
        let oppRoster  = matchup.opponentTeam.roster.sorted { $0.weeklyReturn > $1.weeklyReturn }
        let count      = max(userRoster.count, oppRoster.count)
        let pairs      = (0..<min(userRoster.count, oppRoster.count)).map { i in
            userRoster[i].weeklyReturn - oppRoster[i].weeklyReturn
        }
        let userWins = pairs.filter { $0 > 0.001 }.count
        let ties     = pairs.filter { abs($0) <= 0.001 }.count

        return VStack(alignment: .leading, spacing: 0) {
            CircleDivider(weight: .section)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("MATCHUP").font(.cBodyEmphasis).foregroundStyle(Color.cTextPrimary).textCase(.uppercase)
                    Text("Ranked best to worst").font(.cMeta).foregroundStyle(Color.cTextSecondary)
                }
                Spacer()
                HStack(spacing: CircleSpace.xxs) {
                    Text("You win").font(.cMeta).foregroundStyle(Color.cTextSecondary)
                    Text("\(userWins)").font(.cBodyEmphasis).foregroundStyle(Color.cAccent).monospacedDigit()
                    Text("· Tie").font(.cMeta).foregroundStyle(Color.cTextSecondary)
                    Text("\(ties)").font(.cBodyEmphasis).foregroundStyle(Color.cTextPrimary).monospacedDigit()
                }
            }
            .padding(.horizontal, CircleSpace.lg)
            .padding(.vertical, CircleSpace.md)

            ForEach(0..<count, id: \.self) { i in
                let user = i < userRoster.count ? userRoster[i] : nil
                let opp  = i < oppRoster.count  ? oppRoster[i]  : nil
                Button {
                    if let s = user { Haptics.select(); selectedStock = s }
                } label: {
                    h2hRow(rank: i + 1, userStock: user, oppStock: opp).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if i < count - 1 { CircleDivider().padding(.horizontal, CircleSpace.lg) }
            }
        }
        .padding(.bottom, CircleSpace.xs)
    }

    private func h2hRow(rank: Int, userStock: Stock?, oppStock: Stock?) -> some View {
        let userRet  = userStock?.weeklyReturn ?? 0
        let oppRet   = oppStock?.weeklyReturn ?? 0
        let diff     = userRet - oppRet
        let userWins = diff > 0.001
        let tied     = abs(diff) <= 0.001
        let userTone: TickerTile.Tone = userRet >= 0 ? .green : .red
        let oppTone:  TickerTile.Tone = oppRet  >= 0 ? (userWins ? .neutral : .green) : .red

        return HStack(spacing: 0) {
            HStack(spacing: CircleSpace.base) {
                TickerTile(symbol: userStock?.id ?? "—", tone: userTone, size: .md)
                VStack(alignment: .leading, spacing: 2) {
                    Text(userStock?.id ?? "—").font(.cBodyEmphasis).foregroundStyle(Color.cTextPrimary)
                    Text(String(format: "%@%.1f%%", userRet >= 0 ? "+" : "", userRet * 100))
                        .font(.cMeta)
                        .foregroundStyle(userRet >= 0 ? Color.cAccent : Color.cLoss)
                        .monospacedDigit()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 2) {
                if tied {
                    Text("—").font(.cMeta).foregroundStyle(Color.cTextSecondary)
                } else {
                    Image(systemName: userWins ? "chevron.left" : "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(userWins ? Color.cAccent : Color.cLoss)
                }
                Text(String(format: "+%.1f", abs(diff) * 100))
                    .font(.system(size: 9).monospacedDigit())
                    .foregroundStyle(tied ? Color.cTextSecondary : (userWins ? Color.cAccent : Color.cLoss))
            }
            .frame(width: 36)

            HStack(spacing: CircleSpace.base) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(oppStock?.id ?? "—").font(.cBodyEmphasis).foregroundStyle(Color.cTextPrimary)
                    Text(String(format: "%@%.1f%%", oppRet >= 0 ? "+" : "", oppRet * 100))
                        .font(.cMeta)
                        .foregroundStyle(oppRet >= 0 ? (userWins ? Color.cTextSecondary : Color.cAccent) : Color.cLoss)
                        .monospacedDigit()
                }
                TickerTile(symbol: oppStock?.id ?? "—", tone: oppTone, size: .md)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, CircleSpace.lg)
        .padding(.vertical, CircleSpace.md)
    }

    private func matchupNotes(_ matchup: Matchup) -> some View {
        let mvp = matchup.userTeam.roster.max(by: { $0.weeklyReturn < $1.weeklyReturn })
        return VStack(alignment: .leading, spacing: 0) {
            CircleDivider(weight: .section)
            Text("Notes")
                .font(.cBodyEmphasis).foregroundStyle(Color.cTextPrimary).textCase(.uppercase)
                .padding(.horizontal, CircleSpace.lg)
                .padding(.top, CircleSpace.lgMinus)
                .padding(.bottom, CircleSpace.base)
            VStack(alignment: .leading, spacing: CircleSpace.md) {
                if let mvp {
                    noteRow(icon: "star.fill", iconColor: Color.cGold,
                            text: "Your **\(mvp.id)** is the MVP of the week at \(String(format: "+%.1f%%", mvp.weeklyReturn * 100))")
                }
                noteRow(icon: "exclamationmark.triangle.fill", iconColor: Color.cHot,
                        text: "Watch for earnings this week — swings could affect your lead")
            }
            .padding(.horizontal, CircleSpace.lg)
            .padding(.bottom, CircleSpace.lg)
        }
    }

    private func noteRow(icon: String, iconColor: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: CircleSpace.base) {
            Image(systemName: icon).font(.system(size: 13)).foregroundStyle(iconColor).frame(width: 18)
            Text((try? AttributedString(markdown: text)) ?? AttributedString(text))
                .font(.cBody).foregroundStyle(Color.cTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var matchupButtons: some View {
        HStack(spacing: CircleSpace.base) {
            SecondaryButton(title: "Share", icon: "square.and.arrow.up") {}
            PrimaryButton(title: "Trash talk") {}
        }
        .padding(.horizontal, CircleSpace.lg)
        .padding(.vertical, CircleSpace.lg)
    }

    // MARK: - Roster Section

    private var rosterSection: some View {
        let roster = (appState.currentUser?.roster ?? [])
            .sorted { ($0.draftPickNumber ?? 99) < ($1.draftPickNumber ?? 99) }

        return VStack(alignment: .leading, spacing: 0) {
            if !roster.isEmpty {
                SectionHeader(title: "Your Roster", trailing: "See all \(roster.count) →")
                    .opacity(revealPhase >= 6 ? 1 : 0)
                    .offset(y: revealPhase >= 6 ? 0 : 8)
                CircleDivider(weight: .section)

                ForEach(Array(roster.prefix(5).enumerated()), id: \.element.id) { idx, stock in
                    Button {
                        Haptics.select()
                        selectedStock = stock
                    } label: {
                        rosterRow(stock).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .opacity(revealPhase >= 6 ? 1 : 0)
                    .offset(y: revealPhase >= 6 ? 0 : 12)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double(idx) * 0.06), value: revealPhase)
                    if idx < min(roster.count, 5) - 1 {
                        CircleDivider().padding(.leading, CircleSpace.lg + CircleIcon.Tile.md + CircleSpace.base)
                    }
                }
            }
        }
    }

    private func rosterRow(_ stock: Stock) -> some View {
        let metaText: String = {
            if let pick = stock.draftPickNumber, let cost = stock.draftCostPrice {
                return "\(ordinal(pick)) pick · $\(Int(cost))"
            }
            return stock.sector
        }()

        guard stock.hasPriceData else {
            return RosterRow(
                symbol: stock.id, companyName: stock.name, metaText: metaText,
                price: "—", deltaPercent: 0, deltaPercentText: "Loading",
                sparklineData: [], tags: [], tone: .neutral
            )
        }

        let isPos = stock.weeklyReturn >= 0
        let tone: TickerTile.Tone = {
            if stock.tag == .star { return .gold }
            if stock.tag == .hot  { return .orange }
            return isPos ? .green : .red
        }()
        let tags: [TagChip] = {
            if stock.tag == .star { return [TagChip("STAR", style: .star, leadingIcon: "star.fill")] }
            if stock.tag == .hot  { return [TagChip("HOT",  style: .hot,  leadingIcon: "flame.fill")] }
            return []
        }()

        return RosterRow(
            symbol: stock.id, companyName: stock.name, metaText: metaText,
            price: stock.currentPrice.formatted(.currency(code: "USD")),
            deltaPercent: stock.weeklyReturn,
            deltaPercentText: String(format: "%@%.2f%%", isPos ? "+" : "", abs(stock.weeklyReturn * 100)),
            sparklineData: stock.sparkline, tags: tags, tone: tone
        )
    }

    private func ordinal(_ n: Int) -> String {
        switch n {
        case 1: return "1st"; case 2: return "2nd"; case 3: return "3rd"
        default: return "\(n)th"
        }
    }

    // MARK: - Home Action Card

    @ViewBuilder
    private var homeActionCard: some View {
        if !appState.hasLeague {
            noLeagueCard
        } else if let draftDate = appState.league.nextDraftDate, !appState.league.draftComplete {
            draftCard(draftDate: draftDate)
        } else if appState.isCommissioner && !appState.league.draftComplete && appState.league.nextDraftDate == nil {
            scheduleDraftNudge
        }
    }

    private var noLeagueCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: CircleSpace.xs) {
                Text("No league yet")
                    .font(.cBodyEmphasis)
                    .foregroundStyle(Color.cTextPrimary)
                Text("Create a league and schedule a draft\nto start competing.")
                    .font(.cMeta)
                    .foregroundStyle(Color.cTextSecondary)
            }
            Spacer()
            Image(systemName: "person.3.fill")
                .font(.system(size: 22))
                .foregroundStyle(Color.cTextTertiary)
        }
        .padding(CircleSpace.lgMinus)
        .background(Color.cBgPanel)
        .clipShape(RoundedRectangle(cornerRadius: CircleRadius.panel, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: CircleRadius.panel, style: .continuous)
            .strokeBorder(Color.cBorderChip, lineWidth: 1))
        .padding(.horizontal, CircleSpace.lg)
        .padding(.top, CircleSpace.xl)
        .padding(.bottom, CircleSpace.xs)
    }

    private func draftCard(draftDate: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            draftCardBody(draftDate: draftDate)
        }
    }

    private func draftCardBody(draftDate: Date) -> some View {
        let isDue = draftDate.timeIntervalSince(Date()) <= 0
        let countdown = isDue ? "Ready to start" : DraftCountdown.text(until: draftDate)

        return ZStack(alignment: .trailing) {
            RoundedRectangle(cornerRadius: CircleRadius.panel, style: .continuous)
                .fill(Color.cAccentTileBg)

            GeometryReader { geo in
                let cx = geo.size.width + 10; let cy = geo.size.height / 2
                Canvas { ctx, _ in
                    let radii: [CGFloat] = [44, 78, 112, 148, 186]
                    for (i, r) in radii.enumerated() {
                        let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
                        ctx.stroke(Path(ellipseIn: rect),
                                   with: .color(Color.cAccent.opacity(0.22 - Double(i) * 0.04)), lineWidth: 1)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: CircleRadius.panel, style: .continuous))

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: CircleSpace.xs) {
                    Text("Draft")
                        .font(.cMeta)
                        .foregroundStyle(Color.cAccentMuted.opacity(0.7))
                    Text(countdown)
                        .font(.cBodyEmphasis)
                        .foregroundStyle(Color.cAccent)
                        .monospacedDigit()
                    HStack(spacing: CircleSpace.xs) {
                        Image(systemName: "clock").font(.system(size: 11))
                        Text(draftDateString(draftDate)).font(.cMeta)
                    }
                    .foregroundStyle(Color.cAccentMuted.opacity(0.7))
                }
                Spacer()
                if appState.isCommissioner {
                    // Locked until the scheduled draft time arrives.
                    Button { appState.startDraftIfDue() } label: {
                        HStack(spacing: CircleSpace.xs) {
                            if !isDue {
                                Image(systemName: "lock.fill").font(.system(size: 11, weight: .bold))
                            }
                            Text(isDue ? "Start Draft" : "Locked").font(.cBodyEmphasis)
                            if isDue {
                                Image(systemName: "arrow.right").font(.system(size: 12, weight: .bold))
                            }
                        }
                        .foregroundStyle(isDue ? Color.cAccentTileBg : Color.cTextSecondary)
                        .padding(.horizontal, CircleSpace.md)
                        .padding(.vertical, 11)
                        .background(isDue ? Color.cAccent : Color.cBgPanel)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .strokeBorder(isDue ? Color.clear : Color.cBorderChip, lineWidth: 1)
                        )
                    }
                    .disabled(!isDue)
                }
            }
            .padding(CircleSpace.lgMinus)
        }
        .frame(height: 120)
        .padding(.horizontal, CircleSpace.lg)
        .padding(.top, CircleSpace.xl)
        .padding(.bottom, CircleSpace.xs)
    }

    private var scheduleDraftNudge: some View {
        HStack {
            VStack(alignment: .leading, spacing: CircleSpace.xs) {
                Text("Schedule your draft")
                    .font(.cBodyEmphasis)
                    .foregroundStyle(Color.cTextPrimary)
                Text("Head to the League tab to set a date and kick things off.")
                    .font(.cMeta)
                    .foregroundStyle(Color.cTextSecondary)
            }
            Spacer()
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 22))
                .foregroundStyle(Color.cAccent)
        }
        .padding(CircleSpace.lgMinus)
        .background(Color.cBgPanel)
        .clipShape(RoundedRectangle(cornerRadius: CircleRadius.panel, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: CircleRadius.panel, style: .continuous)
            .strokeBorder(Color.cBorderChip, lineWidth: 1))
        .padding(.horizontal, CircleSpace.lg)
        .padding(.top, CircleSpace.xl)
        .padding(.bottom, CircleSpace.xs)
    }

    private func draftDateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE MMM d · h:mma"
        return f.string(from: date)
    }
}

// MARK: - Home Chart Canvas

struct HomeChartCanvas: View {
    let userPoints: [Double]
    let oppPoints: [Double]
    let showOpponent: Bool
    var drawProgress: CGFloat = 1

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let allPts = showOpponent ? userPoints + oppPoints : userPoints
            let minV = (allPts.min() ?? 0) * 0.995
            let maxV = (allPts.max() ?? 1) * 1.005
            let range = max(maxV - minV, 1)
            let clipWidth = max(1, w * drawProgress)

            Canvas { ctx, size in
                func cx(_ i: Int, _ total: Int) -> CGFloat {
                    CGFloat(i) / CGFloat(total - 1) * w
                }
                func cy(_ v: Double) -> CGFloat {
                    h - CGFloat((v - minV) / range) * h * 0.88 - h * 0.06
                }

                ctx.clip(to: Path(CGRect(x: 0, y: 0, width: clipWidth, height: h)))

                var fill = Path()
                fill.move(to: CGPoint(x: 0, y: h))
                for i in 0..<userPoints.count {
                    fill.addLine(to: CGPoint(x: cx(i, userPoints.count), y: cy(userPoints[i])))
                }
                fill.addLine(to: CGPoint(x: w, y: h))
                fill.closeSubpath()
                ctx.fill(fill, with: .linearGradient(
                    Gradient(colors: [Color.cAccent.opacity(showOpponent ? 0.2 : 0.35), Color.cAccent.opacity(0)]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: h)
                ))

                if showOpponent && oppPoints.count > 1 {
                    var oppLine = Path()
                    oppLine.move(to: CGPoint(x: cx(0, oppPoints.count), y: cy(oppPoints[0])))
                    for i in 1..<oppPoints.count {
                        oppLine.addLine(to: CGPoint(x: cx(i, oppPoints.count), y: cy(oppPoints[i])))
                    }
                    ctx.stroke(oppLine, with: .color(Color.white.opacity(0.35)),
                               style: StrokeStyle(lineWidth: CircleStroke.chart, lineCap: .round, lineJoin: .round))
                }

                var userLine = Path()
                userLine.move(to: CGPoint(x: cx(0, userPoints.count), y: cy(userPoints[0])))
                for i in 1..<userPoints.count {
                    userLine.addLine(to: CGPoint(x: cx(i, userPoints.count), y: cy(userPoints[i])))
                }
                ctx.stroke(userLine, with: .color(Color.cAccent),
                           style: StrokeStyle(lineWidth: CircleStroke.chartHero, lineCap: .round, lineJoin: .round))

                if drawProgress > 0.95 {
                    let lastX = cx(userPoints.count - 1, userPoints.count)
                    let lastY = cy(userPoints.last!)
                    ctx.fill(Path(ellipseIn: CGRect(x: lastX - 4, y: lastY - 4, width: 8, height: 8)),
                             with: .color(Color.cAccent))
                }
            }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState.preview)
        .preferredColorScheme(.dark)
}
