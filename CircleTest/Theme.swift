import SwiftUI

/// Legacy semantic aliases — kept for backward compat while views migrate.
/// Prefer `Color.cAccent`, `Color.cLoss`, etc. from CircleDesignSystem.
enum Theme {
    // Background layers
    static let background    = Color.cBg
    static let surface       = Color.cBgPanel
    static let surfaceRaised = Color.cDividerSection

    // Accent
    static let green         = Color.cAccent

    // Text
    static let textPrimary   = Color.cTextPrimary
    static let textSecondary = Color.cTextSecondary

    // Semantic
    static let positive      = Color.cAccent
    static let negative      = Color.cLoss
}

extension Color {
    /// Hex string initializer — kept alongside the UInt32 version in CircleDesignSystem.
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
