//
//  OnboardingView.swift
//  truelable
//

import SwiftUI

/// Shown once, before the first `RootView` tab bar appears — see
/// `RootView`'s `hasOnboarded` gate. Four pages, one continuous view
/// hierarchy (matches this app's established pattern of an internal enum
/// state machine rather than `NavigationStack`, same as `ScannerView`/
/// `ContributeProductView`).
struct OnboardingView: View {
    var onFinished: () -> Void

    private enum Page: Int, CaseIterable {
        case welcome, trust, preferences, done
    }

    @State private var page: Page = .welcome

    var body: some View {
        ZStack {
            TLColor.bg.ignoresSafeArea()

            switch page {
            case .welcome: welcomePage
            case .trust: trustPage
            case .preferences: preferencesPage
            case .done: donePage
            }
        }
        .preferredColorScheme(.dark)
        .transition(.opacity)
        .animation(.easeOutExpo(duration: 0.34), value: page)
    }

    // MARK: - Page 1

    private var welcomePage: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .strokeBorder(TLColor.accent.opacity(0.28), lineWidth: 1.5)
                    .frame(width: 196, height: 196)
                    .modifier(PulseRing())
                Circle()
                    .strokeBorder(TLColor.accent.opacity(0.5), lineWidth: 1.5)
                    .frame(width: 196, height: 196)
                barcodeGlyph
            }
            .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 14) {
                Text("Scan it.\nActually know it.")
                    .font(.system(size: 38, weight: .bold))
                    .tracking(-0.5)
                Text("Point at any barcode and see what's really inside. No ads, no nudges to buy, nothing sold about you.")
                    .font(.system(size: 16.5))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            progressDots(current: 0)
                .padding(.vertical, 20)

            Button("Continue") { page = .trust }
                .buttonLabelStyle()
        }
        .padding(.horizontal, 28)
        .padding(.top, 96)
        .padding(.bottom, 40)
    }

    private var barcodeGlyph: some View {
        HStack(alignment: .center, spacing: 4) {
            ForEach([4.0, 7, 3, 8, 3, 5, 3], id: \.self) { w in
                RoundedRectangle(cornerRadius: 2)
                    .fill(w == 7 || w == 3 ? TLColor.accent : Color.white)
                    .frame(width: w, height: 74)
            }
        }
    }

    // MARK: - Page 2

    private var trustPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Verified by people,\nnot press releases.")
                .font(.system(size: 33, weight: .bold))
                .tracking(-0.4)
            Text("Some data comes from official sources. Some comes from shoppers who photographed a label. You always see which.")
                .font(.system(size: 16))
                .foregroundStyle(.white.opacity(0.6))
                .padding(.top, 14)

            VStack(spacing: 12) {
                trustRow(
                    icon: "checkmark", iconColor: TLColor.accent,
                    title: "Verified", titleColor: TLColor.accent,
                    body: "Matches the printed label, confirmed by 5+ people.",
                    highlighted: true
                )
                trustRow(
                    icon: "square", iconColor: TLColor.warn,
                    title: "Community-submitted", titleColor: TLColor.warn,
                    body: "Read from a photo, still collecting confirmations."
                )
                trustRow(
                    icon: "circle", iconColor: .white.opacity(0.5),
                    title: "Not in the database", titleColor: .white,
                    body: "Nobody's added it yet. You can be the first."
                )
            }
            .padding(.top, 30)

            Spacer()
            progressDots(current: 1).padding(.bottom, 20)
            Button("Makes sense") { page = .preferences }
                .buttonLabelStyle()
        }
        .padding(.horizontal, 28)
        .padding(.top, 96)
        .padding(.bottom, 40)
    }

    private func trustRow(icon: String, iconColor: Color, title: String, titleColor: Color, body: String, highlighted: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(iconColor.opacity(0.18)).frame(width: 30, height: 30)
                Image(systemName: icon).font(.system(size: 13, weight: .bold)).foregroundStyle(iconColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(titleColor)
                Text(body).font(.system(size: 13.5)).foregroundStyle(.white.opacity(0.55))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(highlighted ? TLColor.accent.opacity(0.07) : Color.clear)
        .liquidGlassCard(cornerRadius: highlighted ? 18 : 24)
    }

    // MARK: - Page 3

    private var preferencesPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Anything we should\nwatch for?")
                .font(.system(size: 33, weight: .bold))
                .tracking(-0.4)
            Text("Pick what matters and we'll flag it on every scan. Optional — you can set this later.")
                .font(.system(size: 15.5))
                .foregroundStyle(.white.opacity(0.58))
                .padding(.top, 12)

            DietaryPreferenceChips()
                .padding(.top, 26)

            Spacer()

            Text("This stays on your phone. We don't sell it, and we don't need an account for it to work.")
                .font(.system(size: 12.5))
                .foregroundStyle(.white.opacity(0.38))
                .padding(.bottom, 16)

            Button("Save preferences") { page = .done }
                .buttonLabelStyle()
            Button("Skip for now") { page = .done }
                .font(.system(size: 15.5))
                .foregroundStyle(.white.opacity(0.5))
                .frame(maxWidth: .infinity)
                .frame(height: 46)
        }
        .padding(.horizontal, 28)
        .padding(.top, 92)
        .padding(.bottom, 40)
    }

    // MARK: - Page 4

    private var donePage: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 34)
                    .fill(TLColor.accent.opacity(0.14))
                    .frame(width: 104, height: 104)
                    .overlay(RoundedRectangle(cornerRadius: 34).strokeBorder(TLColor.accent.opacity(0.35)))
                Image(systemName: "checkmark")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(TLColor.accent)
            }
            VStack(spacing: 12) {
                Text("You're all set.")
                    .font(.system(size: 30, weight: .bold))
                    .tracking(-0.4)
                Text("Try something from the kitchen shelf — a biscuit packet, a namkeen, a curd tub.")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }
            Spacer()
            Button("Scan your first product", action: onFinished)
                .buttonLabelStyle()
        }
        .padding(.horizontal, 28)
        .padding(.top, 96)
        .padding(.bottom, 40)
    }

    private func progressDots(current: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<4) { i in
                Capsule()
                    .fill(i == current ? TLColor.accent : Color.white.opacity(0.18))
                    .frame(width: i == current ? 22 : 8, height: 3)
            }
        }
    }
}

private struct PulseRing: ViewModifier {
    @State private var pulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(pulsing ? 1.28 : 0.9)
            .opacity(pulsing ? 0 : 0.55)
            .onAppear {
                withAnimation(.easeOut(duration: 2.6).repeatForever(autoreverses: false)) {
                    pulsing = true
                }
            }
    }
}

private extension View {
    func buttonLabelStyle() -> some View {
        font(.system(size: 17, weight: .semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .primaryCTAStyle()
    }
}

#Preview {
    OnboardingView(onFinished: {})
}
