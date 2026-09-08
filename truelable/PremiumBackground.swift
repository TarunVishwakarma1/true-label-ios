//
//  PremiumBackground.swift
//  truelable
//

import SwiftUI

/// Looking up into the night sky at an angle: aurora rays converge toward a
/// vanishing point above/beside the frame and fan out across the visible
/// sky — the perspective you get from a wide lens pointed near the zenith.
/// Each ray is its own strand; the ripple along its length comes from a
/// sine wave driven directly by elapsed time (no loop/reset, so the flow
/// never repeats on a visible cycle). Geometry (length, hue, width) is
/// randomized once per ray from a seeded generator, so only the wave itself
/// animates — the rays don't reshuffle or jitter frame to frame.
struct PremiumBackground: View {
    private let nightSky = Color(red: 0.01, green: 0.015, blue: 0.025)

    private struct RayGeometry {
        var angleT: CGFloat // 0...1 position across the fan
        var lengthScale: CGFloat
        var hueOffset: Double
        var lineWidth: CGFloat
        var phase: Double
        var waveSpeed: Double
    }

    private static let rayCount = 56

    private let rays: [RayGeometry] = (0..<rayCount).map { i in
        var rng = SeededGenerator(seed: UInt64(i + 1) &* 2654435761)
        return RayGeometry(
            angleT: CGFloat(i) / CGFloat(rayCount - 1),
            lengthScale: CGFloat.random(in: 0.7...1.25, using: &rng),
            hueOffset: Double.random(in: -0.03...0.05, using: &rng),
            lineWidth: CGFloat.random(in: 1.2...2.6, using: &rng),
            phase: Double.random(in: 0...(2 * .pi), using: &rng),
            waveSpeed: Double.random(in: 0.35...0.65, using: &rng)
        )
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, size in
                let vp = CGPoint(x: size.width * 0.62, y: -size.height * 0.25)
                let leftTarget = CGPoint(x: -size.width * 0.3, y: size.height * 1.05)
                let rightTarget = CGPoint(x: size.width * 1.25, y: size.height * 0.65)

                let strands: [(path: Path, near: Color, far: Color, farPoint: CGPoint, width: CGFloat)] =
                    rays.map { ray in
                        buildStrand(ray, vp: vp, leftTarget: leftTarget, rightTarget: rightTarget, t: t)
                    }

                // Bloom pass: wider, heavier blur, dimmer — the soft halo real
                // aurora photos show around each bright strand.
                context.drawLayer { layer in
                    layer.addFilter(.blur(radius: 9))
                    layer.blendMode = .screen
                    for strand in strands {
                        layer.stroke(
                            strand.path,
                            with: .linearGradient(
                                Gradient(colors: [strand.near.opacity(0.35), strand.far.opacity(0.25), strand.far.opacity(0)]),
                                startPoint: vp,
                                endPoint: strand.farPoint
                            ),
                            style: StrokeStyle(lineWidth: strand.width * 3, lineCap: .round)
                        )
                    }
                }

                // Core pass: thin, nearly sharp — the bright strand itself.
                context.drawLayer { layer in
                    layer.addFilter(.blur(radius: 1.5))
                    layer.blendMode = .screen
                    for strand in strands {
                        layer.stroke(
                            strand.path,
                            with: .linearGradient(
                                Gradient(colors: [strand.near.opacity(0.6), strand.far.opacity(0.5), strand.far.opacity(0)]),
                                startPoint: vp,
                                endPoint: strand.farPoint
                            ),
                            style: StrokeStyle(lineWidth: strand.width, lineCap: .round)
                        )
                    }
                }
            }
            .background(nightSky)
        }
        .ignoresSafeArea()
    }

    private func buildStrand(
        _ ray: RayGeometry, vp: CGPoint, leftTarget: CGPoint, rightTarget: CGPoint, t: Double
    ) -> (path: Path, near: Color, far: Color, farPoint: CGPoint, width: CGFloat) {
        let target = CGPoint(
            x: leftTarget.x + (rightTarget.x - leftTarget.x) * ray.angleT,
            y: leftTarget.y + (rightTarget.y - leftTarget.y) * ray.angleT
        )
        let dx = target.x - vp.x
        let dy = target.y - vp.y
        let rawLength = sqrt(dx * dx + dy * dy)
        let dirX = dx / rawLength
        let dirY = dy / rawLength
        let perpX = -dirY // perpendicular unit vector, for the wave displacement
        let perpY = dirX
        let length = rawLength * ray.lengthScale

        var path = Path()
        var farPoint = vp
        let step: CGFloat = 14
        var d: CGFloat = 0
        var isFirst = true
        while d <= length {
            let progress = d / length
            let amplitude = 20 * progress // rays wave more as they fan outward
            let wave = amplitude * CGFloat(sin(Double(d) * 0.02 + t * ray.waveSpeed + ray.phase))
            let point = CGPoint(x: vp.x + dirX * d + perpX * wave, y: vp.y + dirY * d + perpY * wave)
            if isFirst {
                path.move(to: point)
                isFirst = false
            } else {
                path.addLine(to: point)
            }
            farPoint = point
            d += step
        }

        // Near the vanishing point (higher altitude, overhead): a pink-violet
        // tinge. Fanning outward toward the horizon (lower altitude): green —
        // the same altitude-to-color relationship real aurora shows.
        let near = Color(hue: (0.88 + ray.hueOffset * 0.3).truncatingRemainder(dividingBy: 1), saturation: 0.55, brightness: 0.6)
        let far = Color(hue: (0.38 + ray.hueOffset).truncatingRemainder(dividingBy: 1), saturation: 0.75, brightness: 0.55)
        return (path, near, far, farPoint, ray.lineWidth)
    }
}

/// Deterministic RNG so each ray's geometry (length, hue, width) is fixed
/// once and doesn't reshuffle every frame — only the wave phase moves.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

#Preview {
    PremiumBackground()
}
