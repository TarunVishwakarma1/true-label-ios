//
//  VerifyView.swift
//  truelable
//
//  A deck of real products short of the 3-confirmation threshold. Swipe
//  right (or tap) to confirm — that's a real POST. Swipe left only skips
//  locally; the backend has no "dispute" shape yet, so nothing is sent.
//

import SwiftUI

struct VerifyView: View {
    @AppStorage(Keys.verifiedCount) private var verifiedCount = 0
    @State private var candidates: [Candidate] = []
    @State private var index = 0
    @State private var loading = true
    @State private var failed = false
    @State private var drag: CGSize = .zero
    @State private var voted = 0
    @State private var checkedNow = 0
    @State private var confirmed = 0

    private var remaining: ArraySlice<Candidate> { candidates[min(index, candidates.count)...] }

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    loadingState
                } else if failed {
                    failedState
                } else if remaining.isEmpty {
                    emptyState
                } else {
                    deck
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .screenBackground()
            .navigationTitle("Verify")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Pill(text: "\(verifiedCount) confirmed", color: TL.accent, icon: "checkmark.seal.fill")
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .sensoryFeedback(.impact(weight: .light), trigger: voted)
        .sensoryFeedback(.success, trigger: confirmed)
    }

    private var deck: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Does this look right?")
                    .font(.displayM)
                Text("Someone added this label. Confirm only if you're holding the pack and it matches.")
                    .font(.subheadline)
                    .foregroundStyle(TL.fg2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 8)
            .appear(0)

            ZStack {
                ForEach(Array(remaining.prefix(3).enumerated().reversed()), id: \.element.id) { offset, candidate in
                    card(candidate, isTop: offset == 0)
                        .scaleEffect(offset == 0 ? 1 : 1 - CGFloat(offset) * 0.04)
                        .offset(y: CGFloat(offset) * 12)
                        .zIndex(Double(3 - offset))
                        .allowsHitTesting(offset == 0)
                }
            }
            .frame(height: 270)
            .padding(.horizontal, 28)
            // Nothing implicit on this container, and no entrance transform
            // on it either. The cards inside carry a live `.glassEffect`,
            // and an implicit `.animation(value:)` here animates the glass's
            // own geometry on every restack — which is the background
            // bleeding away from its content, the same bug as before. The
            // deck is animated explicitly from `advance()` instead, which
            // keeps the change contained to the state that actually moved.

            Text("\(remaining.count) left · swipe right to confirm, left to skip")
                .font(.caption)
                .foregroundStyle(TL.fg3)
                .contentTransition(.numericText())
                .appear(2)

            HStack(spacing: 12) {
                Button { advance() } label: {
                    Label("Skip", systemImage: "arrow.uturn.right").foregroundStyle(TL.fg)
                }
                .buttonStyle(.secondary)
                Button { Task { await confirm() } } label: {
                    Label("Matches", systemImage: "checkmark")
                }
                .buttonStyle(.primary)
            }
            .padding(.horizontal, 28)
            .appear(3)
            Spacer()
        }
    }

    private func card(_ c: Candidate, isTop: Bool) -> some View {
        let offset = isTop ? drag : .zero
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                ProductThumb(url: c.imageURL, size: 56, radius: 16)
                    // The product name text right next to it already
                    // names the item — an unlabeled photo would just be a
                    // redundant, uninformative stop for VoiceOver.
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(c.productName).font(.displayS).lineLimit(2)
                    if let brand = c.brand { Text(brand).font(.footnote).foregroundStyle(TL.fg2).lineLimit(1) }
                }
                Spacer(minLength: 0)
                GradeBadge(grade: c.nutriscoreGrade)
            }
            Hairline()
            VStack(spacing: 8) {
                stat("Energy", c.energyKcal, "kcal")
                stat("Sugar", c.sugar, "g")
                stat("Sodium", c.sodium.map { $0 * 1000 }, "mg")
            }
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule().fill(i < c.verificationCount ? TL.accent : Color.white.opacity(0.1)).frame(height: 4)
                }
                Text("\(c.verificationCount)/3").font(.caption2.weight(.semibold)).foregroundStyle(TL.fg3).padding(.leading, 6)
            }
        }
        .frame(height: 250)
        .card(.hero, fill: TL.elevated, solid: true)
        .overlay(alignment: .topTrailing) {
            if isTop {
                Pill(text: "MATCHES", color: TL.accent, icon: "checkmark", filled: true)
                    .opacity(min(max(drag.width / 70, 0), 1))
                    .padding(16)
                    // Fades in only as a drag VoiceOver can't perform
                    // anyway progresses — the real confirm path for a
                    // VoiceOver user is the "Matches" button below, which
                    // already speaks for itself.
                    .accessibilityHidden(true)
            }
        }
        .overlay(alignment: .topLeading) {
            if isTop {
                Pill(text: "SKIP", color: TL.fg2, icon: "arrow.uturn.right")
                    .opacity(min(max(-drag.width / 70, 0), 1))
                    .padding(16)
                    .accessibilityHidden(true)
            }
        }
        // The card is drawn `solid:` rather than in Liquid Glass for this
        // reason: a live compositor material cannot be transformed without
        // its background drifting from its content, and every card in this
        // deck is offset and scaled while the top one is dragged and
        // rotated. `compositingGroup()` stays so the border and shadow
        // rotate as one flattened piece with the card rather than each
        // being resolved separately.
        .compositingGroup()
        .offset(offset)
        .rotationEffect(.degrees(Double(offset.width / 20)))
        .gesture(isTop ? dragGesture : nil)
        // One combined stop instead of six-plus fragmented ones (name,
        // brand, grade, three separate stat rows, progress) — a shopper
        // glances at the whole card at once, so a VoiceOver user should
        // hear it as one summary too, then act via the Skip/Matches
        // buttons below rather than the drag gesture this can't perform.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isTop ? accessibilityLabel(for: c) : "")
        .accessibilityHidden(!isTop)
    }

    private func accessibilityLabel(for c: Candidate) -> String {
        var parts = [c.productName]
        if let brand = c.brand { parts.append("by \(brand)") }
        if let letter = Nutriscore.letter(c.nutriscoreGrade) { parts.append("Nutri-Score \(letter.uppercased())") }
        if let energy = c.energyKcal { parts.append("\(energy.compact) kilocalories per 100 grams") }
        if let sugar = c.sugar { parts.append("\(sugar.compact) grams sugar per 100 grams") }
        if let sodium = c.sodium { parts.append("\((sodium * 1000).compact) milligrams sodium per 100 grams") }
        parts.append("verified \(c.verificationCount) of 3 times")
        return parts.joined(separator: ", ")
    }

    private var dragGesture: some Gesture {
        // No implicit `.animation(value:)` on the card while this tracks —
        // that would wrap every `onChanged` tick in its own animation and
        // the queue falls behind the finger, reading as the card
        // "refusing" to swipe. Only the snap-back on release is animated.
        DragGesture()
            .onChanged { drag = $0.translation }
            .onEnded { value in
                if value.translation.width > 90 {
                    Task { await confirm() }
                } else if value.translation.width < -90 {
                    advance()
                } else {
                    // Timing curve, not a spring: a spring's overshoot is
                    // applied to the glass card's geometry and reopens the
                    // bleed. Springs are for things that aren't glass.
                    withAnimation(.tl(0.3)) { drag = .zero }
                }
            }
    }

    private func stat(_ label: String, _ value: Double?, _ unit: String) -> some View {
        HStack {
            Text(label).font(.footnote).foregroundStyle(TL.fg2)
            Spacer()
            Text(value.map { "\($0.compact) \(unit) / 100 g" } ?? "—")
                .font(.footnote.weight(.semibold))
                .numeric()
        }
    }

    private func confirm() async {
        guard let c = remaining.first else { return }
        advance()
        if (try? await API.verify(barcode: c.barcode)) != nil {
            verifiedCount += 1
            confirmed += 1
        }
    }

    private func advance() {
        voted += 1
        checkedNow += 1
        drag = .zero
        withAnimation(.tl(0.35)) { index += 1 }
    }

    /// Shaped like the deck it stands in for, rather than five grey lines —
    /// the wait should look like this screen arriving.
    private var loadingState: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Capsule().fill(TL.line).frame(width: 220, height: 20)
                Capsule().fill(TL.line).frame(width: 280, height: 12)
            }
            .padding(.top, 8)

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(TL.line).frame(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: 7) {
                        Capsule().fill(TL.line).frame(width: 150, height: 14)
                        Capsule().fill(TL.line).frame(width: 90, height: 10)
                    }
                    Spacer(minLength: 0)
                }
                Hairline()
                ForEach(0..<3, id: \.self) { _ in
                    Capsule().fill(TL.line).frame(height: 10)
                }
                Spacer(minLength: 0)
            }
            .frame(height: 250)
            .card(.hero, fill: TL.elevated, solid: true)
            .padding(.horizontal, 28)

            Spacer()
        }
        .loadingPulse()
    }

    private var emptyState: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle()
                    .fill(TL.surface)
                    .frame(width: 96, height: 96)
                    .overlay(Circle().stroke(TL.line))
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(TL.accent)
            }
            VStack(spacing: 8) {
                Text(checkedNow > 0 ? "That's the queue" : "All caught up")
                    .font(.displayM)
                Text(checkedNow > 0
                     ? "You checked \(checkedNow) just now. That's what keeps the catalogue honest."
                     : "Nothing needs a second look right now. Pull to refresh.")
                    .font(.subheadline)
                    .foregroundStyle(TL.fg2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)
        }
        .appear()
    }

    private var failedState: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle()
                    .fill(TL.surface)
                    .frame(width: 96, height: 96)
                    .overlay(Circle().stroke(TL.line))
                Image(systemName: "wifi.slash")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(TL.fg3)
            }
            VStack(spacing: 8) {
                Text("Couldn't load the queue")
                    .font(.displayM)
                Text("Check your connection and try again.")
                    .font(.subheadline)
                    .foregroundStyle(TL.fg2)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            Button("Try again") { Task { await load() } }
                .buttonStyle(.primary)
                .padding(.horizontal, 40)
        }
        .appear()
    }

    private func load() async {
        loading = candidates.isEmpty
        failed = false
        do {
            candidates = try await API.needsVerification()
            index = 0
        } catch {
            failed = candidates.isEmpty
        }
        loading = false
    }
}

#Preview {
    VerifyView().preferredColorScheme(.dark)
}
