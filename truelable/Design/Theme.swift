import SwiftUI
import UIKit

private func tone(_ light: UInt32, _ dark: UInt32) -> Color {
    Color(uiColor: UIColor { traits in
        UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
    })
}

private func tone(light: UInt32, lightAlpha: Double, dark: UInt32, darkAlpha: Double) -> Color {
    Color(uiColor: UIColor { traits in
        let dark_ = traits.userInterfaceStyle == .dark
        return UIColor(Color(hex: dark_ ? dark : light))
            .withAlphaComponent(dark_ ? darkAlpha : lightAlpha)
    })
}

enum TL {

    static let bg = tone(0xF3F2EF, 0x08080A)
    static let surface = tone(0xFFFFFF, 0x121216)
    static let elevated = tone(0xFFFFFF, 0x1A1A20)

    static let fg = tone(0x16161A, 0xF5F4F1)
    static let fg2 = tone(0x5C5B58, 0xA3A2A0)
    static let fg3 = tone(0x8A8985, 0x6E6D6B)

    static let line = tone(light: 0x000000, lightAlpha: 0.10, dark: 0xFFFFFF, darkAlpha: 0.09)

    static let shadow = tone(light: 0x000000, lightAlpha: 0.10, dark: 0x000000, darkAlpha: 0.58)

    static let track = tone(light: 0x000000, lightAlpha: 0.08, dark: 0xFFFFFF, darkAlpha: 0.08)

    static let accent = tone(0x16161A, 0xEFE6D4)
    static let accentDim = tone(0x5C5B58, 0xC9C1B2)

    static let ink = tone(0xFFFFFF, 0x08080A)

    static let accentGradient = LinearGradient(
        colors: [accent, accent], startPoint: .top, endPoint: .bottom
    )

    static let good = tone(0x1E9E5A, 0x3DD68C)
    static let fair = tone(0x6FA32E, 0x9BD84F)
    static let warn = tone(0xD79A16, 0xF5C043)
    static let poor = tone(0xD1722A, 0xF2953F)
    static let danger = tone(0xD14036, 0xEE5D52)

    static let info = tone(0x2F5FE0, 0x6E9BFF)
    static let violet = tone(0x6B4FCC, 0x9B85F0)

    static let brass = tone(0xB08A2E, 0xD9B45B)
    static let brassDeep = tone(0x8A6A1C, 0xA8842A)
    static let plusGradient = LinearGradient(
        colors: [brass, brassDeep], startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static let paper = tone(0xFFFFFF, 0xFFFFFF)
    static let paperInk = tone(0x16161A, 0x16161A)
    static let paperMuted = tone(0x6E6759, 0x6E6759)

    enum R {
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 22
        static let xl: CGFloat = 28
        static let sheet: CGFloat = 30
    }

    static let gutter: CGFloat = 20

    static let border: CGFloat = 1
    static let borderHero: CGFloat = 1

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
        case .flat: 16
        case .raised: 18
        case .hero: 20
        }
    }

    var lift: (radius: CGFloat, y: CGFloat) {
        switch self {
        case .flat: (0, 0)
        case .raised: (24, 12)
        case .hero: (34, 18)
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

    static func tl(_ duration: Double = 0.45) -> Animation {
        .timingCurve(0.16, 1, 0.3, 1, duration: duration)
    }
}

extension Font {

    static func display(_ size: CGFloat, weight: Font.Weight = .black) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static let displayXL = display(40)
    static let displayL = display(32)
    static let displayM = display(25)
    static let displayS = display(19)
    static let sectionTitle = display(17, weight: .bold)
}

struct PlateBackground: View {
    var fill: Color
    var radius: CGFloat = TL.R.lg
    var lift: (radius: CGFloat, y: CGFloat) = (0, 0)

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(fill)
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(TL.line, lineWidth: TL.border)
            }
            .shadow(color: lift.radius > 0 ? TL.shadow : .clear,
                    radius: lift.radius, y: lift.y)
            .allowsHitTesting(false)
    }
}

extension View {

    func engraved(_ strength: Double = 1) -> some View {
        self
    }

    func card(_ level: CardLevel = .raised, fill: Color = TL.surface) -> some View {
        modifier(Plate(level: level, fill: fill))
    }

    func plate(_ fill: Color = TL.surface, radius: CGFloat = TL.R.md, lifted: Bool = false) -> some View {
        background {
            PlateBackground(fill: fill, radius: radius, lift: lifted ? (18, 8) : (0, 0))
        }
    }

    func blockShadow(_ step: CGFloat = 4) -> some View {
        shadow(color: TL.shadow, radius: 18, y: 8)
    }

    func numeric() -> some View {
        monospacedDigit().kerning(0.2)
    }

    func appear(_ order: Int = 0) -> some View {
        modifier(Appear(order: order))
    }

    func screenBackground() -> some View {
        background { Backdrop() }
            .background(TL.bg.ignoresSafeArea())
    }
}

private struct Plate: ViewModifier {
    var level: CardLevel
    var fill: Color

    func body(content: Content) -> some View {
        content
            .padding(level.padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                PlateBackground(fill: fill, radius: level.radius, lift: level.lift)
            }
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

extension Double {

    var compact: String {
        formatted(.number.precision(.fractionLength(0...1)))
    }
}

extension String {
    var nilIfBlank: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}
