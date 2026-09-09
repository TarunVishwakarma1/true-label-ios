//
//  PremiumBackground.swift
//  truelable
//

import SwiftUI

/// Aurora rays fanning out from a vanishing point, animated via a sine wave
/// driven by elapsed time. Ray geometry (direction, length, color) is fixed
/// once per ray and cached — only the wave motion runs every frame.
struct PremiumBackground: View {
    /// Freezes the animation (e.g. while covered by a fullScreenCover,
    /// which otherwise keeps rendering underneath at full cost).
    var isPaused: Bool = false

    private let nightSky = Color(red: 0.01, green: 0.015, blue: 0.025)

    private struct RayGeometry {
        var angleT: CGFloat // 0...1 position across the fan
        var lengthScale: CGFloat
        var lineWidth: CGFloat
        var phase: Double
        var waveSpeed: Double
        var nearColor: Color
        var farColor: Color

        init(angleT: CGFloat, lengthScale: CGFloat, hueOffset: Double, lineWidth: CGFloat, phase: Double, waveSpeed: Double) {
            self.angleT = angleT
            self.lengthScale = lengthScale
            self.lineWidth = lineWidth
            self.phase = phase
            self.waveSpeed = waveSpeed
            self.nearColor = Color(hue: (0.88 + hueOffset * 0.3).truncatingRemainder(dividingBy: 1), saturation: 0.55, brightness: 0.6)
            self.farColor = Color(hue: (0.38 + hueOffset).truncatingRemainder(dividingBy: 1), saturation: 0.75, brightness: 0.55)
        }
    }

    /// Size-dependent, time-independent part of a ray's path — cached so
    /// it's not recomputed every frame.
    private struct RayBase {
        var dirX: CGFloat
        var dirY: CGFloat
        var perpX: CGFloat
        var perpY: CGFloat
        var length: CGFloat
    }

    /// Reference type in `@State` so refreshing it from inside `Canvas`
    /// doesn't itself trigger a re-render.
    private final class GeometryCache {
        private(set) var size: CGSize = .zero
        private(set) var vp: CGPoint = .zero
        private(set) var bases: [RayBase] = []

        func refresh(for size: CGSize, rays: [RayGeometry]) {
            guard size != self.size else { return }
            self.size = size
            vp = CGPoint(x: size.width * 0.62, y: -size.height * 0.25)
            let leftTarget = CGPoint(x: -size.width * 0.3, y: size.height * 1.05)
            let rightTarget = CGPoint(x: size.width * 1.25, y: size.height * 0.65)

            bases = rays.map { ray in
                let target = CGPoint(
                    x: leftTarget.x + (rightTarget.x - leftTarget.x) * ray.angleT,
                    y: leftTarget.y + (rightTarget.y - leftTarget.y) * ray.angleT
                )
                let dx = target.x - vp.x
                let dy = target.y - vp.y
                let rawLength = sqrt(dx * dx + dy * dy)
                let dirX = dx / rawLength
                let dirY = dy / rawLength
                return RayBase(
                    dirX: dirX,
                    dirY: dirY,
                    perpX: -dirY,
                    perpY: dirX,
                    length: rawLength * ray.lengthScale
                )
            }
        }
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

    @State private var geometryCache = GeometryCache()

    var body: some View {
        // 18fps: this motion is slow enough that it reads just as smooth as
        // a higher rate, at a real fraction of the blur-filter cost.
        TimelineView(.animation(minimumInterval: 1.0 / 18.0, paused: isPaused)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, size in
                geometryCache.refresh(for: size, rays: rays)
                let vp = geometryCache.vp

                let strands: [(path: Path, near: Color, far: Color, farPoint: CGPoint, width: CGFloat)] =
                    zip(rays, geometryCache.bases).map { ray, base in
                        buildStrand(ray, base: base, vp: vp, t: t)
                    }

                // No `.addFilter(.blur(...))` here — that allocates a fresh
                // Core Image filter pipeline inside Canvas every single
                // frame, which is a known way to accumulate GPU resource
                // pressure over sustained continuous use (fine at first,
                // degrades the longer it runs — exactly what this looked
                // like). Plain strokes here; blur is applied once below as
                // a stable view-level effect instead.
                context.blendMode = .screen
                for strand in strands {
                    context.stroke(
                        strand.path,
                        with: .linearGradient(
                            Gradient(colors: [strand.near.opacity(0.3), strand.far.opacity(0.22), strand.far.opacity(0)]),
                            startPoint: vp,
                            endPoint: strand.farPoint
                        ),
                        style: StrokeStyle(lineWidth: strand.width * 3, lineCap: .round)
                    )
                    context.stroke(
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
            .background(nightSky)
            .compositingGroup()
            .blur(radius: 5)
        }
        .ignoresSafeArea()
    }

    private func buildStrand(
        _ ray: RayGeometry, base: RayBase, vp: CGPoint, t: Double
    ) -> (path: Path, near: Color, far: Color, farPoint: CGPoint, width: CGFloat) {
        var path = Path()
        var farPoint = vp
        let step: CGFloat = 14
        var d: CGFloat = 0
        var isFirst = true
        while d <= base.length {
            let progress = d / base.length
            let amplitude = 20 * progress
            let wave = amplitude * CGFloat(sin(Double(d) * 0.02 + t * ray.waveSpeed + ray.phase))
            let point = CGPoint(x: vp.x + base.dirX * d + base.perpX * wave, y: vp.y + base.dirY * d + base.perpY * wave)
            if isFirst {
                path.move(to: point)
                isFirst = false
            } else {
                path.addLine(to: point)
            }
            farPoint = point
            d += step
        }

        return (path, ray.nearColor, ray.farColor, farPoint, ray.lineWidth)
    }
}

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
