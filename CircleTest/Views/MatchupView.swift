import SwiftUI

struct MatchupView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                headerBar
                if let matchup = appState.league.currentMatchup {
                    scoreHero(matchup)
                    chartSection(matchup)
                    CircleDivider(weight: .section)
                    headToHeadSection(matchup)
                } else {
                    noMatchupBanner
                }
                CircleDivider(weight: .section)
                allMatchupsSection
                Spacer(minLength: 40)
            }
        }
        .background(Color.cBg.ignoresSafeArea())
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Header

    private var headerBar: some View {
        ZStack {
            Color.cBg
            VStack(spacing: 2) {
                Spacer()
                Text("WEEK \(appState.league.currentWeek)")
                    .font(.cTiny)
                    .tracking(CircleTracking.eyebrowTight)
                    .foregroundStyle(Color.cTextTertiary)
                Text("MATCHUP")
                    .font(.cTitleSection)
                    .foregroundStyle(Color.cTextPrimary)
                Spacer()
            }
            HStack {
                Spacer()
                NavTrailingChrome(
                    userInitials: String((appState.currentUser?.name.prefix(2) ?? "ME").uppercased())
                )
                .padding(.trailing, CircleSpace.lg)
            }
        }
        .frame(height: 132)
    }

    // MARK: - No Matchup

    private var noMatchupBanner: some View {
        VStack(spacing: CircleSpace.md) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Color.cTextTertiary)
            Text("No matchup yet")
                .font(.cBodyEmphasis)
                .foregroundStyle(Color.cTextPrimary)
            Text("Matchups are set up once there are at least 2 players in the league.")
                .font(.cBody)
                .foregroundStyle(Color.cTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, CircleSpace.xl)
        .padding(.top, 60)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Score Hero

    private func scoreHero(_ matchup: Matchup) -> some View {
        let userVal    = matchup.userScore
        let oppVal     = matchup.opponentScore
        let lead       = userVal - oppVal
        let leadPct    = oppVal > 0 ? lead / oppVal * 100 : 0
        let total      = userVal + oppVal
        let frac       = total > 0 ? max(0.05, min(0.95, userVal / total)) : 0.5
        let isWinning  = matchup.userIsWinning

        let weekEnd    = appState.league.weekStartDate.addingTimeInterval(7 * 86400)
        let remaining  = max(0, weekEnd.timeIntervalSince(Date()))
        let daysLeft   = Int(remaining / 86400)
        let hoursLeft  = Int(remaining.truncatingRemainder(dividingBy: 86400) / 3600)
        let timeString = remaining > 3600 ? "\(daysLeft)d \(hoursLeft)h left" : "Ending soon"

        return VStack(alignment: .leading, spacing: 16) {
            // Names + avatars
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    CircleAvatar(
                        initials: String((appState.currentUser?.name.prefix(2) ?? "ME").uppercased()),
                        team: .selfBrand,
                        diameter: CircleIcon.Avatar.sm
                    )
                    VStack(alignment: .leading, spacing: 1) {
                        Text("You").font(.cBodyEmphasis).foregroundStyle(Color.cTextPrimary)
                        Text(appState.currentUser?.teamName ?? "").font(.cMeta).foregroundStyle(Color.cTextSecondary).lineLimit(1)
                    }
                }
                Spacer()
                HStack(spacing: 8) {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(matchup.opponentTeam.name).font(.cBodyEmphasis).foregroundStyle(Color.cTextPrimary)
                        Text(matchup.opponentTeam.teamName).font(.cMeta).foregroundStyle(Color.cTextSecondary).lineLimit(1)
                    }
                    CircleAvatar(
                        initials: String(matchup.opponentTeam.name.prefix(2)).uppercased(),
                        team: CircleAvatar.TeamColor.forUserID(matchup.opponentTeam.id.uuidString),
                        diameter: CircleIcon.Avatar.sm
                    )
                }
            }

            // Big scores
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(format: "$%@", Int(userVal).formatted()))
                        .font(.cTitle).foregroundStyle(Color.cAccent)
                    let userGain = matchup.userTeam.totalWeeklyGainLoss
                    HStack(spacing: 4) {
                        Image(systemName: userGain >= 0 ? "arrow.up" : "arrow.down").font(.cMeta)
                        Text(String(format: "%@$%.0f this week", userGain >= 0 ? "+" : "-", abs(userGain))).font(.cMeta)
                    }
                    .foregroundStyle(userGain >= 0 ? Color.cAccent : Color.cLoss)
                }
                Spacer()
                Text("VS").font(.cMeta).foregroundStyle(Color.cTextTertiary).padding(.top, 14)
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "$%@", Int(oppVal).formatted()))
                        .font(.cTitle).foregroundStyle(Color.cTextSecondary)
                    let oppGain = matchup.opponentTeam.totalWeeklyGainLoss
                    HStack(spacing: 4) {
                        Image(systemName: oppGain >= 0 ? "arrow.up" : "arrow.down").font(.cMeta)
                        Text(String(format: "%@$%.0f this week", oppGain >= 0 ? "+" : "-", abs(oppGain))).font(.cMeta)
                    }
                    .foregroundStyle(oppGain >= 0 ? Color.cAccent : Color.cLoss)
                }
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.cBgPanel).frame(height: 6)
                    Capsule()
                        .fill(isWinning ? Color.cAccent : Color.cLoss)
                        .frame(width: geo.size.width * frac, height: 6)
                }
            }
            .frame(height: 6)

            // Lead + time remaining
            HStack {
                HStack(spacing: 4) {
                    Text(isWinning ? "Leading by" : "Trailing by")
                        .font(.cMeta).foregroundStyle(Color.cTextSecondary)
                    Text(String(format: "$%@ · %.1f%%", Int(abs(lead)).formatted(), abs(leadPct)))
                        .font(.cMeta).fontWeight(.medium)
                        .foregroundStyle(isWinning ? Color.cAccent : Color.cLoss)
                }
                Spacer()
                Text(timeString).font(.cMeta).foregroundStyle(Color.cTextSecondary)
            }
        }
        .padding(.horizontal, CircleSpace.lg)
        .padding(.top, CircleSpace.base)
        .padding(.bottom, CircleSpace.xl)
    }

    // MARK: - Chart

    private func chartSection(_ matchup: Matchup) -> some View {
        let userSeries  = portfolioSeries(matchup.userTeam)
        let oppSeries   = portfolioSeries(matchup.opponentTeam)
        let hasData     = userSeries.count > 1

        return Group {
            if hasData {
                VStack(alignment: .leading, spacing: 0) {
                    MatchupChartCanvas(userPoints: userSeries, oppPoints: oppSeries.count > 1 ? oppSeries : [])
                        .frame(height: 160)
                        .padding(.horizontal, CircleSpace.lg)

                    let days = ["7d", "6d", "5d", "4d", "3d", "2d", "Now"]
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
                    .padding(.top, CircleSpace.sm)

                    HStack(spacing: CircleSpace.lg) {
                        HStack(spacing: 6) {
                            Rectangle().fill(Color.cAccent).frame(width: 20, height: 2)
                            Text("You").font(.cMeta).foregroundStyle(Color.cTextPrimary)
                        }
                        HStack(spacing: 6) {
                            Rectangle().fill(Color.cTextTertiary).frame(width: 20, height: 2)
                            Text(matchup.opponentTeam.name).font(.cMeta).foregroundStyle(Color.cTextSecondary)
                        }
                    }
                    .padding(.horizontal, CircleSpace.lg)
                    .padding(.top, CircleSpace.base)
                    .padding(.bottom, CircleSpace.xl)
                }
            } else {
                // No investments yet — show helpful nudge
                HStack(spacing: CircleSpace.md) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.cTextTertiary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No investments yet")
                            .font(.cBodyEmphasis).foregroundStyle(Color.cTextPrimary)
                        Text("Head to the Trade tab to invest your $\(Int(LeagueConfig.startingCapital).formatted()) and start earning.")
                            .font(.cMeta).foregroundStyle(Color.cTextSecondary)
                    }
                }
                .padding(CircleSpace.lgMinus)
                .background(Color.cBgPanel)
                .clipShape(RoundedRectangle(cornerRadius: CircleRadius.panel, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: CircleRadius.panel, style: .continuous)
                    .strokeBorder(Color.cBorderChip, lineWidth: 1))
                .padding(.horizontal, CircleSpace.lg)
                .padding(.bottom, CircleSpace.xl)
            }
        }
    }

    // Computes week-long portfolio value series from holdings × sparklines
    private func portfolioSeries(_ member: LeagueMember) -> [Double] {
        let invested = member.roster.filter {
            (member.holdings[$0.id] ?? 0) > 0 && $0.sparkline.count > 1
        }
        guard !invested.isEmpty else { return [member.portfolioValue] }
        let minCount = invested.map(\.sparkline.count).min()!
        var result = [Double](repeating: member.cash, count: minCount)
        for stock in invested {
            let shares = member.holdings[stock.id] ?? 0
            for i in 0..<minCount { result[i] += shares * stock.sparkline[i] }
        }
        return result
    }

    // MARK: - Head-to-Head

    private func headToHeadSection(_ matchup: Matchup) -> some View {
        let userRoster = matchup.userTeam.roster.sorted { $0.weeklyReturn > $1.weeklyReturn }
        let oppRoster  = matchup.opponentTeam.roster.sorted { $0.weeklyReturn > $1.weeklyReturn }
        let count      = max(userRoster.count, oppRoster.count)
        let pairs      = (0..<min(userRoster.count, oppRoster.count)).map {
            userRoster[$0].weeklyReturn - oppRoster[$0].weeklyReturn
        }
        let userWins = pairs.filter { $0 > 0.001 }.count
        let ties     = pairs.filter { abs($0) <= 0.001 }.count

        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("HEAD TO HEAD").font(.cBodyEmphasis).foregroundStyle(Color.cTextPrimary)
                    Text("Ranked best to worst performer")
                        .font(.cMeta).foregroundStyle(Color.cTextSecondary)
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

            if count == 0 {
                Text("No stocks drafted yet")
                    .font(.cBody)
                    .foregroundStyle(Color.cTextTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, CircleSpace.xl)
            } else {
                ForEach(0..<count, id: \.self) { i in
                    let user = i < userRoster.count ? userRoster[i] : nil
                    let opp  = i < oppRoster.count  ? oppRoster[i]  : nil
                    h2hRow(rank: i + 1, userStock: user, oppStock: opp)
                    if i < count - 1 { CircleDivider().padding(.horizontal, CircleSpace.lg) }
                }
            }
        }
        .padding(.bottom, CircleSpace.md)
    }

    private func h2hRow(rank: Int, userStock: Stock?, oppStock: Stock?) -> some View {
        let userRet  = userStock?.weeklyReturn ?? 0
        let oppRet   = oppStock?.weeklyReturn ?? 0
        let diff     = userRet - oppRet
        let userWins = diff > 0.001
        let tied     = abs(diff) <= 0.001

        return HStack(spacing: 0) {
            HStack(spacing: CircleSpace.base) {
                TickerTile(symbol: userStock?.id ?? "—",
                           tone: userRet >= 0 ? .green : .red, size: .md)
                VStack(alignment: .leading, spacing: 2) {
                    Text(userStock?.id ?? "—").font(.cBodyEmphasis).foregroundStyle(Color.cTextPrimary)
                    Text(String(format: "%@%.1f%%", userRet >= 0 ? "+" : "", userRet * 100))
                        .font(.cMeta).foregroundStyle(userRet >= 0 ? Color.cAccent : Color.cLoss).monospacedDigit()
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
                TickerTile(symbol: oppStock?.id ?? "—",
                           tone: oppRet >= 0 ? (userWins ? .neutral : .green) : .red, size: .md)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, CircleSpace.lg)
        .padding(.vertical, CircleSpace.md)
    }

    // MARK: - All Matchups This Week

    private var allMatchupsSection: some View {
        let matchups = appState.league.weeklyMatchups

        return VStack(alignment: .leading, spacing: 0) {
            SectionHeader(
                title: "Week \(appState.league.currentWeek) Matchups",
                subtitle: "All league pairings"
            )
            CircleDivider()

            if matchups.isEmpty {
                Text("Add more players to generate matchups")
                    .font(.cBody)
                    .foregroundStyle(Color.cTextTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, CircleSpace.xl)
            } else {
                ForEach(Array(matchups.enumerated()), id: \.element.id) { idx, m in
                    matchupRow(m)
                    if idx < matchups.count - 1 { CircleDivider() }
                }
            }
        }
    }

    private func matchupRow(_ matchup: Matchup) -> some View {
        let userVal  = matchup.userScore
        let oppVal   = matchup.opponentScore
        let leadingTeam = userVal >= oppVal ? matchup.userTeam : matchup.opponentTeam
        let trailingTeam = userVal >= oppVal ? matchup.opponentTeam : matchup.userTeam
        let leadVal  = abs(userVal - oppVal)
        let isCurrentUser = matchup.userTeam.isCurrentUser || matchup.opponentTeam.isCurrentUser

        return HStack(spacing: CircleSpace.base) {
            // Leading team
            HStack(spacing: CircleSpace.sm) {
                CircleAvatar(
                    initials: String(leadingTeam.name.prefix(2)).uppercased(),
                    team: leadingTeam.isCurrentUser ? .selfBrand : CircleAvatar.TeamColor.forUserID(leadingTeam.id.uuidString),
                    diameter: CircleIcon.Avatar.sm
                )
                VStack(alignment: .leading, spacing: 1) {
                    Text(leadingTeam.teamName).font(.cBodyEmphasis).foregroundStyle(Color.cTextPrimary).lineLimit(1)
                    Text(String(format: "$%@", Int(max(userVal, oppVal)).formatted()))
                        .font(.cMeta).foregroundStyle(Color.cAccent).monospacedDigit()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 2) {
                Text("VS").font(.cTiny).foregroundStyle(Color.cTextTertiary)
                if leadVal > 0 {
                    Text(String(format: "+$%@", Int(leadVal).formatted()))
                        .font(.system(size: 9).monospacedDigit())
                        .foregroundStyle(Color.cAccent)
                }
            }
            .frame(width: 44)

            // Trailing team
            HStack(spacing: CircleSpace.sm) {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(trailingTeam.teamName).font(.cBodyEmphasis).foregroundStyle(Color.cTextPrimary).lineLimit(1)
                    Text(String(format: "$%@", Int(min(userVal, oppVal)).formatted()))
                        .font(.cMeta).foregroundStyle(Color.cTextSecondary).monospacedDigit()
                }
                CircleAvatar(
                    initials: String(trailingTeam.name.prefix(2)).uppercased(),
                    team: trailingTeam.isCurrentUser ? .selfBrand : CircleAvatar.TeamColor.forUserID(trailingTeam.id.uuidString),
                    diameter: CircleIcon.Avatar.sm
                )
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, CircleSpace.lg)
        .padding(.vertical, CircleSpace.base)
        .background(isCurrentUser ? Color.cBgYours : Color.clear)
        .overlay(alignment: .leading) {
            if isCurrentUser {
                Rectangle().fill(Color.cAccent).frame(width: 2)
            }
        }
    }
}

// MARK: - Chart Canvas

struct MatchupChartCanvas: View {
    let userPoints: [Double]
    let oppPoints:  [Double]

    var body: some View {
        GeometryReader { geo in
            let w   = geo.size.width
            let h   = geo.size.height
            let all = userPoints + oppPoints
            let minV = ((all.min() ?? 0) - 200).clamped(to: 0...)
            let maxV = (all.max() ?? 1) + 200
            let range = max(maxV - minV, 1)

            Canvas { ctx, size in
                func cx(_ i: Int, count: Int) -> CGFloat { CGFloat(i) / CGFloat(count - 1) * w }
                func cy(_ v: Double) -> CGFloat { h - CGFloat((v - minV) / range) * h * 0.85 - h * 0.05 }

                if userPoints.count > 1 {
                    var fill = Path()
                    fill.move(to: CGPoint(x: cx(0, count: userPoints.count), y: h))
                    for i in 0..<userPoints.count {
                        fill.addLine(to: CGPoint(x: cx(i, count: userPoints.count), y: cy(userPoints[i])))
                    }
                    fill.addLine(to: CGPoint(x: cx(userPoints.count - 1, count: userPoints.count), y: h))
                    fill.closeSubpath()
                    ctx.fill(fill, with: .linearGradient(
                        Gradient(colors: [Color.cAccent.opacity(0.35), Color.cAccent.opacity(0)]),
                        startPoint: .zero, endPoint: CGPoint(x: 0, y: h)
                    ))

                    var userLine = Path()
                    userLine.move(to: CGPoint(x: cx(0, count: userPoints.count), y: cy(userPoints[0])))
                    for i in 1..<userPoints.count {
                        userLine.addLine(to: CGPoint(x: cx(i, count: userPoints.count), y: cy(userPoints[i])))
                    }
                    ctx.stroke(userLine, with: .color(Color.cAccent),
                               style: StrokeStyle(lineWidth: CircleStroke.chartHero, lineCap: .round, lineJoin: .round))

                    let uEnd = CGPoint(x: cx(userPoints.count - 1, count: userPoints.count), y: cy(userPoints.last!))
                    ctx.fill(Path(ellipseIn: CGRect(x: uEnd.x - 6, y: uEnd.y - 6, width: 12, height: 12)),
                             with: .color(Color.cAccent))
                }

                if oppPoints.count > 1 {
                    var oppLine = Path()
                    oppLine.move(to: CGPoint(x: cx(0, count: oppPoints.count), y: cy(oppPoints[0])))
                    for i in 1..<oppPoints.count {
                        oppLine.addLine(to: CGPoint(x: cx(i, count: oppPoints.count), y: cy(oppPoints[i])))
                    }
                    ctx.stroke(oppLine, with: .color(Color.cTextTertiary.opacity(0.6)),
                               style: StrokeStyle(lineWidth: CircleStroke.chart, lineCap: .round, lineJoin: .round))

                    let oEnd = CGPoint(x: cx(oppPoints.count - 1, count: oppPoints.count), y: cy(oppPoints.last!))
                    ctx.fill(Path(ellipseIn: CGRect(x: oEnd.x - 5, y: oEnd.y - 5, width: 10, height: 10)),
                             with: .color(Color.cTextTertiary.opacity(0.6)))
                }
            }
        }
    }
}

private extension Comparable {
    func clamped(to range: PartialRangeFrom<Self>) -> Self { max(self, range.lowerBound) }
}

#Preview {
    MatchupView()
        .environmentObject(AppState.preview)
        .preferredColorScheme(.dark)
}
