import Foundation

struct OHLCBar: Hashable, Codable {
    let open: Double
    let high: Double
    let low: Double
    let close: Double
}

// MARK: - Chart Range

/// Selectable window for the trading charts. Each range maps to an Alpaca
/// timeframe plus how many bars to request.
enum ChartRange: String, CaseIterable, Hashable {
    case day   = "1D"
    case week  = "1W"
    case month = "1M"
    case quarter = "3M"
    case year  = "1Y"
    case all   = "All"

    var timeframe: String {
        switch self {
        case .day:     return "5Min"
        case .week:    return "1Day"
        case .month:   return "1Day"
        case .quarter: return "1Day"
        case .year:    return "1Week"
        case .all:     return "1Week"
        }
    }

    /// Bars requested — roughly one full window at the chosen timeframe.
    var barCount: Int {
        switch self {
        case .day:     return 78     // ~6.5h regular session in 5-minute bars
        case .week:    return 5      // trading days
        case .month:   return 22
        case .quarter: return 66
        case .year:    return 52     // weekly bars
        case .all:     return 260    // ~5y of weekly bars
        }
    }
}

struct Stock: Identifiable, Hashable, Codable {
    let id: String          // ticker, e.g. "AAPL"
    let name: String
    let sector: String
    var currentPrice: Double
    var weekStartPrice: Double
    var sparkline: [Double] // 7 closing prices for mini sparklines
    var candles: [OHLCBar] = []          // daily OHLC bars
    var intradayCandles: [OHLCBar] = [] // 1-minute intraday bars for the trading chart
    var draftPickNumber: Int?
    var draftCostPrice: Double?
    var hasPriceData: Bool = false  // true only once Alpaca API provides live quotes

    var weeklyReturn: Double {
        guard weekStartPrice > 0 else { return 0 }
        return (currentPrice - weekStartPrice) / weekStartPrice
    }
    var weeklyGainLoss: Double {
        currentPrice - weekStartPrice
    }
    // Tag only applies when real price data exists
    var tag: StockTag {
        guard hasPriceData else { return .none }
        if weeklyReturn > 0.05 { return .hot }
        if weeklyReturn > 0.02 { return .star }
        return .none
    }
}

enum StockTag: String {
    case star = "⭐ STAR"
    case hot  = "🔥 HOT"
    case none = ""
}

// MARK: - Draft pool

extension Stock {
    /// Default pool of draftable stocks. Replaced by live Alpaca data once connected.
    static func draftPool() -> [Stock] {
        [
            Stock(id: "NVDA",  name: "Nvidia",             sector: "Tech",        currentPrice: 875.00, weekStartPrice: 875.00, sparkline: [875,875,875,875,875,875,875]),
            Stock(id: "AAPL",  name: "Apple",               sector: "Tech",        currentPrice: 227.50, weekStartPrice: 227.50, sparkline: [227,227,227,227,227,227,227]),
            Stock(id: "MSFT",  name: "Microsoft",           sector: "Tech",        currentPrice: 415.20, weekStartPrice: 415.20, sparkline: [415,415,415,415,415,415,415]),
            Stock(id: "TSLA",  name: "Tesla",               sector: "EV",          currentPrice: 248.00, weekStartPrice: 248.00, sparkline: [248,248,248,248,248,248,248]),
            Stock(id: "GOOGL", name: "Alphabet",            sector: "Tech",        currentPrice: 192.40, weekStartPrice: 192.40, sparkline: [192,192,192,192,192,192,192]),
            Stock(id: "META",  name: "Meta",                sector: "Tech",        currentPrice: 598.00, weekStartPrice: 598.00, sparkline: [598,598,598,598,598,598,598]),
            Stock(id: "AMZN",  name: "Amazon",              sector: "Retail/Tech", currentPrice: 220.00, weekStartPrice: 220.00, sparkline: [220,220,220,220,220,220,220]),
            Stock(id: "COIN",  name: "Coinbase",            sector: "Crypto",      currentPrice: 228.00, weekStartPrice: 228.00, sparkline: [228,228,228,228,228,228,228]),
            Stock(id: "NFLX",  name: "Netflix",             sector: "Streaming",   currentPrice: 910.00, weekStartPrice: 910.00, sparkline: [910,910,910,910,910,910,910]),
            Stock(id: "SPOT",  name: "Spotify",             sector: "Streaming",   currentPrice: 452.00, weekStartPrice: 452.00, sparkline: [452,452,452,452,452,452,452]),
            Stock(id: "PLTR",  name: "Palantir",            sector: "Tech",        currentPrice: 78.00,  weekStartPrice: 78.00,  sparkline: [78,78,78,78,78,78,78]),
            Stock(id: "AMD",   name: "AMD",                 sector: "Tech",        currentPrice: 162.00, weekStartPrice: 162.00, sparkline: [162,162,162,162,162,162,162]),
            Stock(id: "JPM",   name: "JPMorgan Chase",      sector: "Finance",     currentPrice: 241.00, weekStartPrice: 241.00, sparkline: [241,241,241,241,241,241,241]),
            Stock(id: "V",     name: "Visa",                sector: "Finance",     currentPrice: 312.00, weekStartPrice: 312.00, sparkline: [312,312,312,312,312,312,312]),
            Stock(id: "UNH",   name: "UnitedHealth",        sector: "Healthcare",  currentPrice: 572.00, weekStartPrice: 572.00, sparkline: [572,572,572,572,572,572,572]),
            Stock(id: "JNJ",   name: "Johnson & Johnson",   sector: "Healthcare",  currentPrice: 148.00, weekStartPrice: 148.00, sparkline: [148,148,148,148,148,148,148]),
            Stock(id: "XOM",   name: "ExxonMobil",          sector: "Energy",      currentPrice: 116.00, weekStartPrice: 116.00, sparkline: [116,116,116,116,116,116,116]),
            Stock(id: "WMT",   name: "Walmart",             sector: "Retail",      currentPrice: 96.00,  weekStartPrice: 96.00,  sparkline: [96,96,96,96,96,96,96]),
            Stock(id: "DIS",   name: "Disney",              sector: "Media",       currentPrice: 108.00, weekStartPrice: 108.00, sparkline: [108,108,108,108,108,108,108]),
            Stock(id: "KO",    name: "Coca-Cola",           sector: "Consumer",    currentPrice: 62.00,  weekStartPrice: 62.00,  sparkline: [62,62,62,62,62,62,62]),
        ]
    }
}
