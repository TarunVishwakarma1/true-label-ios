//
//  OnboardingView.swift
//  truelable
//
//  Three swipes: what it is, why to trust it, what to watch for. The
//  preferences page writes straight to the same @AppStorage the rest of
//  the app reads — no separate save step.
//
//  This is the first thing anyone sees, so it is the one screen where the
//  entrance is the point: the mark reads itself, then the words arrive.
//

import SwiftUI

struct OnboardingView: View {
    var onFinished: () -> Void

    @State private var page = 0
    @AppStorage(Keys.dietary) private var dietaryRaw = ""

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                welcome.tag(0)
                trust.tag(1)
                preferences.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack(spacing: 16) {
                dots
                Button(page == 2 ? "Start scanning" : "Continue") {
                    if page == 2 { onFinished() } else { withAnimation(.tlSettle) { page += 1 } }
                }
                .buttonStyle(.primary)
                .contentTransition(.opacity)

                // A third page of preferences is worth skipping for someone
                // reinstalling, and burying the exit is the kind of thing
                // that reads as an app that doesn't trust its own value.
                Group {
                    if page == 2 {
                        Text("Stays on your phone. No account, nothing sold about you.")
                            .font(.caption)
                            .foregroundStyle(TL.fg3)
                            .multilineTextAlignment(.center)
                    } else {
                        Button("Skip") { onFinished() }
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(TL.fg3)
                    }
                }
                .frame(height: 18)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
        .screenBackground()
        .animation(.tlSettle, value: page)
        .sensoryFeedback(.selection, trigger: page)
    }

    private var dots: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(i == page ? TL.accent : Color.white.opacity(0.18))
                    .frame(width: i == page ? 22 : 8, height: 4)
                    .animation(.tlSnap, value: page)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Page \(page + 1) of 3")
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            ScanningGlyph()
                .frame(height: 96)
                .padding(.bottom, 44)
                .appear(0)
            Text("Scan it.\nActually know it.")
                .font(.displayXL)
                .tracking(-1)
                .lineSpacing(-4)
                .appear(1)
            Text("Point at any barcode and see what's really inside — sugar in teaspoons, additives by name, and whether it fits how you eat.")
                .font(.body)
                .foregroundStyle(TL.fg2)
                .padding(.top, 14)
                .appear(2)
            Spacer()
        }
        .padding(.horizontal, 28)
    }

    private var trust: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            Text("Verified by people,\nnot press releases.")
                .font(.displayL)
                .tracking(-0.8)
                .appear(0)
            Text("Some data comes from Open Food Facts. Some comes from shoppers who photographed a label. You always see which — and you can confirm what you're holding.")
                .font(.body)
                .foregroundStyle(TL.fg2)
                .padding(.top, 14)
                .appear(1)

            VStack(spacing: 12) {
                trustRow("checkmark.seal.fill", TL.accent, "Verified", "Confirmed against the printed label by 3+ people.")
                    .appear(2)
                trustRow("person.2.fill", TL.warn, "Community-submitted", "Read from a photo, still collecting confirmations.")
                    .appear(3)
                trustRow("plus.viewfinder", TL.fg2, "Not in the database", "Nobody's added it yet. You can be the first.")
                    .appear(4)
            }
            .padding(.top, 28)
            Spacer()
        }
        .padding(.horizontal, 28)
    }

    private func trustRow(_ icon: String, _ tint: Color, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: TL.R.sm, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(body).font(.footnote).foregroundStyle(TL.fg2)
            }
        }
        .card(.flat)
    }

    private var preferences: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Anything we should\nwatch for?")
                    .font(.displayL)
                    .tracking(-0.8)
                    .padding(.top, 72)
                    .appear(0)
                Text("Pick what matters and every scan flags it first. Optional — change it anytime under You.")
                    .font(.body)
                    .foregroundStyle(TL.fg2)
                    .padding(.top, 12)
                    .appear(1)
                DietaryChips(raw: $dietaryRaw)
                    .padding(.top, 26)
                    .appear(2)
            }
            .padding(.horizontal, 28)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
    }
}

/// The brand mark, reading itself. A barcode's whole job is to be scanned,
/// so the one animation on the opening screen is the scan — not a logo that
/// slides in from somewhere for no reason.
private struct ScanningGlyph: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sweeping = false

    var body: some View {
        BarcodeGlyph()
            .overlay {
                if !reduceMotion {
                    GeometryReader { geo in
                        LinearGradient(
                            colors: [.clear, TL.accent.opacity(0.9), .clear],
                            startPoint: .top, endPoint: .bottom
                        )
                        .frame(height: 26)
                        .blur(radius: 3)
                        .offset(y: sweeping ? geo.size.height : -26)
                    }
                    .allowsHitTesting(false)
                }
            }
            .mask { BarcodeGlyph() }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 2.1).repeatForever(autoreverses: false).delay(0.4)) {
                    sweeping = true
                }
            }
            .accessibilityHidden(true)
    }
}

/// Wrapping chips over the shared preference set. Used here and in Profile.
struct DietaryChips: View {
    @Binding var raw: String

    private var enabled: Set<DietaryPreference> { DietaryPreference.decode(raw) }

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(DietaryPreference.allCases) { pref in
                let on = enabled.contains(pref)
                Button {
                    var set = enabled
                    if on { set.remove(pref) } else { set.insert(pref) }
                    withAnimation(.tlSnap) { raw = DietaryPreference.encode(set) }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: on ? "checkmark" : pref.icon)
                            .font(.caption.weight(.bold))
                            .contentTransition(.symbolEffect(.replace))
                        Text(pref.rawValue)
                            .font(.subheadline.weight(on ? .semibold : .regular))
                    }
                    .foregroundStyle(on ? TL.ink : TL.fg)
                    .engraved(0.6)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .glassEffect(on ? .regular.tint(TL.accent).interactive() : .regular.interactive(), in: .capsule)
                }
                .buttonStyle(.pressable)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: raw)
    }
}

/// Left-to-right wrapping layout for chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 { x = 0; y += row + spacing; row = 0 }
            x += size.width + spacing
            row = max(row, size.height)
        }
        return CGSize(width: width, height: y + row)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, row: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += row + spacing; row = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            row = max(row, size.height)
        }
    }
}

#Preview {
    OnboardingView(onFinished: {})
        .preferredColorScheme(.dark)
}
