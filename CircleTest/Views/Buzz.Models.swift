import SwiftUI

// MARK: - Contest

enum ContestKind {
    case elimination, streak, bracket, longShort
}

struct Contest: Identifiable {
    let id: String
    let title: String
    let kind: ContestKind
    let prizePool: Int?
    let entryFee: Int?
    let players: Int
    let closesAt: Date?
    let opensAt: Date?
    let isLive: Bool
    let isFeatured: Bool
    let isOpen: Bool

    var metaString: String {
        switch kind {
        case .elimination:
            let pool = prizePool.map { "$\($0) pool" } ?? "Free"
            return "\(pool) · \(players) in · closes 8pm"
        case .streak:
            let fee = entryFee == nil ? "Free entry" : "$\(entryFee!) entry"
            let prize = prizePool.map { "$\($0)" } ?? "—"
            return "\(fee) · \(players) in · 7-day streak \(prize)"
        case .bracket:
            let pool = prizePool.map { "$\($0) pool" } ?? "Free"
            let opens = opensAt.map {
                let f = DateFormatter(); f.dateFormat = "EEE ha"; return f.string(from: $0)
            } ?? "soon"
            return "\(pool) · opens \(opens) · 64 spots"
        case .longShort:
            let pool = prizePool.map { "$\($0) pool" } ?? "Free"
            return "\(pool) · \(players) in · closes market close"
        }
    }
}

// MARK: - Trending

struct TrendingTrade {
    let username: String
    let userInitials: String
    let userTeamColor: CircleAvatar.TeamColor
    let from: String
    let to: String
    let percentSinceTrade: Double
    let timeAgo: String
}

struct TopTrader {
    let username: String
    let initials: String
    let teamColor: CircleAvatar.TeamColor
    let summary: String
    let weekPercent: Double
}

struct HotStock {
    let symbol: String
    let companyName: String
    let timesDraftedThisWeek: Int
    let sparklineValues: [Double]
    let price: Double
    let percent: Double
}

// MARK: - Global Leaderboard

struct GlobalRanker: Identifiable {
    let id = UUID()
    let rank: Int
    let username: String
    let initials: String
    let teamColor: CircleAvatar.TeamColor
    let title: String
    let portfolioValue: Int
    let isSelf: Bool
}
