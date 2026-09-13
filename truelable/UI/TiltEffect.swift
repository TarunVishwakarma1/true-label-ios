//
//  TiltEffect.swift
//  truelable
//

import SwiftUI
import Combine
#if os(iOS)
import CoreMotion
#endif

/// Reads device attitude relative to however the phone is currently being
/// held (not absolute orientation) — captured fresh on every `start()`, so
/// tilting always reads as a small delta from "now", never a leftover
/// baseline from an earlier screen. Rate-capped to 30Hz, same discipline as
/// `PremiumBackground`'s 18fps cap — this is a subtle depth cue, not a game
/// controller, and doesn't need device-refresh-rate updates.
///
/// CoreMotion doesn't exist on macOS at all (this project also builds
/// "Designed for iPad" on Mac) — `available` is simply `false` there, and
/// `TiltEffect` below already has a drag-based fallback for exactly that.
@MainActor
final class TiltMotion: ObservableObject {
    @Published private(set) var roll: Double = 0
    @Published private(set) var pitch: Double = 0
    let available: Bool

    #if os(iOS)
    private let manager = CMMotionManager()
    private var reference: CMAttitude?
    #endif

    init() {
        #if os(iOS)
        available = manager.isDeviceMotionAvailable
        #else
        available = false
        #endif
    }

    func start() {
        #if os(iOS)
        guard available, !manager.isDeviceMotionActive else { return }
        reference = nil
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let attitude = data?.attitude else { return }
            guard let reference = self.reference else {
                self.reference = attitude
                return
            }
            attitude.multiply(byInverseOf: reference)
            self.roll = attitude.roll * 180 / .pi
            self.pitch = attitude.pitch * 180 / .pi
        }
        #endif
    }

    func stop() {
        #if os(iOS)
        manager.stopDeviceMotionUpdates()
        #endif
        roll = 0
        pitch = 0
    }
}

/// Tilt your phone and this content responds with real depth plus a
/// light-catching highlight — like turning a glossy product label to catch
/// the light. In Simulator (no CoreMotion) it falls back to drag-based
/// tilt, so the effect is still checkable without a device.
struct TiltEffect: ViewModifier {
    var maxDegrees: Double = 8
    var specular: Bool = true

    @StateObject private var motion = TiltMotion()
    @GestureState private var dragOffset: CGSize = .zero

    func body(content: Content) -> some View {
        let roll = motion.available ? motion.roll : Double(dragOffset.width / 8)
        let pitch = motion.available ? motion.pitch : Double(dragOffset.height / 8)
        let clampedRoll = min(max(roll, -maxDegrees), maxDegrees)
        let clampedPitch = min(max(pitch, -maxDegrees), maxDegrees)

        content
            .rotation3DEffect(.degrees(clampedPitch), axis: (x: 1, y: 0, z: 0), perspective: 0.4)
            .rotation3DEffect(.degrees(-clampedRoll), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
            .overlay {
                if specular {
                    SpecularHighlight(x: clampedRoll, y: clampedPitch)
                        .allowsHitTesting(false)
                }
            }
            .animation(.easeOutExpo(duration: 0.25), value: clampedRoll)
            .animation(.easeOutExpo(duration: 0.25), value: clampedPitch)
            // Harmless to keep attached even when CoreMotion is driving —
            // `dragOffset` is simply ignored above in that case, which
            // sidesteps SwiftUI's finicky optional-gesture overloads.
            .gesture(
                DragGesture().updating($dragOffset) { value, state, _ in state = value.translation }
            )
            .onAppear { motion.start() }
            .onDisappear { motion.stop() }
    }
}

private struct SpecularHighlight: View {
    var x: Double
    var y: Double

    var body: some View {
        GeometryReader { geo in
            RadialGradient(
                colors: [.white.opacity(0.3), .white.opacity(0)],
                center: UnitPoint(x: 0.5 + x / 16, y: 0.5 + y / 16),
                startRadius: 0,
                endRadius: max(geo.size.width, geo.size.height) * 0.7
            )
            .blendMode(.screen)
        }
    }
}

extension View {
    /// Applies `TiltEffect` — see its doc comment for the CoreMotion vs.
    /// Simulator-drag-fallback behavior.
    func tiltResponsive(maxDegrees: Double = 8, specular: Bool = true) -> some View {
        modifier(TiltEffect(maxDegrees: maxDegrees, specular: specular))
    }
}

#Preview {
    RoundedRectangle(cornerRadius: 24)
        .fill(TLColor.paper)
        .frame(width: 280, height: 180)
        .tiltResponsive()
        .padding(60)
        .background(Color.black)
}
