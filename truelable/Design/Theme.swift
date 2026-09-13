//
//  Theme.swift
//  truelable
//
//  TrueLabel v2 design language. Dark-only, editorial, quiet: one accent,
//  three text tones, one corner radius, one motion curve. Everything that
//  looks "designed" in the app comes from these few constants.
//

import SwiftUI

enum TL {
    // MARK: Ground
    //
    // A warm charcoal ramp, not a cold one. Every premium dark interface
    // this was benchmarked against sits on warm near-black; cold grey is
    // what utility apps use.
    static let bg = Color(hex: 0x0C0B0A)
    static let surface = Color(hex: 0x171512)
    static let elevated = Color(hex: 0x221F1B)
    static let line = Color(hex: 0xEFE6D4).opacity(0.10)

    // MARK: Text
    //
    // Explicit warm neutrals rather than white at an opacity: opacity over
    // a translucent card compounds with the glass and drifts blue.
    static let fg = Color(hex: 0xF3EFE7)
    static let fg2 = Color(hex: 0xB8B1A6)
    static let fg3 = Color(hex: 0x8A837A)

    // MARK: Brand
    //
    // Bone, the colour of the nutrition label itself. It is deliberately
    // *not* on the traffic-light scale below, because the brand and the
    // verdict must never be the same colour — that was the bug in the old
    // palette, where one green meant both "TrueLabel" and "this is good for
    // you", so neither read as anything.
    static let accent = Color(hex: 0xEFE6D4)
    static let accentDim = Color(hex: 0xCFC4AD)
    static let ink = Color(hex: 0x141210)

    // MARK: Verdict
    //
    // The published Nutri-Score ramp, lifted for a dark ground. These carry
    // meaning, so they appear only on grades, statuses and meters — never
    // as chrome.
    static let good = Color(hex: 0x4FBF73)
    static let fair = Color(hex: 0xA3C63F)
    static let warn = Color(hex: 0xE9B23C)
    static let poor = Color(hex: 0xE68A3C)
    static let danger = Color(hex: 0xE05B47)

    // MARK: Data
    //
    // Three macros are three series in a chart, not three judgements, so
    // they get hues that carry no verdict of their own.
    static let info = Color(hex: 0x6FA8FF)
    static let violet = Color(hex: 0xA98BE8)

    // MARK: Premium
    //
    // Brass is the only metallic in the app and appears nowhere except
    // Plus. Scarcity is what makes it read as special.
    static let brass = Color(hex: 0xE9CE8C)
    static let brassDeep = Color(hex: 0xB8933F)
    static let plusGradient = LinearGradient(
        colors: [brass, brassDeep],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    // MARK: Paper
    //
    // The printed label. Now the brand's own material rather than an
    // exception to it — the bone above is this colour, lit.
    static let paper = Color(hex: 0xF4EFE2)
    static let paperInk = Color(hex: 0x2A2620)
    static let paperMuted = Color(hex: 0x6B6357)

    // MARK: Measure
    //
    // Four radii and one spacing scale. The app previously used eleven
    // radii and sixteen spacings, which is why nothing lined up: the eye
    // finds rhythm in repetition, and there was none to find.
    enum R {
        static let sm: CGFloat = 12   // chips, fields, small tiles
        static let md: CGFloat = 18   // rows, inner groupings
        static let lg: CGFloat = 24   // the standard card
        static let xl: CGFloat = 30   // hero cards, sheets, decks
    }

    /// Spacing is every multiple of four from 4 to 24, plus 2 for a label
    /// and its own value. Nothing else — sixteen arbitrary gaps is what the
    /// app had before, and it is why nothing lined up.
    static let gutter: CGFloat = 20

    /// Flat bone with the faintest warm fall, so a filled button reads as a
    /// pressed material rather than a coloured rectangle.
    static let accentGradient = LinearGradient(
        colors: [Color(hex: 0xF5EEDE), Color(hex: 0xE4D8C0)],
        startPoint: .top, endPoint: .bottom
    )

    static func grade(_ letter: String?) -> Color {
        switch letter?.lowercased() {
        case "a": return good
        case "b": return fair
        case "c": return warn
        case "d": return poor
        case "e": return danger
        default: return fg3
        }
    }

    static func nova(_ group: Int?) -> Color {
        switch group {
        case 1: return good
        case 2: return fair
        case 3: return warn
        case 4: return danger
        default: return fg3
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

extension Animation {
    /// The one signature curve (ease-out-expo). Every animation in the app
    /// uses this so motion reads as a single language.
    static func tl(_ duration: Double = 0.45) -> Animation {
        .timingCurve(0.16, 1, 0.3, 1, duration: duration)
    }
}

extension Font {
    /// Display type is serif (New York) — the one typographic move that
    /// makes the app read as editorial rather than a settings screen. Body
    /// and UI stay SF.
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    /// Five display steps, down from nine ad hoc sizes. A headline should be
    /// recognisable as the same headline from screen to screen.
    static let displayXL = display(40)      // the one line that opens the app
    static let displayL = display(32)       // page headline
    static let displayM = display(26)       // sheet and card title
    static let displayS = display(20)       // row and deck title
    static let sectionTitle = display(17, weight: .semibold)
}

extension View {
    /// Text and icons cut into the surface: a dark groove above each glyph
    /// and a lit lip below it. Applied once per card subtree — nesting it
    /// doubles the effect and reads as a blur.
    func engraved(_ strength: Double = 1) -> some View {
        compositingGroup()
            .shadow(color: .black.opacity(0.55 * strength), radius: 1, y: -0.5)
            .shadow(color: .white.opacity(0.16 * strength), radius: 0, y: 1)
    }

    /// Every surface in the app. The level carries radius, padding and
    /// depth together, so a screen reads as a hierarchy instead of a stack
    /// of identical panes. `fill` tints the glass rather than hiding what is
    /// behind it.
    func card(_ level: CardLevel = .raised, fill: Color = TL.surface) -> some View {
        modifier(GlassCard(level: level, tint: fill))
    }

    /// The ground every screen stands on: a flat base, then the static
    /// mesh the glass surfaces refract.
    /// Figures line up column to column, which is most of what makes a
    /// nutrition table look printed rather than typed.
    func numeric() -> some View {
        monospacedDigit().kerning(0.2)
    }

    /// A single entrance: content rises and settles the first time a screen
    /// shows it. Deliberately not tied to scroll position — scroll-linked
    /// motion is what made this app feel like it was being dragged. Do not
    /// use inside `List` or `LazyVStack`, where rows recycle and it would
    /// re-fire.
    func appear(_ order: Int = 0) -> some View {
        modifier(Appear(order: order))
    }

    func screenBackground() -> some View {
        background { Backdrop() }
            .background(TL.bg.ignoresSafeArea())
    }
}

private struct Appear: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var order: Int
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 10)
            .onAppear {
                guard !reduceMotion else {
                    shown = true
                    return
                }
                withAnimation(.tl(0.5).delay(Double(order) * 0.05)) { shown = true }
            }
    }
}

/// How close to the reader a surface sits. One `.hero` per screen, `.raised`
/// for the substance, `.flat` for rows and inner groupings — without this
/// every card sat at the same depth and the page read as one flat sheet.
enum CardLevel {
    case flat, raised, hero

    var radius: CGFloat {
        switch self {
        case .flat: TL.R.md
        case .raised: TL.R.lg
        case .hero: TL.R.xl
        }
    }

    var padding: CGFloat {
        switch self {
        case .flat: 14
        case .raised: 20
        case .hero: 22
        }
    }

    var tintStrength: Double {
        switch self {
        case .flat: 0.32
        case .raised: 0.45
        case .hero: 0.52
        }
    }

    var edge: Double {
        switch self {
        case .flat: 0.14
        case .raised: 0.24
        case .hero: 0.34
        }
    }

    var shadow: (radius: CGFloat, y: CGFloat, opacity: Double) {
        switch self {
        case .flat: (0, 0, 0)
        case .raised: (14, 8, 0.28)
        case .hero: (26, 14, 0.42)
        }
    }
}

/// ponytail: one glass layer per card, no GlassEffectContainer. Group them
/// in a container if a screen ever shows enough cards at once to drop frames.
private struct GlassCard: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var level: CardLevel
    var tint: Color

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: level.radius, style: .continuous)
        let drop = level.shadow
        let inner = content
            .engraved()
            .padding(level.padding)
            .frame(maxWidth: .infinity, alignment: .leading)

        if reduceTransparency {
            inner
                .background(tint, in: shape)
                .overlay(shape.strokeBorder(TL.line))
        } else {
            inner
                .glassEffect(.regular.tint(tint.opacity(level.tintStrength)), in: shape)
                .overlay {
                    shape.strokeBorder(
                        LinearGradient(colors: [TL.accent.opacity(level.edge), TL.accent.opacity(0.04)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1
                    )
                    .allowsHitTesting(false)
                }
                .shadow(color: .black.opacity(drop.opacity), radius: drop.radius, y: drop.y)
        }
    }
}

// MARK: - Formatting

extension Double {
    /// "12.5" / "12" — trims a pointless ".0".
    var compact: String {
        formatted(.number.precision(.fractionLength(0...1)))
    }
}

extension String {
    var nilIfBlank: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}
