//
//  VerifyView.swift
//  truelable
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
    @State private var isSwiping = false

    private var remaining: ArraySlice<Candidate> { candidates[min(index, candidates.count)...] }

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    VStack(spacing: 16) { Skeleton(lines: 5).card().padding(.horizontal, 28) }
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

            ZStack {
                ForEach(Array(remaining.prefix(3).enumerated().reversed()), id: \.element.id) { offset, candidate in
                    card(candidate, isTop: offset == 0)
                        .scaleEffect(offset == 0 ? 1 : 1 - CGFloat(offset) * 0.04)
                        .offset(y: CGFloat(offset) * 12)
                        .zIndex(Double(3 - offset))
                        .allowsHitTesting(offset == 0 && !isSwiping)
                }
            }
            .frame(height: 270)
            .padding(.horizontal, 28)

            Text("\(remaining.count) left · swipe right to confirm, left to skip")
                .font(.caption)
                .foregroundStyle(TL.fg3)

            HStack(spacing: 12) {
                Button {
                    swipeCard(confirm: false)
                } label: {
                    Label("Skip", systemImage: "arrow.uturn.right").foregroundStyle(TL.fg)
                }
                .buttonStyle(.secondary)
                .disabled(isSwiping || remaining.isEmpty)

                Button {
                    swipeCard(confirm: true)
                } label: {
                    Label("Matches", systemImage: "checkmark")
                }
                .buttonStyle(.primary)
                .disabled(isSwiping || remaining.isEmpty)
            }
            .padding(.horizontal, 28)
            Spacer()
        }
    }

    private func card(_ c: Candidate, isTop: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: TL.R.xl, style: .continuous)
        let offset = isTop ? drag : .zero

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                ProductThumb(url: c.imageURL, size: 56, radius: 16)
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
        .engraved()
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TL.elevated, in: shape)
        .overlay {
            shape.strokeBorder(
                LinearGradient(
                    colors: [TL.accent.opacity(0.34), TL.accent.opacity(0.04)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
            .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(0.42), radius: 26, y: 14)
        .overlay(alignment: .topLeading) {
            if isTop {
                Pill(text: "MATCHES", color: TL.accent, icon: "checkmark", filled: true)
                    .opacity(min(max(drag.width / 70, 0), 1))
                    .padding(16)
                    .accessibilityHidden(true)
            }
        }
        .overlay(alignment: .topTrailing) {
            if isTop {
                Pill(text: "SKIP", color: TL.fg2, icon: "arrow.uturn.right")
                    .opacity(min(max(-drag.width / 70, 0), 1))
                    .padding(16)
                    .accessibilityHidden(true)
            }
        }
        .rotationEffect(.degrees(isTop ? Double(offset.width / 25) : 0), anchor: .center)
        .offset(offset)
        .highPriorityGesture(isTop ? dragGesture : nil)
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
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard !isSwiping else { return }
                drag = value.translation
            }
            .onEnded { value in
                guard !isSwiping else { return }
                let threshold: CGFloat = 90
                if value.translation.width > threshold {
                    swipeCard(confirm: true)
                } else if value.translation.width < -threshold {
                    swipeCard(confirm: false)
                } else {
                    withAnimation(.tl(0.3)) {
                        drag = .zero
                    }
                }
            }
    }

    private func swipeCard(confirm isConfirm: Bool) {
        guard !isSwiping, let c = remaining.first else { return }
        isSwiping = true
        withAnimation(.easeOut(duration: 0.22)) {
            drag = CGSize(width: isConfirm ? 500 : -500, height: drag.height)
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)
            if isConfirm {
                if (try? await API.verify(barcode: c.barcode)) != nil {
                    verifiedCount += 1
                }
            }
            advance()
            drag = .zero
            isSwiping = false
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

    private func advance() {
        voted += 1
        checkedNow += 1
        index += 1
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("All caught up", systemImage: "checkmark.seal.fill")
        } description: {
            Text(checkedNow > 0 ? "You checked \(checkedNow) just now. Thanks." : "Nothing needs a second look right now. Pull to refresh.")
        }
    }

    private var failedState: some View {
        ContentUnavailableView {
            Label("Couldn't load the queue", systemImage: "wifi.slash")
        } description: {
            Text("Check your connection and pull to refresh.")
        } actions: {
            Button("Try again") { Task { await load() } }.buttonStyle(.bordered)
        }
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
