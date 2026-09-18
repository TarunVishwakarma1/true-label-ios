import SwiftUI

extension Animation {

    static let tlSnap = Animation.spring(response: 0.32, dampingFraction: 0.82)

    static let tlSettle = Animation.spring(response: 0.52, dampingFraction: 0.86)

    static let tlLift = Animation.spring(response: 0.62, dampingFraction: 0.72)
}

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

    func settleOnScroll() -> some View {
        modifier(SettleOnScroll())
    }

    func loadingPulse(_ active: Bool = true) -> some View {
        modifier(LoadingPulse(active: active))
    }

    func zoomSource(_ id: some Hashable, in namespace: Namespace.ID) -> some View {
        matchedTransitionSource(id: id, in: namespace)
    }

    func zoomDestination(_ id: some Hashable, in namespace: Namespace.ID) -> some View {
        navigationTransition(.zoom(sourceID: id, in: namespace))
    }
}
