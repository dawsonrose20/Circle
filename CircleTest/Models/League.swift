import Foundation

// MARK: - League Config

struct LeagueConfig {
    /// Per-team starting cash. Set when a league is created; drives cash,
    /// portfolio value, and return calculations across the app.
    static var startingCapital: Double = 10_000
    static var startingCapitalFormatted: String {
        startingCapital.formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }
    static let rosterSize: Int = 7
}

// MARK: - LeagueMember

struct LeagueMember: Identifiable, Hashable {
    let id: UUID
    var name: String
    var teamName: String
    var roster: [Stock]
    var wins: Int
    var losses: Int
    var isCurrentUser: Bool
    var cash: Double = LeagueConfig.startingCapital
    var holdings: [String: Double] = [:]

    // Identity-based equality so NavigationLink stays stable while portfolio changes
    static func == (lhs: LeagueMember, rhs: LeagueMember) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    // Current market value of all invested positions.
    //
    // Positions are always counted, even before live quotes arrive. Skipping
    // un-priced stocks used to make a fresh buy look like a loss: cash went
    // down but the new position contributed nothing. `currentPrice` is the same
    // price `buy` used to size the position, so value is conserved until real
    // market data replaces it.
    var investedValue: Double {
        roster.reduce(0.0) { sum, stock in
            sum + (holdings[stock.id] ?? 0) * stock.currentPrice
        }
    }

    // Total portfolio: uninvested cash + positions at current market prices
    var portfolioValue: Double { cash + investedValue }

    // Dollar gain/loss vs starting capital
    var totalWeeklyGainLoss: Double { portfolioValue - LeagueConfig.startingCapital }

    // Percentage return vs starting capital — drives matchup scoring and leaderboards
    var totalWeeklyReturn: Double { totalWeeklyGainLoss / LeagueConfig.startingCapital }
}

// MARK: - Matchup

struct Matchup: Identifiable {
    let id: UUID
    let weekNumber: Int
    let userTeam: LeagueMember
    let opponentTeam: LeagueMember

    var userScore: Double     { userTeam.portfolioValue }
    var opponentScore: Double { opponentTeam.portfolioValue }
    var userIsWinning: Bool   { userScore >= opponentScore }
}

// MARK: - League

struct League: Identifiable {
    let id: UUID
    var name: String
    var members: [LeagueMember]
    var currentWeek: Int
    var draftComplete: Bool
    var nextDraftDate: Date? = nil
    var commissionerId: UUID = UUID()
    var weekStartDate: Date = Date()

    var inviteCode: String {
        let hex = id.uuidString.replacingOccurrences(of: "-", with: "")
        let value = Int(String(hex.prefix(4)), radix: 16) ?? 0
        return "DGN-\(1000 + value % 9000)"
    }

    var currentUser: LeagueMember? {
        members.first { $0.isCurrentUser }
    }

    // All pairings for the current week using circle-method round-robin
    var weeklyMatchups: [Matchup] {
        let n = members.count
        guard n >= 2 else { return [] }

        // Fix members[0], rotate the rest by (week - 1) positions each week
        let fixed = members[0]
        var rotating = Array(members.dropFirst())
        let shift = rotating.isEmpty ? 0 : (currentWeek - 1) % rotating.count
        if shift > 0 {
            rotating = Array(rotating.dropFirst(shift)) + Array(rotating.prefix(shift))
        }
        let lineup = [fixed] + rotating

        var result: [Matchup] = []
        let pairCount = lineup.count / 2
        for i in 0..<pairCount {
            result.append(Matchup(
                id: UUID(),
                weekNumber: currentWeek,
                userTeam: lineup[i],
                opponentTeam: lineup[lineup.count - 1 - i]
            ))
        }
        return result
    }

    // Current user's matchup, with current user always on userTeam side
    var currentMatchup: Matchup? {
        guard let m = weeklyMatchups.first(where: {
            $0.userTeam.isCurrentUser || $0.opponentTeam.isCurrentUser
        }) else { return nil }
        if m.userTeam.isCurrentUser { return m }
        return Matchup(id: m.id, weekNumber: m.weekNumber,
                       userTeam: m.opponentTeam, opponentTeam: m.userTeam)
    }

    var standings: [LeagueMember] {
        members.sorted { $0.portfolioValue > $1.portfolioValue }
    }
}
