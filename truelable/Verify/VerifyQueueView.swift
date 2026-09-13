//
//  VerifyQueueView.swift
//  truelable
//

import SwiftUI

/// Real products genuinely short of the 3-verification threshold (see
/// `ProductAPIClient.fetchNeedsVerification` / the backend's
/// `find_needs_verification`), never a fabricated queue.
///
/// The design this is built from shows checking a single specific field
/// (e.g. "Total sugar: 38.2g/100g") with a per-field confidence badge —
/// this app's real verification model is whole-product, not per-field (see
/// `VerifyPromptView`), so this asks "does this whole entry look right?"
/// instead, showing the key numbers rather than claiming a field-level
/// check that doesn't exist in the data. Swipe left only dismisses locally
/// — the backend has no "dispute" shape yet, only a plain confirmation, so
/// nothing is silently sent for a swipe-left the way it is for swipe-right.
struct VerifyQueueView: View {
    @State private var candidates: [VerificationCandidate] = []
    @State private var index = 0
    @State private var loading = true
    @State private var dragOffset: CGSize = .zero
    @State private var didVote = false
    @State private var totalChecked = 0

    var body: some View {
        NavigationStack {
            ZStack {
                TLColor.bg.ignoresSafeArea()

                if loading {
                    ProgressView().tint(.white)
                } else if remaining.isEmpty {
                    emptyState
                } else {
                    queue
                }
            }
            .navigationTitle("Verify")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
        .task { await load() }
        .sensoryFeedback(.impact(weight: .light), trigger: didVote)
    }

    private var remaining: ArraySlice<VerificationCandidate> {
        candidates[index...]
    }

    private var queue: some View {
        VStack(spacing: 24) {
            VStack(spacing: 4) {
                Text("Quick check")
                    .font(.system(size: 22, weight: .bold))
                Text("\(remaining.count) left")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.top, 12)

            Text("Someone submitted this label. Does it look right to you?")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            ZStack {
                ForEach(Array(remaining.prefix(3).enumerated().reversed()), id: \.element.id) { offset, candidate in
                    card(candidate)
                        .scaleEffect(offset == 0 ? 1 : 1 - CGFloat(offset) * 0.04)
                        .offset(y: offset == 0 ? 0 : CGFloat(offset) * 10)
                        .zIndex(offset == 0 ? 1 : 0)
                        .allowsHitTesting(offset == 0)
                }
            }
            .frame(height: 240)
            .padding(.horizontal, 28)

            Text("Swipe right if it matches, left if it doesn't")
                .font(.system(size: 12.5))
                .foregroundStyle(.white.opacity(0.35))

            HStack(spacing: 14) {
                Button {
                    advance(voted: false)
                } label: {
                    Text("Doesn't match")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(TLColor.danger)
                        .liquidGlassCard(cornerRadius: 16)
                }
                Button {
                    Task { await voteMatches() }
                } label: {
                    Text("Looks right")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .primaryCTAStyle()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)

            Button("Can't tell — skip") { advance(voted: false) }
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.4))

            Spacer()
        }
    }

    @ViewBuilder
    private func card(_ candidate: VerificationCandidate) -> some View {
        let isTop = candidate.id == remaining.first?.id
        if isTop {
            cardBody(candidate, isTop: true).gesture(dragGesture)
        } else {
            cardBody(candidate, isTop: false)
        }
    }

    private func cardBody(_ candidate: VerificationCandidate, isTop: Bool) -> some View {
        let rotation = isTop ? Double(dragOffset.width / 18) : 0

        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(candidate.productName).font(.system(size: 19, weight: .bold))
                if let brand = candidate.brand {
                    Text(brand).font(.system(size: 13)).foregroundStyle(.white.opacity(0.5))
                }
            }

            Divider().overlay(.white.opacity(0.1))

            VStack(alignment: .leading, spacing: 8) {
                statRow("Energy", candidate.energyKcal, unit: "kcal/100g")
                statRow("Sugar", candidate.sugar, unit: "g/100g")
                statRow("Sodium", candidate.sodium, unit: "mg/100g")
            }

            Spacer()

            Text("\(candidate.verificationCount) of 3 confirmations so far")
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 220)
        .liquidGlassCard(cornerRadius: 26)
        .overlay(alignment: .topTrailing) {
            if isTop {
                Text("MATCHES")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(TLColor.accent)
                    .padding(8)
                    .opacity(min(max(dragOffset.width / 70, 0), 1))
                    .padding(16)
            }
        }
        .overlay(alignment: .topLeading) {
            if isTop {
                Text("SKIP")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(TLColor.danger)
                    .padding(8)
                    .opacity(min(max(-dragOffset.width / 70, 0), 1))
                    .padding(16)
            }
        }
        .offset(isTop ? dragOffset : .zero)
        .rotationEffect(.degrees(rotation))
        .animation(.easeOutExpo(duration: 0.3), value: dragOffset)
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { dragOffset = $0.translation }
            .onEnded { value in
                if value.translation.width > 88 {
                    Task { await voteMatches() }
                } else if value.translation.width < -88 {
                    advance(voted: false)
                } else {
                    dragOffset = .zero
                }
            }
    }

    private func statRow(_ label: String, _ value: Double?, unit: String) -> some View {
        HStack {
            Text(label).font(.system(size: 13)).foregroundStyle(.white.opacity(0.55))
            Spacer()
            Text(value.map { "\($0.formatted(.number.precision(.fractionLength(0...1)))) \(unit)" } ?? "—")
                .font(.system(size: 13, design: .monospaced))
        }
    }

    private func voteMatches() async {
        guard let candidate = remaining.first else { return }
        _ = try? await ProductAPIClient.submitVerification(barcode: candidate.barcode)
        advance(voted: true)
    }

    private func advance(voted: Bool) {
        didVote.toggle()
        totalChecked += 1
        dragOffset = .zero
        withAnimation(.easeOutExpo(duration: 0.3)) {
            index += 1
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 40))
                .foregroundStyle(TLColor.accent.opacity(0.6))
            Text("Nothing to check right now")
                .font(.system(size: 16, weight: .semibold))
            Text(totalChecked > 0 ? "You checked \(totalChecked) just now — thanks." : "Come back once more people have scanned.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private func load() async {
        loading = true
        candidates = (try? await ProductAPIClient.fetchNeedsVerification()) ?? []
        index = 0
        loading = false
    }
}

#Preview {
    VerifyQueueView()
}
