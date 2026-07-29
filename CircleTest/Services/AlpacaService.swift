import Foundation

/// Calls the `market-data` Supabase Edge Function, which holds Alpaca keys server-side.
/// The auth token from the user's Supabase session is forwarded so the function can
/// verify the caller is a signed-in app user.
struct AlpacaService {
    private static let functionURL = "https://zoiwopnvwvrcxdkrgadx.supabase.co/functions/v1/market-data"

    // MARK: - Response types

    struct Trade: Decodable { let p: Double }

    struct Bar: Decodable {
        let o, h, l, c: Double
        let t: String?
    }

    /// Every field is optional on purpose. Alpaca omits them per symbol — outside
    /// market hours `latestTrade` is frequently absent — and the whole
    /// `[String: Snapshot]` map is decoded in one call, so declaring them
    /// required made a single incomplete symbol throw for the entire batch. That
    /// left every stock sitting on its `draftPool()` placeholder price.
    struct Snapshot: Decodable {
        let latestTrade: Trade?
        let dailyBar: Bar?
        let prevDailyBar: Bar?

        /// Most recent usable price: last trade, else today's close, else the
        /// previous session's close.
        var price: Double? {
            [latestTrade?.p, dailyBar?.c, prevDailyBar?.c]
                .compactMap { $0 }
                .first { $0 > 0 }
        }

        /// Baseline for percent-change figures, in order of preference: previous
        /// session's close, then today's open, then the latest trade. Only
        /// positive values qualify, so callers never divide by zero — and never
        /// fall back to a hardcoded placeholder price.
        var returnBaseline: Double? {
            [prevDailyBar?.c, dailyBar?.o, latestTrade?.p]
                .compactMap { $0 }
                .first { $0 > 0 }
        }
    }

    private struct BarsResponse: Decodable {
        let bars: [String: [Bar]]
    }

    // MARK: - API calls

    static func snapshots(symbols: [String], authToken: String) async throws -> [String: Snapshot] {
        var comps = URLComponents(string: functionURL)!
        comps.queryItems = [
            URLQueryItem(name: "type",    value: "snapshots"),
            URLQueryItem(name: "symbols", value: symbols.joined(separator: ",")),
        ]
        let data = try await fetch(url: comps.url!, authToken: authToken)
        return try JSONDecoder().decode([String: Snapshot].self, from: data)
    }

    /// Fetches OHLC bars at an arbitrary Alpaca timeframe ("1Min", "5Min",
    /// "1Day", "1Week"…). The edge function allow-lists the timeframe value.
    static func bars(symbols: [String], timeframe: String, limit: Int, authToken: String) async throws -> [String: [Bar]] {
        var comps = URLComponents(string: functionURL)!
        comps.queryItems = [
            URLQueryItem(name: "type",      value: "bars"),
            URLQueryItem(name: "symbols",   value: symbols.joined(separator: ",")),
            URLQueryItem(name: "timeframe", value: timeframe),
            URLQueryItem(name: "limit",     value: "\(limit)"),
        ]
        let data = try await fetch(url: comps.url!, authToken: authToken)
        return try JSONDecoder().decode(BarsResponse.self, from: data).bars
    }

    static func dailyBars(symbols: [String], limit: Int = 7, authToken: String) async throws -> [String: [Bar]] {
        try await bars(symbols: symbols, timeframe: "1Day", limit: limit, authToken: authToken)
    }

    static func intradayBars(symbols: [String], timeframe: String = "1Min", limit: Int = 30, authToken: String) async throws -> [String: [Bar]] {
        try await bars(symbols: symbols, timeframe: timeframe, limit: limit, authToken: authToken)
    }

    private static func fetch(url: URL, authToken: String) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            // The edge function puts the upstream reason in the body; carry it into
            // the error so callers can log something more useful than a status code.
            let body = String(decoding: data.prefix(300), as: UTF8.self)
            throw URLError(.badServerResponse, userInfo: [
                NSLocalizedDescriptionKey: "HTTP \(http.statusCode)\(body.isEmpty ? "" : ": \(body)")"
            ])
        }
        return data
    }
}
