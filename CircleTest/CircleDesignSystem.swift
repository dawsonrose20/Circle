// ============================================================================
//  CircleDesignSystem.swift
// ----------------------------------------------------------------------------
//  The complete design system for Circle — a fantasy stock-drafting app.
//
//  HOW TO USE
//    1. Drop this file into your Xcode project (any target).
//    2. Use tokens. Never raw values.
//         ✅  Color.cAccent       Font.cHero     CircleSpace.lg
//         ❌  Color(hex: "#1de783")    .font(.system(size: 56))    20
//    3. Use components. Don't re-derive layouts.
//         ✅  TickerTile(symbol: "PLTR")
//         ❌  ZStack { … manual chip … }
//    4. As the app grows, split each MARK section into its own file
//       (Color+Circle.swift, Font+Circle.swift, etc.). For now everything
//       lives here so the system is auditable in one place.
//
//  PRINCIPLES
//    - Cards are the exception, not the rule. Hierarchy comes from
//      typography and 0.5px dividers, not bordered boxes. Tinted surfaces
//      are reserved for genuinely distinct meaning ("yours", "live").
//    - Numbers are tabular. Always. Money, %, ranks, timers — they line up
//      vertically when stacked. SF Pro: .monospacedDigit(). Space Grotesk
//      hero/title tokens: .tabularDigits().
//    - Color is semantic.
//          green   = your gains, your team, "yours" surfaces, primary CTA
//          red     = losses, live/urgent events, destructive actions
//          gold    = prizes, MVP, top rank
//          gray    = neutral, opponent, secondary info
//      One accent per surface. If green is everywhere, green stops meaning
//      anything. The hero is allowed to dominate; the chrome should not.
//    - Hairlines, not borders. Section breaks are 0.5px in a barely-lighter
//      gray. Heavy borders read as web design, not native iOS.
//    - Tap targets are 44pt minimum. Visual size can be smaller, but the
//      hit area must be ≥44pt per Apple HIG.
//
//  NAMING
//    All public design tokens are prefixed `c` (color, font) or live in
//    the `CircleSpace`, `CircleRadius`, `CircleDuration`, `CircleStroke`
//    namespaces. Components are unprefixed since they're our types
//    (TickerTile, RosterRow, EyebrowLabel) — no collision risk except
//    `Avatar`, which we name `CircleAvatar` because Avatar is too generic.
//
//  FONT STRATEGY
//    Hero and title tokens (cHero, cHeroMobile, cTitle, cTitleStat,
//    cTitleSub) use Space Grotesk — a geometric sans serif with
//    distinctive flat-sided digits, giving the app's numeric displays
//    a sharp, modern brand voice that fits the draft/finance aesthetic.
//
//    All body, label, and chrome text uses SF Pro (system) for native
//    iOS readability, accessibility, and dynamic type support.
//
//    Tabular figures:
//      - SF Pro numerics use .monospacedDigit()
//      - Space Grotesk numerics use .tabularDigits() (OpenType tnum)
//    Always apply one or the other to any numeric Text.
//
//  ASSUMPTIONS
//    - Dark mode only. The mockups are dark, the brand is dark, the
//      finance vibe is dark. Light mode would be a separate effort.
//    - iOS 16+. We rely on `.monospacedDigit()`, `Grid`, etc.
// ============================================================================

import SwiftUI
import UIKit

// MARK: ───────────────────────────────────────────────────────────────────
// MARK: 0. HAPTICS
// MARK: ───────────────────────────────────────────────────────────────────

enum Haptics {
    static func tap()     { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func select()  { UISelectionFeedbackGenerator().selectionChanged() }
    static func confirm() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func draft()   { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func error()   { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}

// MARK: ───────────────────────────────────────────────────────────────────
// MARK: 0b. ANIMATED NUMBER
// MARK: ───────────────────────────────────────────────────────────────────
//
//  Counts up from 0 to its target on first appearance and transitions
//  smoothly on subsequent changes. Always monospaced so digits don't jitter.
//

struct AnimatedNumber: View {
    let value: Double
    var format: (Double) -> String = { String(format: "%.2f", $0) }
    var duration: Double = 0.8
    var color: Color = .cTextPrimary
    var font: Font = .cBodyEmphasis
    /// Set true when using a Space Grotesk token (cHero, cHeroMobile,
    /// cTitle, cTitleStat, cTitleSub). Those fonts ignore .monospacedDigit();
    /// use .tabularDigits() instead via the OpenType tnum feature.
    var customFontTabular: Bool = false

    @State private var displayed: Double = 0

    var body: some View {
        Text(format(displayed))
            .font(font)
            .foregroundStyle(color)
            .modifier(TabularDigitsModifier(useCustom: customFontTabular))
            .contentTransition(.numericText(value: displayed))
            .onAppear {
                withAnimation(.easeOut(duration: duration)) { displayed = value }
            }
            .onChange(of: value) { _, newVal in
                withAnimation(.easeOut(duration: duration)) { displayed = newVal }
            }
    }
}

// MARK: - Tabular digits

/// Applies the correct tabular-digit treatment depending on whether the
/// font is a Space Grotesk custom font (OpenType tnum) or SF Pro (monospacedDigit).
private struct TabularDigitsModifier: ViewModifier {
    let useCustom: Bool
    func body(content: Content) -> some View {
        if useCustom {
            content.tabularDigits()
        } else {
            content.monospacedDigit()
        }
    }
}

// MARK: - Space Grotesk tabular digit fonts
//
// Pre-built Font values with the OpenType `tnum` (monospaced numbers) feature
// enabled via UIFontDescriptor. Call .font(.cHeroTabular) etc. instead of
// .font(.cHero).tabularDigits() - this approach applies the feature at the
// UIFont level before SwiftUI wraps it, which is the only reliable path on iOS 16+.

enum SpaceGroteskTabular {
    static func font(named name: String, size: CGFloat) -> Font {
        guard let base = UIFont(name: name, size: size) else {
            return .system(size: size, weight: .medium)
        }
        let descriptor = base.fontDescriptor.addingAttributes([
            .featureSettings: [
                [
                    UIFontDescriptor.FeatureKey.type: kNumberSpacingType,
                    UIFontDescriptor.FeatureKey.selector: kMonospacedNumbersSelector
                ]
            ]
        ])
        return Font(UIFont(descriptor: descriptor, size: size))
    }
}

extension View {
    /// Apply to any numeric Text using Space Grotesk tokens
    /// (cHero, cHeroMobile, cTitle, cTitleStat, cTitleSub).
    /// Enables the OpenType `tnum` feature so digits align in stacked lists.
    /// For system-font numerics, use .monospacedDigit() instead.
    func tabularDigits() -> some View {
        // .monospacedDigit() is a no-op on custom fonts in SwiftUI.
        // The actual tabular treatment is baked into the font tokens themselves
        // via SpaceGroteskTabular.font() above. This modifier is a no-op
        // kept as a semantic marker and for the TabularDigitsModifier path.
        self
    }
}

// MARK: ───────────────────────────────────────────────────────────────────
// MARK: 0c. FLICKER ON CHANGE
// MARK: ───────────────────────────────────────────────────────────────────
//
//  Briefly highlights a number in green/red when its value changes,
//  then fades back to the default color.
//

struct FlickerModifier: ViewModifier {
    let value: Double
    let positiveColor: Color
    let negativeColor: Color
    let defaultColor: Color

    @State private var flickerColor: Color? = nil

    func body(content: Content) -> some View {
        content
            .foregroundStyle(flickerColor ?? defaultColor)
            .onChange(of: value) { old, new in
                let highlight = new >= old ? positiveColor : negativeColor
                withAnimation(.easeIn(duration: 0.05)) { flickerColor = highlight }
                withAnimation(.easeOut(duration: 0.5).delay(0.1)) { flickerColor = nil }
            }
    }
}

extension View {
    /// Briefly flashes green on increase, red on decrease, then fades to default.
    func flickerOnChange(of value: Double,
                         positive: Color = .cAccent,
                         negative: Color = .cLoss,
                         default defaultColor: Color = .cTextPrimary) -> some View {
        modifier(FlickerModifier(value: value,
                                 positiveColor: positive,
                                 negativeColor: negative,
                                 defaultColor: defaultColor))
    }
}

// MARK: ───────────────────────────────────────────────────────────────────
// MARK: 0d. PRESSABLE BUTTON STYLE
// MARK: ───────────────────────────────────────────────────────────────────
//
//  Spring-scale + opacity dip on press. Applied to every tappable row,
//  tile, and list item that uses .plain button style.
//

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: ───────────────────────────────────────────────────────────────────
// MARK: 0e. CONFETTI
// MARK: ───────────────────────────────────────────────────────────────────
//
//  Gravity-fall confetti for big moments: draft pick, matchup win, rank up.
//  Usage:  Confetti.fire()    — triggers one burst from the top of the screen
//
//  Attach ConfettiOverlay() to the root ZStack or window level.

struct ConfettiPiece: Identifiable {
    let id = UUID()
    let x: CGFloat          // 0..1 normalized start x
    let color: Color
    let width: CGFloat
    let height: CGFloat
    let rotation: Double    // initial rotation degrees
    let rotationSpeed: Double
    let delay: Double       // stagger
    let duration: Double
}

/// Observable store so any view can call `Confetti.fire()`
@MainActor
@Observable
final class ConfettiStore {
    static let shared = ConfettiStore()
    var pieces: [ConfettiPiece] = []
    var active = false

    func fire() {
        let palette: [Color] = [.cAccent, .cGold, Color.white, Color(hex: 0xa8f0c6)]
        pieces = (0..<72).map { i in
            ConfettiPiece(
                x: CGFloat.random(in: 0...1),
                color: palette[i % palette.count],
                width: CGFloat.random(in: 6...11),
                height: CGFloat.random(in: 10...18),
                rotation: Double.random(in: 0...360),
                rotationSpeed: Double.random(in: 120...480),
                delay: Double.random(in: 0...0.4),
                duration: Double.random(in: 2.0...3.0)
            )
        }
        active = true
        // Auto-clear after longest piece lands
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.6) { [weak self] in
            self?.pieces = []
            self?.active = false
        }
    }
}

enum Confetti {
    @MainActor static func fire() { ConfettiStore.shared.fire() }
}

struct ConfettiOverlay: View {
    private var store: ConfettiStore { ConfettiStore.shared }

    var body: some View {
        if store.active {
            GeometryReader { geo in
                let h = geo.size.height
                ZStack {
                    ForEach(store.pieces) { piece in
                        ConfettiPieceView(piece: piece, screenHeight: h)
                    }
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }
}

private struct ConfettiPieceView: View {
    let piece: ConfettiPiece
    let screenHeight: CGFloat

    @State private var fallen = false
    @State private var opacity: Double = 1

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            Rectangle()
                .fill(piece.color)
                .frame(width: piece.width, height: piece.height)
                .rotationEffect(.degrees(fallen ? piece.rotation + piece.rotationSpeed : piece.rotation))
                .offset(
                    x: piece.x * w - piece.width / 2,
                    y: fallen ? screenHeight + 40 : -20
                )
                .opacity(opacity)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + piece.delay) {
                        withAnimation(.easeIn(duration: piece.duration)) {
                            fallen = true
                        }
                        // Fade out in last 0.6s
                        DispatchQueue.main.asyncAfter(deadline: .now() + piece.duration - 0.6) {
                            withAnimation(.easeOut(duration: 0.6)) {
                                opacity = 0
                            }
                        }
                    }
                }
        }
    }
}

// MARK: ───────────────────────────────────────────────────────────────────
// MARK: 1. COLOR TOKENS
// MARK: ───────────────────────────────────────────────────────────────────
//
//  All colors in the app live here. Every hex value used in any mockup is
//  represented. If you need a color that isn't in this file, add it here
//  first — never inline a hex literal in a view.
//
//  GROUPS
//    bg/*        Surface backgrounds, ranked from darkest (bg) to lightest
//                  panel.
//    text/*      Text colors, ranked by hierarchy.
//    accent/*    Brand green and its tints.
//    semantic    Red (loss/live), gold (prize/MVP).
//    teamColor/* Eight rotating user-identity colors. Each player in a
//                  league gets a deterministic team color from this set.
//    sector/*    Stock sector tints (tech, finance, etc.) for ticker tiles.
//    border/*    Hairline divider colors.
//

extension Color {

    // ── Backgrounds ────────────────────────────────────────────────────
    /// The app's base background. Almost-black. Use for the page itself.
    static let cBg              = Color(hex: 0x0B0D0C)
    /// One step lighter than bg. Use for subtly elevated panels (live trades
    /// section, leaderboard footers) that aren't tinted by meaning.
    static let cBgPanel         = Color(hex: 0x0F1110)
    /// "Yours" surface. The green-tinted background that signals "this is
    /// you" or "this is your data." Used for: your row in standings, your
    /// position summary, the draft countdown band, the active stock detail.
    static let cBgYours         = Color(hex: 0x0F1A13)
    /// "Loss" surface. The red-tinted background. Used for: ticker tiles
    /// of stocks down on the day, sell-action button background.
    static let cBgLoss          = Color(hex: 0x1A0E0C)

    // ── Text ───────────────────────────────────────────────────────────
    /// Primary text. Off-white, never pure white (pure white burns on dark
    /// backgrounds). Use for: stock names, primary numbers, titles.
    static let cTextPrimary     = Color(hex: 0xE8EBE8)
    /// Secondary text. Use for: meta info, labels, sublabels, "today",
    /// "this week", muted opponent data.
    static let cTextSecondary   = Color(hex: 0x6C7571)
    /// Tertiary text. Use sparingly, for: very-de-emphasized metadata,
    /// pagination dots, separator characters in price labels ($12,847.[32]).
    static let cTextTertiary    = Color(hex: 0x4A524D)
    /// Quaternary, almost invisible. For: chart axis labels, the most
    /// background-of-background text in the design.
    static let cTextQuaternary  = Color(hex: 0x3A3D3A)
    /// "Inverse" text — for use ON the green CTA background. Near-black.
    static let cTextOnAccent    = Color(hex: 0x0B0D0C)
    /// Text used inside the green CTA when it needs a darker variant
    /// (e.g. small label inside the green Draft countdown card).
    static let cTextOnAccentDim = Color(hex: 0x0B3D22)

    // ── Accent (Brand Green) ───────────────────────────────────────────
    /// The brand green. The single most-used accent. CTAs, gains, "you",
    /// the logo, anything that signals "good thing happening to you."
    static let cAccent          = Color(hex: 0x1DE783)
    /// A muted variant of accent. Use for trends in opponent rows or as
    /// secondary accents that should read as green-family but quieter.
    static let cAccentMuted     = Color(hex: 0x6AD19C)
    /// Tinted bg for ticker tiles of green-trending stocks.
    static let cAccentTileBg    = Color(hex: 0x1A2E21)
    /// 25% opacity overlay of accent — used as a subtle border on
    /// "yours" surfaces.
    static let cAccentBorder25  = Color(hex: 0x1DE783, opacity: 0.25)
    /// 40% opacity overlay of accent — slightly stronger border, used on
    /// the active stock detail section and the user's avatar.
    static let cAccentBorder40  = Color(hex: 0x1DE783, opacity: 0.40)

    // ── Loss / Live (Red) ──────────────────────────────────────────────
    /// The single red. Used for: stock losses, live event dots
    /// ("LIVE · MNF", "Live trades"), sell action label, urgent timers
    /// at <1min, destructive confirmations.
    static let cLoss            = Color(hex: 0xFF5A4D)
    /// A softer red used for losses on stat tables — less aggressive
    /// than `cLoss` so it doesn't dominate when many stocks are down.
    static let cLossSoft        = Color(hex: 0xFF7A6D)
    /// Tile bg for red-trending tickers.
    static let cLossTileBg      = Color(hex: 0x2E1A1A)
    /// 40% opacity overlay of loss — used on the Sell button border.
    static let cLossBorder40    = Color(hex: 0xFF5A4D, opacity: 0.40)

    // ── Gold (Prize / MVP / Champion) ──────────────────────────────────
    /// Gold. Reserved for: prize amounts, MVP badge, season-champion rank,
    /// "STAR" tags, the gold "1" crown badge on top traders. Never used
    /// for general accents — must remain meaningful.
    static let cGold            = Color(hex: 0xF5C043)
    /// Tile bg for gold-tagged elements (MVP, top rank, prize callout).
    static let cGoldTileBg      = Color(hex: 0x2E2208)
    /// Used as a darker text-on-gold for the small "1" crown badge.
    static let cGoldOnGold      = Color(hex: 0x2E2208)

    // ── Hot (Orange / Trending) ────────────────────────────────────────
    /// "Hot stock" orange. Used for the flame icon and HOT tag, and for
    /// sleeper-tier tickers in the draft. Distinct from gold (which is
    /// for prestige) — orange is for momentum.
    static let cHot             = Color(hex: 0xFF8A3D)
    static let cHotTileBg       = Color(hex: 0x2E140A)

    // ── Borders / Dividers ─────────────────────────────────────────────
    /// 0.5px hairline used between tight rows (roster rows, trade feed
    /// rows, standings rows). Barely visible — that's the point.
    static let cDividerRow      = Color(hex: 0x141614)
    /// 0.5px hairline used between sections (between Standings and Live
    /// Trades, between header and content). One step more visible.
    static let cDividerSection  = Color(hex: 0x1A1D1B)
    /// Border for outlined chips, bordered icon buttons, "Search players"
    /// chrome, and the 0.5px outline of pill chips that aren't selected.
    static let cBorderChip      = Color(hex: 0x1F2320)
    /// Background of inactive pill chips (sort options, time ranges).
    static let cChipInactive    = Color(hex: 0x1A1D1B)

    // ── Team Identity Palette ──────────────────────────────────────────
    //  Each user/avatar in a league gets a deterministic color from this
    //  rotation. The color is used for: their avatar bg, their avatar
    //  text, accent details on their rows. These are intentionally
    //  desaturated so they read as "team colors" rather than "shouting
    //  brand colors."
    //
    //  When mapping: hash the user ID, modulo 8, pick from this list.
    //  Stick to it — once a user's color is assigned, never change it.

    static let cTeamGreen       = Color(hex: 0x6AD19C)  // bg: 0x1A2820
    static let cTeamPink        = Color(hex: 0xD85A7E)  // bg: 0x2E1A24
    static let cTeamYellow      = Color(hex: 0xC5B543)  // bg: 0x2A2A1A
    static let cTeamBlue        = Color(hex: 0x4DA8E8)  // bg: 0x1A2028
    static let cTeamOrange      = Color(hex: 0xC08A4A)  // bg: 0x282018
    static let cTeamLime        = Color(hex: 0x8FBF7A)  // bg: 0x1E2A1E
    static let cTeamPurple      = Color(hex: 0xB47AE8)  // bg: 0x2A1A2E
    /// User's own color is always the brand green — they are anchor.
    static let cTeamSelf        = cAccent              // bg: 0x13281D

    /// Muted text-on-loss — used for opponent's gain in head-to-head
    /// comparison rows where their stock is up but they're losing the
    /// matchup overall.
    static let cTextOpponent    = Color(hex: 0x8A8F8A)

    // ── Sparkline Colors ───────────────────────────────────────────────
    /// Sparklines use cAccent for up, cLoss for down. No gradient on the
    /// stroke itself; gradients are applied to the area-fill only.
    static let cSparkUpStroke   = cAccent
    static let cSparkDownStroke = cLoss
    /// 25% top-opacity → 0% bottom-opacity gradient under cAccent strokes.
    /// Use `LinearGradient(gradient: cSparkUpFill, startPoint: .top, endPoint: .bottom)`
    static let cSparkUpFillTop  = Color(hex: 0x1DE783, opacity: 0.25)
    static let cSparkUpFillBot  = Color(hex: 0x1DE783, opacity: 0.00)
}

// MARK: Hex helper
//  Local hex initializer so this file is self-contained. If your project
//  already has one, delete this and use yours.
extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >>  8) & 0xFF) / 255
        let b = Double( hex        & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}


// MARK: ───────────────────────────────────────────────────────────────────
// MARK: 2. TYPOGRAPHY
// MARK: ───────────────────────────────────────────────────────────────────
//
//  Six tiers, plus a few specialized variants. Don't add new sizes — pick
//  from this list. If a screen needs a size that isn't here, the design
//  is wrong, not the system.
//
//  WEIGHTS
//    The system uses .regular and .medium almost exclusively. .semibold
//    appears occasionally for the very tightest emphasis, never .bold —
//    bold reads as too aggressive against the dark palette.
//
//  LETTER SPACING (tracking)
//    Hero numbers       — tight (-2 to -3 pt)
//    Title numbers      — slightly tight (-0.5 to -1 pt)
//    Body / labels      — default (0)
//    Eyebrow / brand    — tracked (1.5 to 3 pt)
//
//  TABULAR FIGURES
//    SF Pro numerics: use .monospacedDigit()
//    Space Grotesk numerics (cHero/cTitle tiers): use .tabularDigits()
//    Non-negotiable — misaligned numbers in a finance app look amateurish.
//

extension Font {

    // ── Heroes — Space Grotesk ─────────────────────────────────────────
    // PostScript name: SpaceGrotesk-Light_Medium (variable font, wght axis).
    // Tabular digits (tnum) are baked in via SpaceGroteskTabular.font().
    // Use .tabularDigits() on any numeric Text as a semantic marker —
    // the actual spacing fix is in the Font itself.
    /// The single biggest type in the app — only used for the absolute
    /// hero number on a screen (portfolio value on Home, draft timer,
    /// stock detail price). Never used twice on the same screen.
    /// 76pt Space Grotesk Medium, -3 tracking. Add `.tabularDigits()`.
    static let cHero            = SpaceGroteskTabular.font(named: "SpaceGrotesk-Light_Medium", size: 76)
    /// Mobile hero — slightly smaller for phone widths. 62pt.
    /// Use this for the team-value display on the Circle mobile home.
    static let cHeroMobile      = SpaceGroteskTabular.font(named: "SpaceGrotesk-Light_Medium", size: 62)

    // ── Titles — Space Grotesk ─────────────────────────────────────────
    /// Section heroes — 40pt. For "Pick 3" contest title, "The Degens"
    /// league name, "Round 4" draft label.
    static let cTitle           = SpaceGroteskTabular.font(named: "SpaceGrotesk-Light_Medium", size: 40)
    /// Subhero numbers — 28pt. For matchup head-to-head numbers, a
    /// secondary big stat. Tighter than body, looser than hero.
    static let cTitleStat       = SpaceGroteskTabular.font(named: "SpaceGrotesk-Light_Medium", size: 28)
    /// Sub-stat — 24pt. Used in the "best vs best" matchup rows where
    /// each side gets a 24pt percentage.
    static let cTitleSub        = SpaceGroteskTabular.font(named: "SpaceGrotesk-Light_Medium", size: 24)
    /// Stock detail name / "round" label / section heroes — 18pt.
    static let cTitleSection    = Font.system(size: 18, weight: .medium, design: .default)

    // ── Body ───────────────────────────────────────────────────────────
    /// Default text size. 14pt. Stock names in roster, body copy, list
    /// item primary text, button labels.
    static let cBody            = Font.system(size: 14, weight: .regular, design: .default)
    /// Body emphasized — 14pt medium. For the "primary" item in a row
    /// (stock name) when a less-important item (subtitle) sits below.
    static let cBodyEmphasis    = Font.system(size: 14, weight: .medium, design: .default)
    /// Smaller body — 13pt. Used in trade feed rows, dense data lists.
    static let cBodyDense       = Font.system(size: 13, weight: .regular, design: .default)

    // ── Captions / Meta ────────────────────────────────────────────────
    /// Sublabel under a primary list item. 11pt. "1st pick · cost $3,208",
    /// "QB · BUF", row meta info.
    static let cMeta            = Font.system(size: 11, weight: .regular, design: .default)
    /// Smallest readable text. 10pt. Eyebrow labels, axis labels, time
    /// stamps in dense lists, percentage labels in chart legend.
    static let cTiny            = Font.system(size: 10, weight: .regular, design: .default)
    /// Even smaller, for tag chips and badges only. 9pt medium.
    static let cTag             = Font.system(size: 9, weight: .medium, design: .default)

    // ── Specialty ──────────────────────────────────────────────────────
    /// The brand wordmark "CIRCLE" sits at this size with 3pt tracking.
    static let cBrand           = Font.system(size: 16, weight: .medium, design: .default)
    /// Eyebrow labels — uppercase, tracked. "TODAY'S PLAY · LIVE",
    /// "LIVE · MNF", "MATCHUP NOTES". Apply .tracking(2) at use site.
    static let cEyebrow         = Font.system(size: 11, weight: .medium, design: .default)
    /// Smaller eyebrow used inside a section. 10pt with .tracking(2).
    static let cEyebrowSmall    = Font.system(size: 10, weight: .medium, design: .default)
}

// MARK: Tracking helpers
//  Common tracking values. Apply via `.tracking(CircleTracking.eyebrow)`.
enum CircleTracking {
    /// Hero numbers — visually tighter, around -3.
    static let hero:        CGFloat = -3
    /// Title numbers — -1.
    static let title:       CGFloat = -1
    /// Subtitle / sub-stat — -0.5.
    static let subtitle:    CGFloat = -0.5
    /// Default body — 0.
    static let body:        CGFloat = 0
    /// Eyebrow labels — opens up the letterforms.
    static let eyebrow:     CGFloat = 2
    /// Small eyebrow / tag.
    static let eyebrowTight: CGFloat = 1.5
    /// Brand wordmark — most open of all.
    static let brand:       CGFloat = 3
    /// Tag chips ("MVP", "STAR", "HOT") — 0.5 to 0.8.
    static let tag:         CGFloat = 0.5
}


// MARK: ───────────────────────────────────────────────────────────────────
// MARK: 3. SPACING
// MARK: ───────────────────────────────────────────────────────────────────
//
//  Base unit is 4. Every padding, margin, and gap should be a multiple of
//  this scale. Don't invent in-between values — if the design needs 17pt
//  of padding, you're rounding wrong.
//
//  USAGE
//    .padding(.horizontal, CircleSpace.lg)
//    HStack(spacing: CircleSpace.sm) { … }
//
//  COMMON PATTERNS
//    Section vertical gap   → xxl (32) or xxxl (44 for hero sections)
//    Page horizontal pad    → lg (20)
//    Row vertical pad       → md (14)
//    Inline icon-text gap   → xs (6) to sm (8)
//

enum CircleSpace {
    /// 2 — for hairline-tight spacing, unusual.
    static let xxxs:    CGFloat = 2
    /// 4 — within tightly-coupled inline elements (the dot in "8 wins · 2 losses").
    static let xxs:     CGFloat = 4
    /// 6 — between an icon and its text label.
    static let xs:      CGFloat = 6
    /// 8 — between a tag chip and the text it follows.
    static let sm:      CGFloat = 8
    /// 10 — between meta items in a row (price and percentage).
    static let smPlus:  CGFloat = 10
    /// 12 — standard inline gap, between an avatar and the name beside it.
    static let base:    CGFloat = 12
    /// 14 — vertical padding inside a list row.
    static let md:      CGFloat = 14
    /// 16 — between two adjacent buttons in a button row.
    static let mdPlus:  CGFloat = 16
    /// 18 — vertical padding inside a tinted section (Live trades section).
    static let lgMinus: CGFloat = 18
    /// 20 — page horizontal padding. The default safe-area inset for content.
    static let lg:      CGFloat = 20
    /// 22 — header padding.
    static let lgPlus:  CGFloat = 22
    /// 28 — large section padding (between major content blocks).
    static let xl:      CGFloat = 28
    /// 32 — top of a new major section (e.g. between the matchup and the
    /// "head to head" list).
    static let xxl:     CGFloat = 32
    /// 44 — hero-section vertical breathing room.
    static let xxxl:    CGFloat = 44
}


// MARK: ───────────────────────────────────────────────────────────────────
// MARK: 4. RADII
// MARK: ───────────────────────────────────────────────────────────────────
//
//  Three sizes, plus full-pill. Don't invent in-between radii.
//

enum CircleRadius {
    /// 3 — tag chips ("MVP", "STAR", "HOT", "T1").
    static let chip:        CGFloat = 3
    /// 4 — small pills, inline badges with text.
    static let pillSmall:   CGFloat = 4
    /// 6 — buttons in chrome (segmented controls, time-range pickers, the
    /// gain pill "↑ +$1,284").
    static let pill:        CGFloat = 6
    /// 7 — small icon backgrounds (28-32pt squares).
    static let iconTight:   CGFloat = 7
    /// 9 — medium icon backgrounds, contest type icons (36pt squares).
    static let icon:        CGFloat = 9
    /// 10 — primary CTA buttons.
    static let button:      CGFloat = 10
    /// 11 — ticker tiles (42pt squares). Slightly more rounded than icons,
    /// signals "object" not "icon."
    static let tile:        CGFloat = 11
    /// 12 — small panel rounding (head-to-head matchup boxes).
    static let panel:       CGFloat = 12
    /// 16 — medium panel rounding (Head-to-head matchup container,
    /// trade-card panel).
    static let panelLarge:  CGFloat = 16
    /// 18 — hero panels / contest cards.
    static let panelHero:   CGFloat = 18
    /// 22 — the green "you're on the clock" draft hero.
    static let panelXL:     CGFloat = 22
    /// 999 — pills (full circular pills, status dots wrappers).
    static let pillFull:    CGFloat = 999
    /// 38 — phone screen rounding (used in our mockup frame).
    static let device:      CGFloat = 38
}


// MARK: ───────────────────────────────────────────────────────────────────
// MARK: 5. STROKE WIDTHS
// MARK: ───────────────────────────────────────────────────────────────────
//
//  Hairlines are 0.5pt and survive Retina rendering as a single pixel
//  on @2x and 1.5px on @3x. They look correct on every device.
//

enum CircleStroke {
    /// 0.5pt — hairline divider between rows / sections.
    static let hairline:    CGFloat = 0.5
    /// 1pt — subtle border on outlined buttons.
    static let thin:        CGFloat = 1
    /// 1.5pt — sparkline strokes.
    static let spark:       CGFloat = 1.5
    /// 2pt — main chart stroke (portfolio value graph), pulse circles.
    static let chart:       CGFloat = 2
    /// 2.5pt — emphasized chart strokes (matchup chart, hero sparkline).
    static let chartHero:   CGFloat = 2.5
}


// MARK: ───────────────────────────────────────────────────────────────────
// MARK: 6. ANIMATION DURATIONS / EASINGS
// MARK: ───────────────────────────────────────────────────────────────────

enum CircleDuration {
    /// 150ms — micro-interactions (button press, tap feedback, color flips).
    static let micro:   Double = 0.15
    /// 250ms — default UI transitions (chip selection, expansion).
    static let base:    Double = 0.25
    /// 400ms — page-level transitions, section expand/collapse.
    static let page:    Double = 0.40
    /// 1.2s — pulse cycle for live dots ("● LIVE", "you're on the clock").
    static let pulse:   Double = 1.20
}

enum CircleEase {
    /// Default ease — smooth in and out.
    static let standard = Animation.easeInOut(duration: CircleDuration.base)
    /// Snappy — for taps and presses.
    static let snappy   = Animation.spring(response: 0.30, dampingFraction: 0.75)
    /// Soft spring — for sheet transitions and reveals.
    static let soft     = Animation.spring(response: 0.45, dampingFraction: 0.85)
    /// The infinite pulse used by live indicators.
    static let pulse    = Animation.easeInOut(duration: CircleDuration.pulse).repeatForever(autoreverses: true)
}


// MARK: ───────────────────────────────────────────────────────────────────
// MARK: 7. ICON SIZES
// MARK: ───────────────────────────────────────────────────────────────────
//
//  Icons should match one of these sizes. The "tap target" column is the
//  full hit area; the "visual" column is the rendered size.
//
//      USE                         VISUAL    TAP TARGET
//      Inline-with-text icon       12-14     —
//      Eyebrow icon (★, ⚠)         13-14     —
//      Section header icon         14-16     —
//      Avatar 24                   24        44 (parent)
//      Avatar 28                   28        44 (parent)
//      Avatar 30 (standings)       30        44 (parent)
//      Avatar 32 (rich row)        32        44 (parent)
//      Avatar 38 (header)          38        44 (parent)
//      Ticker tile (sm)            28        —
//      Ticker tile (md, default)   42        44+
//      Ticker tile (lg, hero)      54        —
//      Tab bar icon                20        49 (system)
//      Top nav icon button         14 inside 38 ring  44+
//

enum CircleIcon {
    static let inline:      CGFloat = 12
    static let eyebrow:     CGFloat = 14
    static let section:     CGFloat = 16
    static let topNav:      CGFloat = 14   // inside a 38pt ring
    static let topNavRing:  CGFloat = 38
    static let tabBar:      CGFloat = 20

    enum Avatar {
        static let xs:      CGFloat = 24
        static let sm:      CGFloat = 28
        static let md:      CGFloat = 30
        static let lg:      CGFloat = 32
        static let xl:      CGFloat = 38
        static let hero:    CGFloat = 44
    }

    enum Tile {
        static let sm:      CGFloat = 28   // matchup pair tiles
        static let md:      CGFloat = 42   // default roster / list tile
        static let lg:      CGFloat = 54   // stock detail hero
    }

    enum Pulse {
        /// Diameter of the inner solid pulse dot on live indicators.
        static let dot:     CGFloat = 7
        /// Diameter of the inner solid for "online" status dots.
        static let dotSm:   CGFloat = 5
    }
}


// MARK: ───────────────────────────────────────────────────────────────────
// MARK: 8. COMPONENT — Eyebrow Label
// MARK: ───────────────────────────────────────────────────────────────────
//
//  The small uppercase tracked label that sits above section content.
//  "TODAY'S PLAY · LIVE", "MATCHUP NOTES", "Round-by-round".
//
//  Variants:
//    .standard   — secondary text, no leading dot
//    .live       — red text with pulsing red dot before
//    .yours      — accent (green) text with optional dot
//
//  Use:
//      EyebrowLabel("Today's play · live", style: .live)
//      EyebrowLabel("Standings")
//

struct EyebrowLabel: View {
    enum Style { case standard, live, yours }

    let text: String

    init(_ text: String, style: Style = .standard) {
        self.text = text
        self.style = style
    }
    var style: Style = .standard

    var body: some View {
        HStack(spacing: CircleSpace.sm) {
            if style != .standard {
                LiveDot(color: dotColor, pulses: style == .live)
            }
            Text(text.uppercased())
                .font(.cEyebrow)
                .tracking(CircleTracking.eyebrow)
                .foregroundStyle(textColor)
        }
    }

    private var textColor: Color {
        switch style {
        case .standard: return .cTextSecondary
        case .live:     return .cLoss
        case .yours:    return .cAccent
        }
    }
    private var dotColor: Color {
        switch style {
        case .standard: return .clear
        case .live:     return .cLoss
        case .yours:    return .cAccent
        }
    }
}

/// Small solid dot, optionally infinitely pulsing. Used by EyebrowLabel
/// and standalone for live status indicators.
struct LiveDot: View {
    var color: Color
    var pulses: Bool = false
    var size: CGFloat = CircleIcon.Pulse.dot

    @State private var on = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .opacity(pulses ? (on ? 1.0 : 0.55) : 1.0)
            .shadow(color: pulses ? color.opacity(0.6) : .clear, radius: pulses ? 4 : 0)
            .onAppear { if pulses { withAnimation(CircleEase.pulse) { on = true } } }
    }
}


// MARK: ───────────────────────────────────────────────────────────────────
// MARK: 9. COMPONENT — Hairline Divider
// MARK: ───────────────────────────────────────────────────────────────────
//
//  The 0.5pt line used between rows and sections. Native `Divider` is
//  too thick and uses the wrong color. Always use this.
//

struct CircleDivider: View {
    enum Weight { case row, section }
    var weight: Weight = .row

    var body: some View {
        Rectangle()
            .fill(weight == .row ? Color.cDividerRow : Color.cDividerSection)
            .frame(height: CircleStroke.hairline)
    }
}


// MARK: ───────────────────────────────────────────────────────────────────
// MARK: 10. COMPONENT — Ticker Tile
// MARK: ───────────────────────────────────────────────────────────────────
//
//  The small rounded square containing a ticker symbol. Used in roster
//  rows, draft list, search results, trade feed, stock detail header.
//
//  Color logic:
//    - Up day or default     → green tile (cAccentTileBg + cAccent text)
//    - Down day              → red tile  (cLossTileBg + cLoss text)
//    - Sleeper / hot stock   → orange    (cHotTileBg + cHot text)
//    - Top-rank / champion   → gold      (cGoldTileBg + cGold text)
//
//  Sizes: .sm (28), .md (42, default), .lg (54)
//

struct TickerTile: View {
    enum Tone { case green, red, orange, gold, neutral }
    enum Size  { case sm, md, lg }

    let symbol: String
    var tone: Tone = .green
    var size: Size = .md

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(bgColor)
            .frame(width: dimension, height: dimension)
            .overlay {
                Text(symbol)
                    .font(.system(size: fontSize, weight: .medium))
                    .tracking(symbol.count >= 4 ? 0 : 0.5)
                    .foregroundStyle(textColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 2)
            }
    }

    private var dimension: CGFloat {
        switch size {
        case .sm: return CircleIcon.Tile.sm
        case .md: return CircleIcon.Tile.md
        case .lg: return CircleIcon.Tile.lg
        }
    }
    private var cornerRadius: CGFloat { CircleRadius.tile }
    private var fontSize: CGFloat {
        switch size {
        case .sm: return 9
        case .md: return 10
        case .lg: return 12
        }
    }
    private var bgColor: Color {
        switch tone {
        case .green:    return .cAccentTileBg
        case .red:      return .cLossTileBg
        case .orange:   return .cHotTileBg
        case .gold:     return .cGoldTileBg
        case .neutral:  return .cChipInactive
        }
    }
    private var textColor: Color {
        switch tone {
        case .green:    return .cAccent
        case .red:      return .cLoss
        case .orange:   return .cHot
        case .gold:     return .cGold
        case .neutral:  return .cTextSecondary
        }
    }
}


// MARK: ───────────────────────────────────────────────────────────────────
// MARK: 11. COMPONENT — Avatar
// MARK: ───────────────────────────────────────────────────────────────────
//
//  Round avatar showing user initials, in their team color. The user's
//  own avatar uses the brand green and gets a 0.5pt cAccentBorder40 ring.
//
//  Optional `crown` overlays a small gold "1" badge for top-rank users.
//

struct CircleAvatar: View {
    enum TeamColor: CaseIterable {
        case selfBrand, green, pink, yellow, blue, orange, lime, purple

        /// Deterministic mapping from a user identifier to a team color.
        static func forUserID(_ id: String) -> TeamColor {
            // Hash modulo 7 (excluding selfBrand which is reserved for current user).
            let pool: [TeamColor] = [.green, .pink, .yellow, .blue, .orange, .lime, .purple]
            let hash = id.unicodeScalars.reduce(0) { ($0 &+ Int($1.value)) }
            return pool[abs(hash) % pool.count]
        }

        var foreground: Color {
            switch self {
            case .selfBrand: return .cAccent
            case .green:     return .cTeamGreen
            case .pink:      return .cTeamPink
            case .yellow:    return .cTeamYellow
            case .blue:      return .cTeamBlue
            case .orange:    return .cTeamOrange
            case .lime:      return .cTeamLime
            case .purple:    return .cTeamPurple
            }
        }
        var background: Color {
            switch self {
            case .selfBrand: return Color(hex: 0x13281D)
            case .green:     return Color(hex: 0x1A2820)
            case .pink:      return Color(hex: 0x2E1A24)
            case .yellow:    return Color(hex: 0x2A2A1A)
            case .blue:      return Color(hex: 0x1A2028)
            case .orange:    return Color(hex: 0x282018)
            case .lime:      return Color(hex: 0x1E2A1E)
            case .purple:    return Color(hex: 0x2A1A2E)
            }
        }
    }

    let initials: String
    var team: TeamColor = .selfBrand
    var diameter: CGFloat = CircleIcon.Avatar.lg
    var crown: Bool = false

    var body: some View {
        Circle()
            .fill(team.background)
            .frame(width: diameter, height: diameter)
            .overlay(
                Circle()
                    .strokeBorder(
                        team == .selfBrand ? Color.cAccentBorder40 : Color.clear,
                        lineWidth: CircleStroke.hairline
                    )
            )
            .overlay {
                Text(initials)
                    .font(.system(size: fontSize, weight: .medium))
                    .foregroundStyle(team.foreground)
            }
            .overlay(alignment: .bottomTrailing) {
                if crown {
                    ZStack {
                        Circle()
                            .fill(Color.cGold)
                            .frame(width: 16, height: 16)
                        Text("1")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.cGoldOnGold)
                    }
                    .offset(x: 2, y: 2)
                }
            }
    }

    private var fontSize: CGFloat {
        switch diameter {
        case ..<28:  return 9
        case ..<32:  return 10
        case ..<38:  return 11
        default:     return 12
        }
    }
}


// MARK: ───────────────────────────────────────────────────────────────────
// MARK: 12. COMPONENT — Tag Chip
// MARK: ───────────────────────────────────────────────────────────────────
//
//  The small inline pills like "★ STAR", "MVP", "HOT", "T1", "LIVE",
//  "MATCHUP", "SELECTED". Bg color and text color are paired with meaning.
//
//  Variants:
//    .star    — gold (★ STAR / MVP / T1)
//    .hot     — orange (🔥 HOT)
//    .live    — red (● LIVE) — with optional pulsing dot
//    .yours   — green (SELECTED / IN ROSTER)
//    .neutral — gray (MATCHUP, default)
//

struct TagChip: View {
    enum Style { case star, hot, live, yours, neutral }

    let text: String
    var style: Style = .neutral
    var leadingIcon: String? = nil   // Optional SF Symbol
    var pulses: Bool = false

    init(_ text: String, style: Style = .neutral, leadingIcon: String? = nil, pulses: Bool = false) {
        self.text = text
        self.style = style
        self.leadingIcon = leadingIcon
        self.pulses = pulses
    }

    var body: some View {
        HStack(spacing: CircleSpace.xxs) {
            if pulses {
                LiveDot(color: textColor, pulses: true, size: 5)
            } else if let icon = leadingIcon {
                Image(systemName: icon)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(textColor)
            }
            Text(text.uppercased())
                .font(.cTag)
                .tracking(CircleTracking.tag)
                .foregroundStyle(textColor)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 1.5)
        .background(bgColor)
        .clipShape(RoundedRectangle(cornerRadius: CircleRadius.chip, style: .continuous))
    }

    private var bgColor: Color {
        switch style {
        case .star:    return .cGoldTileBg
        case .hot:     return .cHotTileBg
        case .live:    return .cLossTileBg
        case .yours:   return Color(hex: 0x13281D)
        case .neutral: return .cDividerSection
        }
    }
    private var textColor: Color {
        switch style {
        case .star:    return .cGold
        case .hot:     return .cHot
        case .live:    return .cLoss
        case .yours:   return .cAccent
        case .neutral: return .cTextPrimary
        }
    }
}


// MARK: ───────────────────────────────────────────────────────────────────
// MARK: 13. COMPONENT — Buttons
// MARK: ───────────────────────────────────────────────────────────────────
//
//  Three flavors:
//    PrimaryButton    — green outline + translucent green fill. Fills solid on press.
//    SecondaryButton  — neutral outline + translucent neutral fill. Fills solid on press.
//    DestructiveButton — red outline + translucent red fill. Fills solid on press.
//
//  All use square corners (radius 4), 1pt solid border, and a custom
//  ButtonStyle to drive the pressed state fill.
//

/// Square-outlined button style used by all Circle buttons.
/// The style wraps the label in a rounded rect background that transitions
/// from translucent (idle) to near-solid (pressed), with a solid 1pt border.
private struct CircleFillButtonStyle: ButtonStyle {
    let color: Color
    let borderColor: Color
    let idleFill: Double
    let pressedFill: Double

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: cButtonRadius, style: .continuous)
        configuration.label
            .background(
                shape.fill(color.opacity(configuration.isPressed ? pressedFill : idleFill))
            )
            .overlay(shape.strokeBorder(borderColor, lineWidth: cButtonBorder))
            .clipShape(shape)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

private let cButtonRadius: CGFloat = 4
private let cButtonBorder: CGFloat = 1

struct PrimaryButton: View {
    let title: String
    var trailingArrow: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: { Haptics.confirm(); action() }) {
            HStack(spacing: CircleSpace.xs) {
                Text(title).font(.cBodyEmphasis)
                if trailingArrow {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .medium))
                }
            }
            .foregroundStyle(Color.cAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, CircleSpace.base)
        }
        .buttonStyle(CircleFillButtonStyle(color: .cAccent, borderColor: .cAccent,
                                           idleFill: 0.15, pressedFill: 0.80))
    }
}

struct SecondaryButton: View {
    let title: String
    var icon: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: { Haptics.tap(); action() }) {
            HStack(spacing: CircleSpace.xs) {
                if let icon { Image(systemName: icon).font(.system(size: 13, weight: .medium)) }
                Text(title).font(.cBodyEmphasis)
            }
            .foregroundStyle(Color.cTextPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, CircleSpace.base)
        }
        .buttonStyle(CircleFillButtonStyle(color: .cTextPrimary, borderColor: .cBorderChip,
                                           idleFill: 0.08, pressedFill: 0.22))
    }
}

struct DestructiveButton: View {
    let title: String
    var trailing: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: { Haptics.error(); action() }) {
            HStack(spacing: CircleSpace.sm) {
                Text(title).font(.cBodyEmphasis).foregroundStyle(Color.cLoss)
                if let trailing {
                    Text(trailing)
                        .font(.cBodyDense)
                        .monospacedDigit()
                        .foregroundStyle(Color.cTextSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, CircleSpace.md)
        }
        .buttonStyle(CircleFillButtonStyle(color: .cLoss, borderColor: .cLoss,
                                           idleFill: 0.12, pressedFill: 0.75))
    }
}


// MARK: ───────────────────────────────────────────────────────────────────
// MARK: 14. COMPONENT — Delta Pill
// MARK: ───────────────────────────────────────────────────────────────────
//
//  The "↑ +$1,284.00" or "−$87.00" pill that sits next to a percentage.
//  Color and arrow flip based on sign. Always tabular.
//

struct DeltaPill: View {
    let value: Double           // Signed. Positive = gain, negative = loss.
    let formatted: String       // Pre-formatted string ("$1,284.00", "8.4%").
    var compact: Bool = false   // Use smaller padding/type for inline use.

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: value >= 0 ? "arrow.up" : "arrow.down")
                .font(.system(size: compact ? 10 : 11, weight: .medium))
                .contentTransition(.symbolEffect(.replace))
            Text(formatted)
                .font(compact ? .cMeta : .cBodyDense)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .foregroundStyle(value >= 0 ? Color.cAccent : Color.cLoss)
        .padding(.horizontal, compact ? CircleSpace.sm : CircleSpace.smPlus)
        .padding(.vertical, compact ? 3 : 5)
        .background(value >= 0 ? Color(hex: 0x0F2A1A) : Color(hex: 0x2E1A1A))
        .clipShape(RoundedRectangle(cornerRadius: CircleRadius.pill, style: .continuous))
    }
}


// MARK: ───────────────────────────────────────────────────────────────────
// MARK: 15. COMPONENT — Sparkline
// MARK: ───────────────────────────────────────────────────────────────────
//
//  Small inline price chart. Auto-colors based on first vs last value.
//  Renders a stroked line, optionally with a gradient area-fill below.
//

struct Sparkline: View {
    let values: [Double]
    var size: CGSize = CGSize(width: 64, height: 26)
    var filled: Bool = false        // Add the gradient area fill.
    var strokeWidth: CGFloat = CircleStroke.spark

    private var isUp: Bool {
        guard let first = values.first, let last = values.last else { return true }
        return last >= first
    }

    var body: some View {
        Canvas { ctx, sz in
            guard values.count > 1,
                  let minV = values.min(),
                  let maxV = values.max() else { return }
            let range = max(0.0001, maxV - minV)
            let xStep = sz.width / CGFloat(values.count - 1)
            var path = Path()
            for (i, v) in values.enumerated() {
                let x = CGFloat(i) * xStep
                let y = sz.height - CGFloat((v - minV) / range) * sz.height
                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                else      { path.addLine(to: CGPoint(x: x, y: y)) }
            }

            if filled {
                var fillPath = path
                fillPath.addLine(to: CGPoint(x: sz.width,  y: sz.height))
                fillPath.addLine(to: CGPoint(x: 0,         y: sz.height))
                fillPath.closeSubpath()
                ctx.fill(
                    fillPath,
                    with: .linearGradient(
                        Gradient(colors: [
                            isUp ? Color.cSparkUpFillTop : Color(hex: 0xFF5A4D, opacity: 0.25),
                            isUp ? Color.cSparkUpFillBot : Color(hex: 0xFF5A4D, opacity: 0.00)
                        ]),
                        startPoint: CGPoint(x: 0, y: 0),
                        endPoint: CGPoint(x: 0, y: sz.height)
                    )
                )
            }

            ctx.stroke(
                path,
                with: .color(isUp ? Color.cSparkUpStroke : Color.cSparkDownStroke),
                style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)
            )
        }
        .frame(width: size.width, height: size.height)
    }
}


// MARK: ───────────────────────────────────────────────────────────────────
// MARK: 16. COMPONENT — Roster Row
// MARK: ───────────────────────────────────────────────────────────────────
//
//  The four-column row pattern used throughout the app (roster, draft,
//  trending, head-to-head). Layout: tile / name+meta / sparkline / number.
//
//  The selected variant adds a left edge bar and tint, matching how the
//  Home tab indicates "currently expanded position."
//

struct RosterRow: View {
    let symbol: String
    let companyName: String
    let metaText: String
    let price: String
    let deltaPercent: Double
    let deltaPercentText: String
    var sparklineData: [Double] = []
    var tags: [TagChip] = []
    var selected: Bool = false
    var tone: TickerTile.Tone = .green

    var body: some View {
        HStack(spacing: CircleSpace.base) {
            TickerTile(symbol: symbol, tone: tone)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: CircleSpace.xs) {
                    Text(companyName)
                        .font(.cBodyEmphasis)
                        .foregroundStyle(selected ? Color.cAccent : Color.cTextPrimary)
                    ForEach(0..<tags.count, id: \.self) { tags[$0] }
                }
                Text(metaText)
                    .font(.cMeta)
                    .foregroundStyle(selected ? Color.cAccent : Color.cTextSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !sparklineData.isEmpty {
                Sparkline(values: sparklineData)
            }

            VStack(alignment: .trailing, spacing: 2) {
                Text(price)
                    .font(.cBodyEmphasis)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .flickerOnChange(of: deltaPercent, default: .cTextPrimary)
                Text(deltaPercentText)
                    .font(.cMeta)
                    .monospacedDigit()
                    .foregroundStyle(deltaPercent >= 0 ? Color.cAccent : Color.cLoss)
                    .contentTransition(.numericText())
            }
        }
        .padding(.vertical, CircleSpace.md)
        .padding(.horizontal, CircleSpace.lg)
        .contentShape(Rectangle())
        .background(selected ? Color.cBgYours : .clear)
        .overlay(alignment: .leading) {
            if selected {
                Rectangle().fill(Color.cAccent).frame(width: 2)
            }
        }
    }
}


// MARK: ───────────────────────────────────────────────────────────────────
// MARK: 17. COMPONENT — Yours Section
// MARK: ───────────────────────────────────────────────────────────────────
//
//  The green-tinted background band that signals "this content is yours."
//  Used for: draft countdown, your position summary, your standings row,
//  the "you're on the clock" hero. Borders are 0.5pt cAccentBorder25
//  hairlines on top and bottom only — no left/right borders.
//

struct YoursSection<Content: View>: View {
    let content: Content
    var hasTopBorder: Bool = true
    var hasBottomBorder: Bool = true

    init(topBorder: Bool = true, bottomBorder: Bool = true,
         @ViewBuilder content: () -> Content) {
        self.hasTopBorder = topBorder
        self.hasBottomBorder = bottomBorder
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, CircleSpace.lg)
            .padding(.vertical, CircleSpace.lgMinus)
            .background(Color.cBgYours)
            .overlay(alignment: .top) {
                if hasTopBorder {
                    Rectangle().fill(Color.cAccentBorder25).frame(height: CircleStroke.hairline)
                }
            }
            .overlay(alignment: .bottom) {
                if hasBottomBorder {
                    Rectangle().fill(Color.cAccentBorder25).frame(height: CircleStroke.hairline)
                }
            }
    }
}


// MARK: ───────────────────────────────────────────────────────────────────
// MARK: 18. COMPONENT — Top Nav
// MARK: ───────────────────────────────────────────────────────────────────
//
//  The header used on every screen. Three layouts:
//    .brand      — left logo, right notification + avatar (Home only)
//    .titled     — back button, centered eyebrow + title, right action
//    .titledNoBack — no back, just centered title (League root)
//

struct CircleTopNav<Trailing: View>: View {
    let layout: Layout
    let trailing: Trailing

    enum Layout {
        case brand                          // Home: left logo, right buttons
        case titled(eyebrow: String, title: String, onBack: () -> Void)
        case titledNoBack(eyebrow: String, title: String)
    }

    init(_ layout: Layout, @ViewBuilder trailing: () -> Trailing) {
        self.layout = layout
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left
            switch layout {
            case .brand:
                BrandLockup()
            case .titled(_, _, let onBack):
                CircleNavIconButton(systemName: "chevron.left", action: onBack)
            case .titledNoBack:
                Color.clear.frame(width: CircleIcon.topNavRing, height: CircleIcon.topNavRing)
            }

            Spacer(minLength: CircleSpace.base)

            // Center
            switch layout {
            case .brand:
                EmptyView()
            case .titled(let eyebrow, let title, _),
                 .titledNoBack(let eyebrow, let title):
                VStack(spacing: 2) {
                    EyebrowLabel(eyebrow)
                    Text(title).font(.cBodyEmphasis).foregroundStyle(Color.cTextPrimary).textCase(.uppercase)
                }
            }

            Spacer(minLength: CircleSpace.base)

            // Right
            trailing
        }
        .padding(.horizontal, CircleSpace.lgMinus)
        .padding(.top, CircleSpace.lgPlus)
        .padding(.bottom, CircleSpace.sm)
    }
}

struct BrandLockup: View {
    var body: some View {
        HStack(spacing: CircleSpace.smPlus) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.cAccent)
                    .frame(width: 30, height: 30)
                Rectangle()
                    .fill(Color.cBg)
                    .frame(width: 11, height: 11)
                    .rotationEffect(.degrees(45))
                    .clipShape(RoundedRectangle(cornerRadius: 2))
            }
            Text("CIRCLE")
                .font(.cBrand)
                .tracking(CircleTracking.brand)
                .foregroundStyle(Color.cTextPrimary)
        }
    }
}

struct CircleNavIconButton: View {
    let systemName: String
    var hasBadge: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: { Haptics.tap(); action() }) {
            ZStack {
                Image(systemName: systemName)
                    .font(.system(size: CircleIcon.topNav, weight: .medium))
                    .foregroundStyle(Color.cTextPrimary)
                    .frame(width: CircleIcon.topNavRing, height: CircleIcon.topNavRing)
                if hasBadge {
                    Circle()
                        .fill(Color.cAccent)
                        .frame(width: 7, height: 7)
                        .overlay(Circle().strokeBorder(Color.cBg, lineWidth: 1.5))
                        .offset(x: 9, y: -8)
                }
            }
        }
        .buttonStyle(CircleFillButtonStyle(color: .cTextPrimary, borderColor: .cBorderChip,
                                           idleFill: 0.08, pressedFill: 0.22))
    }
}


// MARK: ───────────────────────────────────────────────────────────────────
// MARK: 18b. COMPONENT — Nav Trailing Chrome
//
//  An environment action is used so every screen gets the settings gear
//  wired up automatically without per-view changes. Provide the action once
//  at the ContentView level via .environment(\.openSettings, { … }).
//

private struct OpenSettingsKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var openSettings: () -> Void {
        get { self[OpenSettingsKey.self] }
        set { self[OpenSettingsKey.self] = newValue }
    }
}

// MARK: ───────────────────────────────────────────────────────────────────
//
//  Standardized top-nav trailing cluster used on every screen:
//    1. Starting capital label ("$10,000" with "BANKROLL" eyebrow)
//    2. Profile avatar (CircleAvatar, selfBrand, sm size)
//    3. Settings icon (gearshape)
//
//  Usage:  NavTrailingChrome(userInitials: "YO")
//

// MARK: - Draft Countdown

/// Formats the time remaining until a scheduled draft. Granularity tightens as
/// the moment approaches: days → hours → minutes → seconds.
enum DraftCountdown {
    static func text(until date: Date, from now: Date = Date()) -> String {
        let diff = Int(date.timeIntervalSince(now).rounded(.up))
        guard diff > 0 else { return "Starting now" }
        let days = diff / 86400
        let hours = (diff % 86400) / 3600
        let minutes = (diff % 3600) / 60
        let seconds = diff % 60
        if days > 0    { return "\(days)d \(hours)h away" }
        if hours > 0   { return "\(hours)h \(minutes)m away" }
        if minutes > 0 { return "\(minutes)m \(seconds)s away" }
        return "\(seconds)s away"
    }
}

// MARK: - Market Status

/// US equities regular-session status (9:30–16:00 ET, Mon–Fri).
/// Holidays are not accounted for.
enum MarketStatus {
    case open, closed

    static var current: MarketStatus {
        var cal = Calendar(identifier: .gregorian)
        guard let tz = TimeZone(identifier: "America/New_York") else { return .closed }
        cal.timeZone = tz
        let c = cal.dateComponents([.weekday, .hour, .minute], from: Date())
        guard let weekday = c.weekday, let hour = c.hour, let minute = c.minute else { return .closed }
        guard (2...6).contains(weekday) else { return .closed }   // Mon–Fri
        let minutes = hour * 60 + minute
        return (minutes >= 9 * 60 + 30 && minutes < 16 * 60) ? .open : .closed
    }

    var isOpen: Bool { self == .open }
    var label: String { isOpen ? "OPEN" : "CLOSED" }
    var color: Color { isOpen ? Color.cAccent : Color.cTextTertiary }
}

/// Compact market open/closed pill. Refreshes itself so it flips when the
/// session opens or closes without needing a manual reload.
struct MarketStatusPill: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { _ in
            let status = MarketStatus.current
            HStack(spacing: 5) {
                Circle()
                    .fill(status.color)
                    .frame(width: 6, height: 6)
                    .shadow(color: status.isOpen ? status.color.opacity(0.6) : .clear, radius: 3)
                Text(status.label)
                    .font(.cTiny)
                    .tracking(CircleTracking.eyebrowTight)
                    .foregroundStyle(status.color)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.cBgPanel)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Color.cBorderChip, lineWidth: 1))
        }
    }
}

struct NavTrailingChrome: View {
    let userInitials: String
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        HStack(spacing: CircleSpace.xs) {
            // 0. Market open/closed indicator
            MarketStatusPill()

            // 1. Starting capital label
            VStack(alignment: .trailing, spacing: 0) {
                Text("BANKROLL")
                    .font(.cTiny)
                    .tracking(CircleTracking.eyebrowTight)
                    .foregroundStyle(Color.cTextTertiary)
                Text(LeagueConfig.startingCapitalFormatted)
                    .font(.cMeta)
                    .foregroundStyle(Color.cTextSecondary)
                    .monospacedDigit()
            }

            // 2. Profile avatar
            CircleAvatar(
                initials: userInitials,
                team: .selfBrand,
                diameter: CircleIcon.Avatar.sm
            )

            // 3. Settings gear — opens SettingsView via environment action
            CircleNavIconButton(systemName: "gearshape") { openSettings() }
        }
    }
}

// MARK: ───────────────────────────────────────────────────────────────────
// MARK: 19. COMPONENT — Tab Bar
// MARK: ───────────────────────────────────────────────────────────────────
//
//  Three-tab bottom nav. Active tab is green, inactive is text-secondary.
//  Optional pulsing dot above the icon for "your turn" / "draft live"
//  states.
//

struct CircleTabBar: View {
    @Binding var selection: Tab
    var leagueIndicator: TabIndicator = .none

    enum Tab { case home, buzz, league }
    enum TabIndicator { case none, info, urgent }

    var body: some View {
        HStack(spacing: CircleSpace.xxs) {
            tabItem(.home,   label: "Home",   icon: "house.fill")
            tabItem(.buzz,   label: "Buzz",   icon: "bolt.fill")
            tabItem(.league, label: "League", icon: "person.3.fill",
                    indicator: leagueIndicator)
        }
        .padding(.horizontal, CircleSpace.mdPlus)
        .padding(.vertical, CircleSpace.md)
        .background(Color.cBg)
        .overlay(alignment: .top) {
            CircleDivider(weight: .section)
        }
    }

    @ViewBuilder
    private func tabItem(_ tab: Tab, label: String, icon: String,
                         indicator: TabIndicator = .none) -> some View {
        let active = selection == tab
        Button { Haptics.tap(); selection = tab } label: {
            VStack(spacing: 5) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: CircleIcon.tabBar, weight: .medium))
                    if indicator != .none {
                        Circle()
                            .fill(indicator == .urgent ? Color.cLoss : Color.cAccent)
                            .frame(width: 8, height: 8)
                            .offset(x: 6, y: -2)
                    }
                }
                Text(label)
                    .font(.system(size: 10, weight: active ? .medium : .regular))
            }
            .foregroundStyle(active ? Color.cAccent : Color.cTextSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, CircleSpace.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}


// MARK: ───────────────────────────────────────────────────────────────────
// MARK: 20. COMPONENT — Hero Number
// MARK: ───────────────────────────────────────────────────────────────────
//
//  The huge primary value display. Splits the cents into a dimmer color
//  ($12,847.32 — the .32 is muted). Optional eyebrow above and delta pill
//  below.
//

struct HeroNumber: View {
    let dollars: String         // "$12,847"
    var cents: String? = nil    // ".32"
    var eyebrow: String? = nil  // "Portfolio value · week 11"
    var color: Color = .cTextPrimary
    var size: Font = .cHero
    var rawValue: Double? = nil // When provided, drives flicker + count-up transition

    // Maps the known hero font tokens to their point sizes so cents can
    // use Space Grotesk at the same proportional size (~55%).
    private var centsPtSize: CGFloat {
        switch size {
        case .cHero:       return 76 * 0.55
        case .cHeroMobile: return 62 * 0.55
        case .cTitle:      return 40 * 0.55
        default:           return 34  // sensible fallback
        }
    }

    private var centsFont: Font {
        SpaceGroteskTabular.font(named: "SpaceGrotesk-Light_Medium", size: centsPtSize)
    }



    @State private var visible = false

    var body: some View {
        VStack(alignment: .leading, spacing: CircleSpace.smPlus) {
            if let eyebrow {
                EyebrowLabel(eyebrow)
            }
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(dollars)
                    .font(size)
                    .tracking(CircleTracking.hero)
                    .foregroundStyle(color)
                    .tabularDigits()
                    .contentTransition(.numericText())
                    .opacity(visible ? 1 : 0)
                    .flickerOnChange(of: rawValue ?? 0, default: color)
                    .fixedSize()
                if let cents {
                    Text(cents)
                        .font(centsFont)
                        .tracking(CircleTracking.hero)
                        .foregroundStyle(Color.cTextTertiary)
                        .tabularDigits()
                        .contentTransition(.numericText())
                        .opacity(visible ? 1 : 0)
                        .fixedSize()
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { visible = true }
        }
    }
}


// MARK: ───────────────────────────────────────────────────────────────────
// MARK: 21. COMPONENT — Pill Chip (Filter / Selectable)
// MARK: ───────────────────────────────────────────────────────────────────
//
//  The filter pills used on the draft list ("All", "Mega cap", "Growth",
//  "Sleeper"). Selected = filled white-ish background with dark text.
//  Unselected = hairline border with primary text.
//

struct PillChip: View {
    let title: String
    var selected: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: { Haptics.select(); action() }) {
            Text(title)
                .font(.system(size: 12, weight: selected ? .medium : .regular))
                .foregroundStyle(selected ? Color.cBg : Color.cTextPrimary)
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .background(selected ? Color.cTextPrimary : .clear)
                .overlay(
                    RoundedRectangle(cornerRadius: CircleRadius.pillFull, style: .continuous)
                        .strokeBorder(
                            selected ? Color.clear : Color.cBorderChip,
                            lineWidth: CircleStroke.hairline
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: CircleRadius.pillFull, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}


// MARK: ───────────────────────────────────────────────────────────────────
// MARK: 22. COMPONENT — Section Header
// MARK: ───────────────────────────────────────────────────────────────────
//
//  Standard pattern used at the top of every list section: title on the
//  left, optional sublabel below the title, optional small caption
//  ("12 live", "47 total") on the right. Followed immediately by a
//  hairline section divider.
//

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var trailing: String? = nil
    var trailingColor: Color = .cTextSecondary
    var leadingIcon: String? = nil  // SF Symbol, optional

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: CircleSpace.sm) {
                    if let leadingIcon {
                        Image(systemName: leadingIcon)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.cHot)
                    }
                    Text(title)
                        .font(.cBodyEmphasis)
                        .tracking(CircleTracking.eyebrowTight)
                        .foregroundStyle(Color.cTextPrimary)
                        .textCase(.uppercase)
                }
                if let subtitle {
                    Text(subtitle)
                        .font(.cMeta)
                        .foregroundStyle(Color.cTextSecondary)
                }
            }
            Spacer()
            if let trailing {
                Text(trailing).font(.cMeta).foregroundStyle(trailingColor)
            }
        }
        .padding(.horizontal, CircleSpace.lg)
        .padding(.top, CircleSpace.xl)
        .padding(.bottom, CircleSpace.xxs)
    }
}


// MARK: ───────────────────────────────────────────────────────────────────
// MARK: 23. PREVIEW SHOWCASE
// MARK: ───────────────────────────────────────────────────────────────────
//
//  An on-canvas reference of every component. Use this as a smoke-test
//  any time you change the system.
//

#Preview("Component Showcase") {
    ScrollView {
        VStack(alignment: .leading, spacing: CircleSpace.xl) {

            // Eyebrow Labels
            VStack(alignment: .leading, spacing: CircleSpace.sm) {
                EyebrowLabel("Portfolio value · week 11")
                EyebrowLabel("Today's play · live", style: .live)
                EyebrowLabel("Your position", style: .yours)
            }

            // Tag Chips
            HStack(spacing: CircleSpace.sm) {
                TagChip("Star", style: .star, leadingIcon: "star.fill")
                TagChip("Hot", style: .hot, leadingIcon: "flame.fill")
                TagChip("Live", style: .live, pulses: true)
                TagChip("Selected", style: .yours)
                TagChip("Matchup", style: .neutral)
            }

            // Ticker Tiles
            HStack(spacing: CircleSpace.sm) {
                TickerTile(symbol: "PLTR", tone: .green, size: .sm)
                TickerTile(symbol: "PLTR", tone: .green, size: .md)
                TickerTile(symbol: "META", tone: .red,   size: .md)
                TickerTile(symbol: "DKNG", tone: .orange, size: .md)
                TickerTile(symbol: "BRKB", tone: .gold,  size: .md)
                TickerTile(symbol: "AAPL", tone: .green, size: .lg)
            }

            // Avatars
            HStack(spacing: CircleSpace.sm) {
                CircleAvatar(initials: "MR", team: .selfBrand,  diameter: 38)
                CircleAvatar(initials: "JT", team: .pink,       diameter: 32)
                CircleAvatar(initials: "SM", team: .green,      diameter: 32)
                CircleAvatar(initials: "QQ", team: .purple,     diameter: 38, crown: true)
            }

            // Buttons
            VStack(spacing: CircleSpace.sm) {
                PrimaryButton(title: "Enter for $5") {}
                SecondaryButton(title: "Share", icon: "person.2") {}
                DestructiveButton(title: "Sell", trailing: "$620") {}
            }

            // Hero Number
            HeroNumber(
                dollars: "$12,847",
                cents: ".32",
                eyebrow: "Team value",
                color: .cAccent,
                size: .cHeroMobile
            )

            // Delta Pill
            HStack {
                DeltaPill(value:  1284, formatted: "+$1,284.00")
                DeltaPill(value:   -87, formatted: "−$87.00")
            }

            // Sparkline
            HStack(spacing: CircleSpace.lg) {
                Sparkline(values: [10, 12, 11, 14, 18, 17, 22, 24, 28], filled: true)
                Sparkline(values: [28, 26, 24, 22, 18, 16, 14, 10, 8])
            }

            // Pill Chips
            HStack(spacing: CircleSpace.xs) {
                PillChip(title: "All", selected: true)  {}
                PillChip(title: "Mega cap")              {}
                PillChip(title: "Growth")                {}
                PillChip(title: "Sleeper")               {}
            }

            // Section Header preview
            VStack(spacing: 0) {
                SectionHeader(
                    title: "Trending",
                    subtitle: "Across every league",
                    trailing: "Updated 2m ago",
                    leadingIcon: "flame.fill"
                )
                CircleDivider(weight: .row)
            }

            // Roster Row
            VStack(spacing: 0) {
                RosterRow(
                    symbol: "PLTR",
                    companyName: "Palantir",
                    metaText: "4th pick · cost $520",
                    price: "$620",
                    deltaPercent: 8.4,
                    deltaPercentText: "+8.4%",
                    sparklineData: [4, 5, 6, 8, 9, 11, 14, 16, 19],
                    tags: [TagChip("Selected", style: .yours)],
                    selected: true
                )
                CircleDivider()
                RosterRow(
                    symbol: "META",
                    companyName: "Meta",
                    metaText: "5th pick · cost $897",
                    price: "$890",
                    deltaPercent: -0.8,
                    deltaPercentText: "−0.8%",
                    sparklineData: [12, 11, 10, 11, 9, 8, 7, 6, 5],
                    tone: .red
                )
            }

            // Tab Bar
            CircleTabBar(selection: .constant(.home),
                         leagueIndicator: .urgent)
        }
        .padding(CircleSpace.lg)
    }
    .background(Color.cBg)
    .preferredColorScheme(.dark)
}
