//
//  DotGridBackground.swift
//  truelable
//

import SwiftUI

struct DotGridBackground: View {
    var spacing: CGFloat = 26
    var dotSize: CGFloat = 1.6
    var color: Color = .white.opacity(0.18)
    var isPaused: Bool = false

    var body: some View {
        ZStack {
            PremiumBackground(isPaused: isPaused)
            dotsLayer
        }
        .ignoresSafeArea()
    }

    private var dotsLayer: some View {
        Canvas { context, size in
            // Recompute an exact step so dot columns/rows fill edge-to-edge
            // with equal margin on both sides, rather than a fixed spacing
            // that leaves a lopsided gap at the far edge.
            let columns = max(Int((size.width / spacing).rounded()), 1)
            let rows = max(Int((size.height / spacing).rounded()), 1)
            let stepX = size.width / CGFloat(columns)
            let stepY = size.height / CGFloat(rows)

            for row in 0..<rows {
                for col in 0..<columns {
                    let x = stepX / 2 + CGFloat(col) * stepX
                    let y = stepY / 2 + CGFloat(row) * stepY
                    let rect = CGRect(x: x - dotSize / 2, y: y - dotSize / 2, width: dotSize, height: dotSize)
                    context.fill(Path(ellipseIn: rect), with: .color(color))
                }
            }
        }
    }
}

#Preview {
    DotGridBackground()
}
