import SwiftUI

// MARK: - LeagueView

struct LeagueView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedStock: Stock? = nil
    @State private var showCreateLeague = false
    @State private var showSetDraft = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    headerBar
                    if appState.hasLeague {
                        leagueNameSection
                        draftBandSection
                        if appState.league.draftComplete {
                            CircleDivider(weight: .section)
                            weekMatchupsSection
                        }
                        CircleDivider(weight: .section)
                        standingsSection
                        CircleDivider(weight: .section)
                        liveTradesSection
                    } else {
                        noLeagueSection
                    }
                    Spacer(minLength: 40)
                }
            }
            .background(Color.cBg)
            .navigationBarHidden(true)
            .ignoresSafeArea(edges: .top)
            .sheet(item: $selectedStock) { stock in
                StockDetailSheet(stock: stock)
                    .environmentObject(appState)
            }
            .navigationDestination(for: LeagueMember.self) { member in
                TeamDetailView(member: member)
                    .environmentObject(appState)
                    .navigationBarHidden(true)
            }
            .sheet(isPresented: $showCreateLeague) {
                CreateLeagueSheet(isPresented: $showCreateLeague)
                    .environmentObject(appState)
            }
            .sheet(isPresented: $showSetDraft) {
                SetDraftSheet(isPresented: $showSetDraft)
                    .environmentObject(appState)
            }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
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

    // MARK: - No League

    private var noLeagueSection: some View {
        VStack(spacing: CircleSpace.lg) {
            Image(systemName: "person.3")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color.cTextTertiary)
            VStack(spacing: CircleSpace.xs) {
                Text("No league yet")
                    .font(.cTitle)
                    .foregroundStyle(Color.cTextPrimary)
                    .textCase(.uppercase)
                Text("Create a league to draft stocks\nand compete with friends.")
                    .font(.cBody)
                    .foregroundStyle(Color.cTextSecondary)
                    .multilineTextAlignment(.center)
            }
            Button { showCreateLeague = true } label: {
                Text("Create League")
                    .font(.cBodyEmphasis)
                    .foregroundStyle(Color.cAccentTileBg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.cAccent)
                    .clipShape(RoundedRectangle(cornerRadius: CircleRadius.panel, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, CircleSpace.sm)
        }
        .padding(.horizontal, CircleSpace.lg)
        .padding(.top, 80)
        .frame(maxWidth: .infinity)
    }

    // MARK: - League Name

    private var leagueNameSection: some View {
        VStack(alignment: .leading, spacing: CircleSpace.xs) {
            Text(appState.league.name)
                .font(.cTitle)
                .foregroundStyle(Color.cTextPrimary)
                .textCase(.uppercase)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(appState.league.members.count) players · invite code \(leagueCode)")
                .font(.cBody)
                .foregroundStyle(Color.cTextSecondary)
        }
        .padding(.horizontal, CircleSpace.lg)
        .padding(.top, CircleSpace.xs)
        .padding(.bottom, CircleSpace.md)
    }

    private var leagueCode: String {
        appState.league.inviteCode
    }

    // MARK: - Draft Band

    @ViewBuilder
    private var draftBandSection: some View {
        if appState.league.draftComplete {
            draftCompleteBand
        } else if !appState.draftPicks.isEmpty {
            draftInProgressBand
        } else if let draftDate = appState.league.nextDraftDate {
            nextDraftBand(draftDate: draftDate)
        } else if appState.isCommissioner {
            scheduleDraftBand
        }
    }

    // Draft has started but isn't finished — offer to jump back in.
    private var draftInProgressBand: some View {
        let total = LeagueConfig.rosterSize * max(1, appState.league.members.count)
        return Button { appState.draftActive = true } label: {
            HStack {
                VStack(alignment: .leading, spacing: CircleSpace.xs) {
                    HStack(spacing: CircleSpace.xs) {
                        LiveDot(color: .cAccent, pulses: true)
                        Text("Draft in progress")
                            .font(.cBodyEmphasis)
                            .foregroundStyle(Color.cTextPrimary)
                    }
                    Text("\(appState.draftPicks.count) of \(total) picks made")
                        .font(.cMeta)
                        .foregroundStyle(Color.cTextSecondary)
                }
                Spacer()
                HStack(spacing: CircleSpace.xs) {
                    Text("Resume")
                        .font(.cBodyEmphasis)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(Color.cAccentTileBg)
                .padding(.horizontal, CircleSpace.md)
                .padding(.vertical, 11)
                .background(Color.cAccent)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
            .padding(CircleSpace.lgMinus)
            .background(Color.cBgPanel)
            .clipShape(RoundedRectangle(cornerRadius: CircleRadius.panel, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CircleRadius.panel, style: .continuous)
                    .strokeBorder(Color.cBorderChip, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, CircleSpace.lg)
        .padding(.top, CircleSpace.sm)
        .padding(.bottom, CircleSpace.md)
    }

    // Draft finished — roster is locked in.
    private var draftCompleteBand: some View {
        HStack {
            VStack(alignment: .leading, spacing: CircleSpace.xs) {
                HStack(spacing: CircleSpace.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.cAccent)
                    Text("Draft complete")
                        .font(.cBodyEmphasis)
                        .foregroundStyle(Color.cTextPrimary)
                }
                Text("Rosters are set for week \(appState.league.currentWeek)")
                    .font(.cMeta)
                    .foregroundStyle(Color.cTextSecondary)
            }
            Spacer()
        }
        .padding(CircleSpace.lgMinus)
        .background(Color.cBgPanel)
        .clipShape(RoundedRectangle(cornerRadius: CircleRadius.panel, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CircleRadius.panel, style: .continuous)
                .strokeBorder(Color.cBorderChip, lineWidth: 1)
        )
        .padding(.horizontal, CircleSpace.lg)
        .padding(.top, CircleSpace.sm)
        .padding(.bottom, CircleSpace.md)
    }

    private var scheduleDraftBand: some View {
        Button { showSetDraft = true } label: {
            HStack {
                VStack(alignment: .leading, spacing: CircleSpace.xs) {
                    Text("No draft scheduled")
                        .font(.cBodyEmphasis)
                        .foregroundStyle(Color.cTextPrimary)
                    Text("Set a date to kick off your league")
                        .font(.cMeta)
                        .foregroundStyle(Color.cTextSecondary)
                }
                Spacer()
                HStack(spacing: CircleSpace.xs) {
                    Text("Schedule")
                        .font(.cBodyEmphasis)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(Color.cAccentTileBg)
                .padding(.horizontal, CircleSpace.md)
                .padding(.vertical, 11)
                .background(Color.cAccent)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
            .padding(CircleSpace.lgMinus)
            .background(Color.cBgPanel)
            .clipShape(RoundedRectangle(cornerRadius: CircleRadius.panel, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CircleRadius.panel, style: .continuous)
                    .strokeBorder(Color.cBorderChip, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, CircleSpace.lg)
        .padding(.top, CircleSpace.sm)
        .padding(.bottom, CircleSpace.md)
    }

    // Ticks every second so the countdown stays live and the Start Draft
    // control unlocks the moment the scheduled time arrives.
    private func nextDraftBand(draftDate: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            nextDraftBandBody(draftDate: draftDate)
        }
    }

    private func nextDraftBandBody(draftDate: Date) -> some View {
        let diff = draftDate.timeIntervalSince(Date())
        let isDue = diff <= 0
        let countdown = isDue ? "Ready to start" : DraftCountdown.text(until: draftDate)

        let formatter = DateFormatter()
        formatter.dateFormat = "EEE MMM d · h:mma zzz"
        let dateString = formatter.string(from: draftDate)

        return ZStack(alignment: .trailing) {
            RoundedRectangle(cornerRadius: CircleRadius.panel, style: .continuous)
                .fill(Color.cAccentTileBg)

            GeometryReader { geo in
                let cx = geo.size.width + 10
                let cy = geo.size.height / 2
                Canvas { ctx, _ in
                    let radii: [CGFloat] = [44, 78, 112, 148, 186]
                    for (i, r) in radii.enumerated() {
                        let opacity = 0.22 - Double(i) * 0.04
                        let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
                        let path = Path(ellipseIn: rect)
                        ctx.stroke(path, with: .color(Color.cAccent.opacity(opacity)), lineWidth: 1)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: CircleRadius.panel, style: .continuous))

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: CircleSpace.xs) {
                    HStack(spacing: CircleSpace.xs) {
                        LiveDot(color: .cAccent, pulses: true)
                        Text("Next Draft")
                            .font(.cMeta)
                            .foregroundStyle(Color.cAccentMuted.opacity(0.7))
                    }
                    Text(countdown)
                        .font(.cBodyEmphasis)
                        .foregroundStyle(Color.cAccent)
                        .monospacedDigit()
                    Text(dateString)
                        .font(.cMeta)
                        .foregroundStyle(Color.cAccentMuted.opacity(0.7))
                }
                Spacer()
                if appState.isCommissioner {
                    VStack(alignment: .trailing, spacing: CircleSpace.xs) {
                        // Locked until the scheduled draft time arrives.
                        Button { appState.startDraftIfDue() } label: {
                            HStack(spacing: CircleSpace.xs) {
                                if !isDue {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 11, weight: .bold))
                                }
                                Text(isDue ? "Start Draft" : "Locked")
                                    .font(.cBodyEmphasis)
                                if isDue {
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 12, weight: .bold))
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
                        Button { showSetDraft = true } label: {
                            Text("Change date")
                                .font(.cMeta)
                                .foregroundStyle(Color.cAccentMuted.opacity(0.6))
                        }
                    }
                } else {
                    Button {} label: {
                        HStack(spacing: CircleSpace.xs) {
                            Text("Remind me")
                                .font(.cBodyEmphasis)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundStyle(Color.cAccentTileBg)
                        .padding(.horizontal, CircleSpace.md)
                        .padding(.vertical, 11)
                        .background(Color.cAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }
                }
            }
            .padding(CircleSpace.lgMinus)
        }
        .frame(height: 140)
        .padding(.horizontal, CircleSpace.lg)
        .padding(.top, CircleSpace.sm)
        .padding(.bottom, CircleSpace.md)
    }

    // MARK: - Week Matchups

    private var weekMatchupsSection: some View {
        let matchups = appState.league.weeklyMatchups
        return VStack(alignment: .leading, spacing: 0) {
            SectionHeader(
                title: "Week \(appState.league.currentWeek) Matchups",
                subtitle: "Current pairings"
            )
            CircleDivider()

            if matchups.isEmpty {
                Text("Need at least 2 players for matchups")
                    .font(.cBody)
                    .foregroundStyle(Color.cTextTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, CircleSpace.xl)
            } else {
                ForEach(Array(matchups.enumerated()), id: \.element.id) { idx, matchup in
                    weekMatchupRow(matchup)
                    if idx < matchups.count - 1 { CircleDivider() }
                }
            }
        }
    }

    private func weekMatchupRow(_ matchup: Matchup) -> some View {
        let userVal  = matchup.userScore
        let oppVal   = matchup.opponentScore
        let leading  = userVal >= oppVal ? matchup.userTeam : matchup.opponentTeam
        let trailing = userVal >= oppVal ? matchup.opponentTeam : matchup.userTeam
        let isCurrentUser = matchup.userTeam.isCurrentUser || matchup.opponentTeam.isCurrentUser

        return HStack(spacing: CircleSpace.base) {
            CircleAvatar(
                initials: String(leading.name.prefix(2)).uppercased(),
                team: leading.isCurrentUser ? .selfBrand : CircleAvatar.TeamColor.forUserID(leading.id.uuidString),
                diameter: CircleIcon.Avatar.sm
            )
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: CircleSpace.xs) {
                    Text(leading.teamName).font(.cBodyEmphasis).foregroundStyle(Color.cTextPrimary).lineLimit(1)
                    if leading.isCurrentUser { TagChip("YOU", style: .yours) }
                }
                Text(String(format: "$%@", Int(max(userVal, oppVal)).formatted()))
                    .font(.cMeta).foregroundStyle(Color.cAccent).monospacedDigit()
            }
            Spacer()
            Text("VS").font(.cMeta).foregroundStyle(Color.cTextTertiary)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: CircleSpace.xs) {
                    if trailing.isCurrentUser { TagChip("YOU", style: .yours) }
                    Text(trailing.teamName).font(.cBodyEmphasis).foregroundStyle(Color.cTextPrimary).lineLimit(1)
                }
                Text(String(format: "$%@", Int(min(userVal, oppVal)).formatted()))
                    .font(.cMeta).foregroundStyle(Color.cTextSecondary).monospacedDigit()
            }
            CircleAvatar(
                initials: String(trailing.name.prefix(2)).uppercased(),
                team: trailing.isCurrentUser ? .selfBrand : CircleAvatar.TeamColor.forUserID(trailing.id.uuidString),
                diameter: CircleIcon.Avatar.sm
            )
        }
        .padding(.horizontal, CircleSpace.lg)
        .padding(.vertical, CircleSpace.base)
        .background(isCurrentUser ? Color.cBgYours : Color.clear)
        .overlay(alignment: .leading) {
            if isCurrentUser { Rectangle().fill(Color.cAccent).frame(width: 2) }
        }
    }

    // MARK: - Standings

    private var standingsSection: some View {
        let standings = appState.league.standings
        let opponentId = appState.league.currentMatchup?.opponentTeam.id

        return VStack(alignment: .leading, spacing: 0) {
            SectionHeader(
                title: "Standings",
                subtitle: "Sorted by portfolio value"
            )
            CircleDivider()

            ForEach(Array(standings.enumerated()), id: \.element.id) { index, member in
                NavigationLink(value: member) {
                    standingRow(rank: index + 1, member: member, isOpponent: member.id == opponentId)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if index < standings.count - 1 {
                    CircleDivider().padding(.leading, CircleSpace.lg + 20 + CircleSpace.base + CircleIcon.Avatar.lg + CircleSpace.base)
                }
            }

            Button {} label: {
                Text("See all \(appState.league.members.count) teams →")
                    .font(.cBodyEmphasis)
                    .foregroundStyle(Color.cAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, CircleSpace.lgMinus)
            }
        }
    }

    private func standingRow(rank: Int, member: LeagueMember, isOpponent: Bool) -> some View {
        let portfolioVal = member.portfolioValue
        let ret = member.totalWeeklyReturn
        let isUser = member.isCurrentUser
        let teamColor = CircleAvatar.TeamColor.forUserID(member.id.uuidString)

        return HStack(spacing: CircleSpace.base) {
            Text("\(rank)")
                .font(.cBodyEmphasis)
                .foregroundStyle(isUser ? Color.cAccent : Color.cTextSecondary)
                .monospacedDigit()
                .frame(width: 20, alignment: .center)

            CircleAvatar(
                initials: String(member.name.prefix(2)).uppercased(),
                team: isUser ? .selfBrand : teamColor,
                diameter: CircleIcon.Avatar.lg,
                crown: rank == 1
            )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: CircleSpace.xs) {
                    Text(member.teamName)
                        .font(.cBodyEmphasis)
                        .foregroundStyle(Color.cTextPrimary)
                        .lineLimit(1)
                    if isUser {
                        TagChip("YOU", style: .yours)
                    }
                    if isOpponent && !isUser {
                        TagChip("MATCHUP", style: .neutral)
                    }
                }
                Text("@\(member.name) · \(member.wins)W · \(member.losses)L")
                    .font(.cMeta)
                    .foregroundStyle(Color.cTextSecondary)
            }

            Spacer(minLength: CircleSpace.sm)

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "$%.0f", portfolioVal))
                    .font(.cBodyEmphasis)
                    .foregroundStyle(Color.cTextPrimary)
                    .monospacedDigit()
                Text(String(format: "%@%.1f%%", ret >= 0 ? "+" : "", ret * 100))
                    .font(.cMeta)
                    .foregroundStyle(ret >= 0 ? Color.cAccent : Color.cLoss)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, CircleSpace.lg)
        .padding(.vertical, CircleSpace.base)
        .background(isUser ? Color.cBgYours : Color.clear)
        .overlay(alignment: .leading) {
            if isUser {
                Rectangle().fill(Color.cAccent).frame(width: 2)
            }
        }
    }

    // MARK: - Live Trades

    private var liveTradesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(
                title: "Live Trades",
                subtitle: "This week",
                leadingIcon: "bolt.fill"
            )
            CircleDivider()

            Text("No trades yet this week")
                .font(.cBody)
                .foregroundStyle(Color.cTextTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, CircleSpace.xl)

            Button {} label: {
                Text("See full trade history →")
                    .font(.cBodyEmphasis)
                    .foregroundStyle(Color.cAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, CircleSpace.xl)
            }
        }
    }
}

// MARK: - Create League Sheet

private struct CreateLeagueSheet: View {
    @EnvironmentObject var appState: AppState
    @Binding var isPresented: Bool
    @State private var leagueName = ""
    @State private var startingCash = "10000"
    @FocusState private var focusedField: Field?

    private enum Field { case name, cash }

    private let cashPresets: [Double] = [5_000, 10_000, 25_000, 50_000]

    private var startingCashValue: Double {
        Double(startingCash.filter { $0.isNumber || $0 == "." }) ?? 0
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: CircleSpace.lg) {
                VStack(alignment: .leading, spacing: CircleSpace.xs) {
                    Text("Name your league")
                        .font(.cTitle)
                        .foregroundStyle(Color.cTextPrimary)
                    Text("You can always change this later.")
                        .font(.cBody)
                        .foregroundStyle(Color.cTextSecondary)
                }

                TextField("e.g. Stock Smashers", text: $leagueName)
                    .font(.cBody)
                    .foregroundStyle(Color.cTextPrimary)
                    .padding(CircleSpace.md)
                    .background(Color.cBgPanel)
                    .clipShape(RoundedRectangle(cornerRadius: CircleRadius.panel, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: CircleRadius.panel, style: .continuous)
                            .strokeBorder(Color.cBorderChip, lineWidth: 1)
                    )
                    .focused($focusedField, equals: .name)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .cash }

                // Starting cash per team
                VStack(alignment: .leading, spacing: CircleSpace.sm) {
                    Text("Starting cash per team")
                        .font(.cBodyEmphasis)
                        .foregroundStyle(Color.cTextPrimary)

                    HStack(spacing: CircleSpace.xs) {
                        Text("$")
                            .font(.cBody)
                            .foregroundStyle(Color.cTextSecondary)
                        TextField("10,000", text: $startingCash)
                            .keyboardType(.numberPad)
                            .font(.cBody)
                            .foregroundStyle(Color.cTextPrimary)
                            .tint(Color.cAccent)
                            .focused($focusedField, equals: .cash)
                    }
                    .padding(CircleSpace.md)
                    .background(Color.cBgPanel)
                    .clipShape(RoundedRectangle(cornerRadius: CircleRadius.panel, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: CircleRadius.panel, style: .continuous)
                            .strokeBorder(Color.cBorderChip, lineWidth: 1)
                    )

                    HStack(spacing: CircleSpace.xs) {
                        ForEach(cashPresets, id: \.self) { preset in
                            let isSelected = startingCashValue == preset
                            Button {
                                Haptics.select()
                                startingCash = String(Int(preset))
                            } label: {
                                Text(preset.formatted(.currency(code: "USD").precision(.fractionLength(0))))
                                    .font(.cMeta)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(isSelected ? Color.cAccent : Color.cTextSecondary)
                                    .frame(maxWidth: .infinity)
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
                    }
                }

                Spacer()

                Button {
                    let cash = startingCashValue > 0 ? startingCashValue : 10_000
                    appState.createLeague(name: leagueName, startingCapital: cash)
                    isPresented = false
                } label: {
                    Text("Create League")
                        .font(.cBodyEmphasis)
                        .foregroundStyle(Color.cAccentTileBg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.cAccent)
                        .clipShape(RoundedRectangle(cornerRadius: CircleRadius.panel, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(CircleSpace.lg)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(Color.cBg)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { isPresented = false }
                        .foregroundStyle(Color.cTextSecondary)
                }
            }
        }
        .presentationDetents([.large])
        .preferredColorScheme(.dark)
        // Delay focus until the present animation settles — focusing during
        // the transition is what made the sheet stutter on its way up.
        .task {
            try? await Task.sleep(for: .milliseconds(450))
            focusedField = .name
        }
    }
}

// MARK: - Set Draft Sheet

private struct SetDraftSheet: View {
    @EnvironmentObject var appState: AppState
    @Binding var isPresented: Bool
    @State private var draftDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("Schedule Draft")
                    .font(.cTitle)
                    .foregroundStyle(Color.cTextPrimary)
                    .padding(.horizontal, CircleSpace.lg)
                    .padding(.top, CircleSpace.lg)
                    .padding(.bottom, CircleSpace.sm)

                DatePicker("", selection: $draftDate, in: Date()...)
                    .datePickerStyle(.graphical)
                    .tint(Color.cAccent)
                    .padding(.horizontal, CircleSpace.md)

                Spacer()

                Button {
                    appState.scheduleDraft(date: draftDate)
                    isPresented = false
                } label: {
                    Text("Set Draft Date")
                        .font(.cBodyEmphasis)
                        .foregroundStyle(Color.cAccentTileBg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.cAccent)
                        .clipShape(RoundedRectangle(cornerRadius: CircleRadius.panel, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, CircleSpace.lg)
                .padding(.bottom, CircleSpace.lg)
            }
            .background(Color.cBg)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { isPresented = false }
                        .foregroundStyle(Color.cTextSecondary)
                }
            }
        }
        .presentationDetents([.large])
        .preferredColorScheme(.dark)
    }
}

#Preview {
    LeagueView()
        .environmentObject(AppState.preview)
        .preferredColorScheme(.dark)
}
