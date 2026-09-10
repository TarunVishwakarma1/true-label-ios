//
//  Theme.swift
//  truelable
//
//  Mirrors web/packages/ui/src/styles.css exactly, so the app reads as the
//  same product as the (redesigned) website rather than a generic iOS dark
//  mode. Supersedes the ad hoc `.white.opacity(...)` grays used before this.

import SwiftUI

enum TLColor {
    static let accent = Color(hex: 0x10B981)
    static let warn = Color(hex: 0xF59E0B)
    static let ink = Color(hex: 0x0A0A0A)

    // Dark only for now — the scan flow is `.preferredColorScheme(.dark)`
    // throughout already; these exist so new screens don't reinvent grays.
    static let bg = Color(hex: 0x0A0A0A)
    static let fg = Color(hex: 0xF2F2F0)
    static let muted = Color(hex: 0x8B8B8B)
    static let line = Color.white.opacity(0.12)
    static let surface = Color(hex: 0x121212)
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
