import SwiftUI

// MARK: - Helpers (file-private)

private enum DraftTier: String, CaseIterable, Hashable {
    case elite    = "Elite tier"
    case solid    = "Solid picks"
    case sleepers = "Sleepers"

    var icon: String {
        switch self {
        case .elite:    return "star.fill"
        case .solid:    return "circle.fill"
        case .sleepers: return "bolt.fill"
        }
    }
    var iconColor: Color {
        switch self {
        case .elite:    return .cGold
        case .solid:    return .cAccent
        case .sleepers: return .cTeamOrange
        }
    }
}

private func tier(for stock: Stock) -> DraftTier {
    let elite    = ["NVDA","AAPL","MSFT","TSLA","GOOGL","META","AMZN"]
    let sleepers = ["COIN","NFLX","SPOT","DIS","PLTR"]
    if elite.contains(stock.id)    { return .elite }
    if sleepers.contains(stock.id) { return .sleepers }
    return .solid
}

private func adp(for stock: Stock) -> Double {
    let map: [String: Double] = [
        "NVDA": 1.2, "AAPL": 2.1, "MSFT": 3.4, "AMZN": 3.2, "TSLA": 4.6,
        "GOOGL": 4.8, "META": 6.1, "JPM": 10.5, "V": 12.3, "WMT": 14.7,
        "XOM": 15.4, "UNH": 18.2, "JNJ": 22.1, "KO": 19.8, "AMD": 25.0,
        "NFLX": 28.4, "SPOT": 35.1, "PLTR": 40.2, "COIN": 44.8, "DIS": 50.0,
    ]
    return map[stock.id] ?? 60.0
}

// MARK: - DraftView

struct DraftView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedFilter: String = "All"
    @State private var confirmStock: Stock? = nil
    @State private var justDrafted: String? = nil
    @State private var countdownSeconds: Int = 90
    @State private var countdownTimer: Timer? = nil

    private let filterOptions = ["All", "Mega cap", "Growth", "Value", "Sleeper"]

    // MARK: - Turn / round helpers

    private var totalPicks: Int  { LeagueConfig.rosterSize * max(1, appState.league.members.count) }
    private var pickNumber: Int  { appState.draftPicks.count + 1 }
    private var currentRound: Int { (appState.draftPicks.count / max(1, appState.league.members.count)) + 1 }

    // Snake-draft: who picks at overall pick index `n` (0-based)?
    // Round direction alternates. For single-player, always returns the user.
    private var currentPickerIndex: Int {
        let members = appState.league.members
        guard members.count > 1 else { return 0 }
        let n = appState.draftPicks.count
        let round = n / members.count
        let posInRound = n % members.count
        return round % 2 == 0 ? posInRound : (members.count - 1 - posInRound)
    }

    private var isMyTurn: Bool {
        let members = appState.league.members
        guard !members.isEmpty else { return true }
        return members[currentPickerIndex].isCurrentUser
    }

    private var currentPickerName: String {
        let members = appState.league.members
        guard members.indices.contains(currentPickerIndex) else { return "You" }
        let member = members[currentPickerIndex]
        return member.isCurrentUser ? "You" : member.name
    }

    // MARK: - Stock lists

    private var filteredStocks: [Stock] {
        let all = appState.availableStocks
        switch selectedFilter {
        case "Mega cap":
            return all.filter { ["NVDA","AAPL","MSFT","TSLA","GOOGL","META","AMZN"].contains($0.id) }
                      .sorted { adp(for: $0) < adp(for: $1) }
        case "Growth":
            // Growth names by identity, not just live daily return — the draft
            // pool starts flat (no price data), so a return-only filter is empty.
            let growth: Set<String> = ["NVDA","TSLA","PLTR","COIN","AMD","META","SPOT","NFLX","AMZN","GOOGL"]
            return all.filter { growth.contains($0.id) || $0.weeklyReturn > 0.01 }
                      .sorted { adp(for: $0) < adp(for: $1) }
        case "Value":
            return all.filter { $0.currentPrice < 200 }.sorted { adp(for: $0) < adp(for: $1) }
        case "Sleeper":
            return all.filter { tier(for: $0) == .sleepers }.sorted { adp(for: $0) < adp(for: $1) }
        default:
            return all.sorted { adp(for: $0) < adp(for: $1) }
        }
    }

    private var tieredStocks: [(tier: DraftTier, stocks: [Stock])] {
        guard selectedFilter == "All" else { return [] }
        return DraftTier.allCases.compactMap { t in
            let s = appState.availableStocks.filter { tier(for: $0) == t }.sorted { adp(for: $0) < adp(for: $1) }
            return s.isEmpty ? nil : (t, s)
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                headerBar
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        clockCard
                        availablePicksSection
                        Spacer(minLength: 120)
                    }
                }
            }
            .background(Color.cBg.ignoresSafeArea())
            .ignoresSafeArea(edges: .top)

            // Completion overlay
            if appState.league.draftComplete {
                draftCompleteOverlay
                    .transition(.opacity)
            }
        }
        .onAppear { resetAndStartTimer() }
        .onDisappear { countdownTimer?.invalidate() }
        .confirmationDialog(
            confirmStock.map { "Draft \($0.name) (\($0.id))?" } ?? "",
            isPresented: .init(get: { confirmStock != nil }, set: { if !$0 { confirmStock = nil } }),
            titleVisibility: .visible
        ) {
            if let stock = confirmStock {
                Button("Draft \(stock.id)") {
                    performPick(stock)
                    confirmStock = nil
                }
                Button("Cancel", role: .cancel) { confirmStock = nil }
            }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        ZStack {
            Color.cBg
            VStack(spacing: 2) {
                Spacer(minLength: 0)
                Text("Round \(currentRound) · \(currentPickerName) picks")
                    .font(.cMeta)
                    .foregroundStyle(Color.cTextSecondary)
                Text("Pick \(min(pickNumber, totalPicks)) of \(totalPicks)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.cTextPrimary)
                Spacer(minLength: 0)
            }
            HStack {
                Button { appState.draftActive = false } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.cTextPrimary)
                        .frame(width: 36, height: 36)
                        .background(Color.cBgPanel)
                        .clipShape(Circle())
                }
                .padding(.leading, CircleSpace.lg)
                Spacer()
                if !appState.draftPicks.isEmpty {
                    Text("\(appState.draftPicks.count) / \(totalPicks)")
                        .font(.cMeta)
                        .foregroundStyle(Color.cAccent)
                        .padding(.trailing, CircleSpace.lg)
                }
            }
        }
        .frame(height: 88)
        .padding(.top, 44)
        .frame(height: 132)
    }

    // MARK: - Clock Card

    private var clockCard: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        HStack(spacing: 6) {
                            Circle().fill(isMyTurn ? Color.cAccent : Color.cTextTertiary).frame(width: 8, height: 8)
                            Text(isMyTurn ? "You're on the clock" : "\(currentPickerName) is picking…")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(isMyTurn ? Color.cAccent : Color.cTextSecondary)
                        }
                        Spacer()
                        if isMyTurn {
                            Text("AUTO")
                                .font(.system(size: 12, weight: .black))
                                .foregroundStyle(Color.cAccentTileBg)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background(Color.cAccent)
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        }
                    }
                    .padding(.bottom, 12)

                    HStack(alignment: .lastTextBaseline, spacing: 0) {
                        Text(countdownFormatted)
                            .font(.system(size: 72, weight: .bold, design: .monospaced))
                            .foregroundStyle(countdownSeconds <= 10 ? Color.cLoss : Color.cAccent)
                            .monospacedDigit()
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Circle()
                                .trim(from: 0, to: CGFloat(countdownSeconds) / 90.0)
                                .stroke(Color.cAccent.opacity(0.25), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .frame(width: 52, height: 52)
                            Text("until autopick")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.cTextSecondary)
                        }
                    }
                    .padding(.bottom, 14)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.cBorderChip).frame(height: 4)
                            Capsule()
                                .fill(countdownSeconds <= 10 ? Color.cLoss : Color.cAccent)
                                .frame(width: geo.size.width * CGFloat(countdownSeconds) / 90.0, height: 4)
                        }
                    }
                    .frame(height: 4)
                    .padding(.bottom, 14)

                    HStack {
                        Text("Pick **\(min(pickNumber, totalPicks))**")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.cTextSecondary)
                        Spacer()
                        Text("\(appState.availableStocks.count) stocks remaining")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.cTextSecondary)
                    }
                }
                .padding(20)
            }
            .background(Color.cAccentTileBg)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(Color.cAccentBorder25, lineWidth: 1)
            )
            .padding(.horizontal, CircleSpace.lg)
            .padding(.top, CircleSpace.lg)
            .padding(.bottom, CircleSpace.mdPlus)
        }
    }

    private var countdownFormatted: String {
        let m = countdownSeconds / 60
        let s = countdownSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Timer

    private func resetAndStartTimer() {
        countdownTimer?.invalidate()
        countdownSeconds = 90
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            if countdownSeconds > 0 {
                countdownSeconds -= 1
            } else {
                t.invalidate()
                if isMyTurn { triggerAutoPick() }
            }
        }
    }

    private func triggerAutoPick() {
        let sorted = appState.availableStocks.sorted { adp(for: $0) < adp(for: $1) }
        guard let top = sorted.first else { return }
        performPick(top)
    }

    private func performPick(_ stock: Stock) {
        guard appState.draftPicksRemaining > 0 else { return }
        Haptics.draft()
        withAnimation { appState.draftStock(stock); justDrafted = stock.id }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { justDrafted = nil }
        if !appState.league.draftComplete {
            resetAndStartTimer()
        } else {
            countdownTimer?.invalidate()
            Confetti.fire()
        }
    }

    // MARK: - Available Picks Section

    private var availablePicksSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Available Picks")
                        .font(.cBodyEmphasis)
                        .foregroundStyle(Color.cTextPrimary)
                        .textCase(.uppercase)
                    Text("\(appState.availableStocks.count) stocks · sorted by tier")
                        .font(.cMeta)
                        .foregroundStyle(Color.cTextSecondary)
                }
                Spacer()
            }
            .padding(.horizontal, CircleSpace.lg)
            .padding(.bottom, CircleSpace.base)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(filterOptions, id: \.self) { option in
                        filterPill(option)
                    }
                }
                .padding(.horizontal, CircleSpace.lg)
            }
            .padding(.bottom, CircleSpace.mdPlus)

            if appState.availableStocks.isEmpty {
                VStack(spacing: CircleSpace.base) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.cAccent)
                    Text("All stocks drafted!")
                        .font(.cBodyEmphasis)
                        .foregroundStyle(Color.cTextPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, CircleSpace.xl * 2)
            } else if selectedFilter == "All" {
                ForEach(tieredStocks, id: \.tier) { group in
                    tierSection(group.tier, stocks: group.stocks)
                }
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(filteredStocks.enumerated()), id: \.element.id) { idx, stock in
                        stockRow(stock)
                        if idx < filteredStocks.count - 1 {
                            CircleDivider(weight: .row).padding(.leading, 76)
                        }
                    }
                }
            }
        }
        .padding(.bottom, 8)
    }

    private func filterPill(_ label: String) -> some View {
        let isSelected = selectedFilter == label
        return Button { Haptics.select(); selectedFilter = label } label: {
            Text(label)
                .font(.cMeta).fontWeight(.semibold)
                .foregroundStyle(isSelected ? Color.cAccent : Color.cTextSecondary)
                .padding(.horizontal, CircleSpace.md)
                .padding(.vertical, CircleSpace.xs)
                .background(isSelected ? Color.cAccent.opacity(0.15) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(isSelected ? Color.cAccent : Color.cBorderChip, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tier Section

    private func tierSection(_ t: DraftTier, stocks: [Stock]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: t.icon).font(.system(size: 12, weight: .semibold)).foregroundStyle(t.iconColor)
                Text(t.rawValue).font(.cBodyEmphasis).foregroundStyle(Color.cTextPrimary)
                Text("· \(stocks.count) left").font(.cBody).foregroundStyle(Color.cTextSecondary)
                Spacer()
                HStack(spacing: 2) {
                    Text("ADP").font(.cMeta).fontWeight(.semibold).foregroundStyle(Color.cTextSecondary)
                    Image(systemName: "arrow.up").font(.system(size: 10, weight: .bold)).foregroundStyle(Color.cTextSecondary)
                }
            }
            .padding(.horizontal, CircleSpace.lg)
            .padding(.vertical, CircleSpace.base)

            LazyVStack(spacing: 0) {
                ForEach(Array(stocks.enumerated()), id: \.element.id) { idx, stock in
                    stockRow(stock)
                    if idx < stocks.count - 1 {
                        CircleDivider(weight: .row).padding(.leading, 76)
                    }
                }
            }

            CircleDivider(weight: .section)
        }
    }

    // MARK: - Stock Row

    private func stockRow(_ stock: Stock) -> some View {
        let isPos = stock.weeklyReturn >= 0
        let tone: TickerTile.Tone = {
            if stock.tag == .star { return .gold }
            if stock.tag == .hot  { return .orange }
            return isPos ? .green : .red
        }()

        return HStack(spacing: CircleSpace.base) {
            TickerTile(symbol: stock.id, tone: tone, size: .md)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: CircleSpace.xs) {
                    Text(stock.name).font(.cBodyEmphasis).foregroundStyle(Color.cTextPrimary).lineLimit(1)
                    if stock.tag == .hot {
                        TagChip("HOT", style: .hot, leadingIcon: "flame.fill")
                    } else if stock.tag == .star {
                        TagChip("TOP", style: .star, leadingIcon: "star.fill")
                    }
                }
                Text("\(stock.sector) · ADP \(String(format: "%.1f", adp(for: stock)))")
                    .font(.cMeta).foregroundStyle(Color.cTextSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 3) {
                Text(stock.currentPrice, format: .currency(code: "USD"))
                    .font(.cBodyEmphasis).foregroundStyle(Color.cTextPrimary).lineLimit(1).monospacedDigit()
                Text(String(format: "%@%.1f%%", isPos ? "+" : "", stock.weeklyReturn * 100))
                    .font(.cMeta).fontWeight(.semibold)
                    .foregroundStyle(isPos ? Color.cAccent : Color.cLoss).monospacedDigit()
            }
            .fixedSize(horizontal: true, vertical: false)

            Button {
                guard appState.draftPicksRemaining > 0 && isMyTurn else { return }
                confirmStock = stock
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.cAccentTileBg)
                    .frame(width: 36, height: 36)
                    .background(appState.draftPicksRemaining > 0 && isMyTurn ? Color.cAccent : Color.cTextTertiary)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, CircleSpace.lg)
        .padding(.vertical, CircleSpace.base)
        .background(justDrafted == stock.id ? Color.cAccent.opacity(0.08) : Color.clear)
        .animation(.easeOut(duration: 0.3), value: justDrafted)
    }

    // MARK: - Draft Complete Overlay

    private var draftCompleteOverlay: some View {
        ZStack {
            Color.cBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: CircleSpace.xl) {
                    Spacer(minLength: CircleSpace.xxxl)

                    // Trophy / checkmark
                    ZStack {
                        Circle()
                            .fill(Color.cAccentTileBg)
                            .frame(width: 88, height: 88)
                        Image(systemName: "checkmark")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(Color.cAccent)
                    }

                    VStack(spacing: CircleSpace.xs) {
                        Text("Draft Complete")
                            .font(.cTitle)
                            .foregroundStyle(Color.cTextPrimary)
                            .textCase(.uppercase)
                        Text("\(appState.currentUser?.teamName ?? "Your team") is set for week \(appState.league.currentWeek)")
                            .font(.cBody)
                            .foregroundStyle(Color.cTextSecondary)
                            .multilineTextAlignment(.center)
                    }

                    // Roster summary
                    let roster = appState.currentUser?.roster ?? []
                    VStack(spacing: 0) {
                        ForEach(Array(roster.enumerated()), id: \.element.id) { idx, stock in
                            HStack(spacing: CircleSpace.base) {
                                Text("\(idx + 1)")
                                    .font(.cMeta)
                                    .foregroundStyle(Color.cTextTertiary)
                                    .frame(width: 16, alignment: .center)
                                    .monospacedDigit()
                                TickerTile(symbol: stock.id,
                                           tone: stock.hasPriceData ? (stock.weeklyReturn >= 0 ? .green : .red) : .neutral,
                                           size: .sm)
                                Text(stock.name)
                                    .font(.cBodyEmphasis)
                                    .foregroundStyle(Color.cTextPrimary)
                                    .lineLimit(1)
                                Spacer()
                                if stock.hasPriceData {
                                    let ret = stock.weeklyReturn
                                    Text(String(format: "%@%.1f%%", ret >= 0 ? "+" : "", ret * 100))
                                        .font(.cMeta)
                                        .foregroundStyle(ret >= 0 ? Color.cAccent : Color.cLoss)
                                        .monospacedDigit()
                                }
                            }
                            .padding(.horizontal, CircleSpace.lg)
                            .padding(.vertical, CircleSpace.md)
                            if idx < roster.count - 1 {
                                CircleDivider(weight: .row).padding(.leading, CircleSpace.lg + 16 + CircleSpace.base + CircleIcon.Tile.sm + CircleSpace.base)
                            }
                        }
                    }
                    .background(Color.cBgPanel)
                    .clipShape(RoundedRectangle(cornerRadius: CircleRadius.panel, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: CircleRadius.panel, style: .continuous)
                            .strokeBorder(Color.cBorderChip, lineWidth: CircleStroke.hairline)
                    )
                    .padding(.horizontal, CircleSpace.lg)

                    Button {
                        appState.draftActive = false
                    } label: {
                        Text("Let's Go")
                            .font(.cBodyEmphasis)
                            .foregroundStyle(Color.cAccentTileBg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.cAccent)
                            .clipShape(RoundedRectangle(cornerRadius: CircleRadius.panel, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, CircleSpace.lg)

                    Spacer(minLength: CircleSpace.xxxl)
                }
            }
        }
        .onAppear { Confetti.fire() }
    }
}

#Preview {
    DraftView()
        .environmentObject(AppState.preview)
        .preferredColorScheme(.dark)
}
