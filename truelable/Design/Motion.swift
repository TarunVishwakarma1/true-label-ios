//
//  Motion.swift
//  truelable
//
//  The interaction layer. Theme.swift already settled what the app looks
//  like; this settles how it behaves — and that gap is most of what made
//  the app read as a drawing of an interface rather than an interface.
//
//  Three rules, so motion stays one language:
//    1. Springs for anything the user caused. A timing curve describes a
//       path, a spring describes a response, and a response is what makes a
//       tap feel answered.
//    2. `TL.tl()` (ease-out-expo, in Theme.swift) stays for anything the app
//       caused on its own — content arriving, a screen settling.
//    3. Nothing tracks the finger continuously. The previous pass at
//       scroll-linked motion is documented in Theme.swift as "what made this
//       app feel like it was being dragged", and it was right.
//

import SwiftUI

extension Animation {
    /// A tap, a toggle, a chip selecting. Short, barely any overshoot —
    /// this one should feel like the UI answering, not performing.
    static let tlSnap = Animation.spring(response: 0.32, dampingFraction: 0.82)

    /// Layout changing under its own weight: a section expanding, a list
    /// reflowing, a sheet resizing.
    static let tlSettle = Animation.spring(response: 0.52, dampingFraction: 0.86)

    /// The one place overshoot is allowed: something becoming the thing the
    /// user is now looking at. Used sparingly or it reads as bouncy.
    static let tlLift = Animation.spring(response: 0.62, dampingFraction: 0.72)
}

/// Content settles as it rises into view, and is left alone once it is
/// there. `.animated` rather than `.interactive` on purpose: interactive
/// ties the effect to scroll offset, which is the "being dragged" feel
/// Theme.swift warns about. This fires once on the way in and stops.
///
/// Only the bottom edge is treated. Fading things out as they leave the top
/// makes a short list feel like it is dissolving, and costs the reader the
/// thing they just scrolled past.
private struct SettleOnScroll: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.scrollTransition(.animated.threshold(.visible(0.15))) { view, phase in
                view
                    .opacity(phase == .bottomTrailing ? 0 : 1)
                    .scaleEffect(phase == .bottomTrailing ? 0.97 : 1, anchor: .top)
            }
        }
    }
}

/// A quiet breathing pulse for anything the app is still waiting on. Slower
/// and shallower than the system's default redaction shimmer, because at
/// this contrast a hard sweep reads as a glitch on a dark ground.
private struct LoadingPulse: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var active: Bool
    @State private var dim = false

    func body(content: Content) -> some View {
        content
            .opacity(active && dim ? 0.55 : 1)
            .animation(
                active && !reduceMotion
                    ? .easeInOut(duration: 1.1).repeatForever(autoreverses: true)
                    : .default,
                value: dim
            )
            .onChange(of: active, initial: true) { _, on in
                dim = on
            }
    }
}

extension View {
    /// See `SettleOnScroll`. Apply to the big blocks of a screen, not to
    /// every row — a page where each item animates separately is a page
    /// that never holds still.
    ///
    /// **`ScrollView` only. Never inside a `List`.** List recycles its rows
    /// through a collection view and the transition phase does not reliably
    /// resolve back to `.identity` for them, so rows strand at `opacity 0`:
    /// still laid out, still hit-testable, completely invisible. History and
    /// Search both shipped that way once — the rows were there and opened
    /// products when tapped, they just couldn't be seen. If a List needs
    /// this feeling, it doesn't: the platform already animates row insertion.
    func settleOnScroll() -> some View {
        modifier(SettleOnScroll())
    }

    /// Placeholder content that is waiting on the network.
    func loadingPulse(_ active: Bool = true) -> some View {
        modifier(LoadingPulse(active: active))
    }

    /// The source half of a zoom navigation. Pairs with
    /// `.zoomDestination(_:in:)` on the screen being pushed, so a product
    /// grows out of the card the user actually tapped instead of sliding in
    /// from the right like an unrelated page.
    func zoomSource(_ id: some Hashable, in namespace: Namespace.ID) -> some View {
        matchedTransitionSource(id: id, in: namespace)
    }

    func zoomDestination(_ id: some Hashable, in namespace: Namespace.ID) -> some View {
        navigationTransition(.zoom(sourceID: id, in: namespace))
    }
}
