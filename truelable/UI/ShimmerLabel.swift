//
//  ShimmerLabel.swift
//  truelable
//

import SwiftUI

/// A label-shaped placeholder with a light sweep across it, standing in
/// for a bare `ProgressView()` while a lookup/analysis is in flight — cuts
/// perceived latency the way a real loading skeleton does. Plain gradient
/// sweep, not a blur/Material effect, and rate-capped like every other
/// continuous animation in this app (see `PremiumBackground`'s doc
/// comment) — a shimmer that costs a full-screen blur pass every frame
/// would trip the exact rule that motivated `ProductDetailView`'s opaque
/// cards.
struct ShimmerLabel: View {
    var lineCount: Int = 5
    /// `nil` lets the caller's own `.frame(...)` decide, instead of this
    /// view fighting it with a hardcoded height — needed to embed a
    /// smaller shimmer inside `ScannerView`'s 260×260 viewfinder.
    var height: CGFloat? = 200

    var body: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(TLColor.paper.opacity(0.9))
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(0..<lineCount, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(TLColor.paperInk.opacity(0.12))
                            .frame(width: index == lineCount - 1 ? 90 : nil, height: 10)
                    }
                }
                .padding(20)
            }
            .overlay { sweep }
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .frame(height: height)
    }

    private var sweep: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 1.6) / 1.6

            GeometryReader { geo in
                let travel = geo.size.width * 2.4
                LinearGradient(
                    colors: [.white.opacity(0), .white.opacity(0.35), .white.opacity(0)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: geo.size.width * 0.6)
                .offset(x: -geo.size.width * 0.6 + CGFloat(t) * travel)
                .blendMode(.plusLighter)
            }
        }
    }
}

#Preview {
    ShimmerLabel()
        .padding(24)
        .background(Color.black)
}
