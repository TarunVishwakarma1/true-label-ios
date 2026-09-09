//
//  Color+Brand.swift
//  truelable
//

import SwiftUI
import UIKit

extension Color {
    /// Legible label color for text/icons placed on a `.tint(.accentColor)`
    /// fill. AccentColor itself flips between near-black (light) and
    /// near-white (dark) to match the wordmark's ink for each appearance —
    /// a label sitting on top of that fill needs the opposite tone, not a
    /// fixed `.white`, or it goes invisible in dark mode (where AccentColor
    /// is itself near-white).
    static var accentLabel: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 8 / 255, green: 1 / 255, blue: 0 / 255, alpha: 1)
                : .white
        })
    }
}

// SwiftUI resolves leading-dot syntax like `.foregroundStyle(.accentLabel)`
// through `ShapeStyle` static members (the same mechanism that makes
// `.foregroundStyle(.white)` work), not through `Color`'s own statics —
// without this, callers would need the fully-qualified `Color.accentLabel`.
extension ShapeStyle where Self == Color {
    static var accentLabel: Color { Color.accentLabel }
}
