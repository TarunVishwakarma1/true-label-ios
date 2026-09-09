//
//  AnimatedGradientBorder.swift
//  truelable
//

import SwiftUI

/// A soft highlight that slides back and forth along a shape's border —
/// used on the Scan button and the scanner's viewfinder, so both share one
/// "alive" outline instead of each rolling their own.
struct AnimatedGradientBorder<S: InsettableShape>: View {
    var shape: S
    var lineWidth: CGFloat = 1.5
    var duration: Double = 2.5
    var isPaused: Bool = false

    var body: some View {
        // A slow breathing highlight doesn't need native ProMotion refresh —
        // capping it keeps this cheap wherever it's reused.
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: isPaused)) { timeline in
            let raw = timeline.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: duration) / duration
            let progress = (1 - cos(.pi * 2 * raw)) / 2 // eased, seamless loop

            shape.strokeBorder(
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.06), location: 0),
                        .init(color: .white.opacity(0.7), location: progress),
                        .init(color: .white.opacity(0.06), location: 1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                lineWidth: lineWidth
            )
        }
    }
}

#Preview {
    AnimatedGradientBorder(shape: RoundedRectangle(cornerRadius: 28))
        .frame(width: 240, height: 240)
        .padding()
        .background(.black)
}
