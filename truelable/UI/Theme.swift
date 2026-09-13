//
//  Theme.swift
//  truelable
//
//  Mirrors web/packages/ui/src/styles.css exactly, so the app reads as the
//  same product as the (redesigned) website rather than a generic iOS dark
//  mode. Supersedes the ad hoc `.white.opacity(...)` grays used before this.

import SwiftUI

enum TLColor {
    // Adopted from the "TrueLabel iOS v3" Claude Design mockup — the
    // canonical accent going forward, superseding the earlier ad hoc pick.
    static let accent = Color(hex: 0x34E0A1)
    static let accentBright = Color(hex: 0x7CF2C6)
    static let warn = Color(hex: 0xF5A524)
    static let danger = Color(hex: 0xFF6B5E)
    static let proteinBlue = Color(hex: 0x6FA8FF)
    static let ink = Color(hex: 0x04261B)

    // Dark only for now — the scan flow is `.preferredColorScheme(.dark)`
    // throughout already; these exist so new screens don't reinvent grays.
    static let bg = Color(hex: 0x08090A)
    static let fg = Color(hex: 0xF2F4F3)
    static let muted = Color(hex: 0x8B8B8B)
    static let line = Color.white.opacity(0.12)
    static let surface = Color(hex: 0x121212)

    /// The "physical label" paper color — matches the website's
    /// `LabelCard` (`#f4efe2`) exactly, so the printed-label metaphor reads
    /// the same on both platforms.
    static let paper = Color(hex: 0xF4EFE2)
    static let paperInk = Color(hex: 0x2A2620)
    static let paperMuted = Color(hex: 0x6B6357)
}

extension View {
    /// Approximates the "TrueLabel iOS v3" mockup's liquid-glass card
    /// recipe (`linear-gradient(158deg, rgba(255,255,255,.12),
    /// rgba(255,255,255,.04))` + `backdrop-filter: blur(26px)
    /// saturate(180%)`) — as an OPAQUE gradient fill, not a real
    /// `.glassEffect()`/`Material`. Live backdrop-sampling over this app's
    /// own continuously-animating aurora backgrounds is the exact thing
    /// that degraded performance earlier in this project (see
    /// `ProductDetailView`'s original doc comment) — this keeps the visual
    /// weight the design calls for without reintroducing that.
    func liquidGlassCard(cornerRadius: CGFloat = 24) -> some View {
        background(TLColor.surface)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.10), Color.white.opacity(0.03)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(.white.opacity(0.16)))
        .shadow(color: .black.opacity(0.4), radius: 17, y: 14)
    }

    /// The design's primary CTA button treatment.
    func primaryCTAStyle() -> some View {
        foregroundStyle(TLColor.ink)
            .background(
                LinearGradient(colors: [Color(hex: 0x66F1BE), Color(hex: 0x21C68B)], startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: 20)
            )
            .shadow(color: TLColor.accent.opacity(0.34), radius: 17, y: 8)
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
    /// The web's one signature curve (`--ease-out-expo`,
    /// `cubic-bezier(0.16, 1, 0.3, 1)`) — used for every new animation added
    /// to match the redesigned website, so motion reads as one language.
    static func easeOutExpo(duration: Double = 0.4) -> Animation {
        .timingCurve(0.16, 1, 0.3, 1, duration: duration)
    }
}
