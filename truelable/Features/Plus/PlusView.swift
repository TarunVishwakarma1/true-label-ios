//
//  PlusView.swift
//  truelable
//
//  The upgrade screen, on StoreKit's own subscription UI so pricing,
//  trials, restore and family sharing behave exactly as the App Store
//  expects. Marketing content above is ours.
//

import SwiftUI
import StoreKit

struct PlusView: View {
    @Environment(\.dismiss) private var dismiss
    private let plus = Plus.shared

    var body: some View {
        NavigationStack {
            Group {
                if plus.isActive {
                    active
                } else if plus.isGiveaway {
                    giveaway
                } else {
                    store
                }
            }
            .screenBackground()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .presentationBackground(TL.bg)
        .presentationCornerRadius(32)
    }

    /// Nothing is for sale yet, so the paywall is a switch. Same marketing,
    /// no price, no obligation — and the copy says why rather than showing a
    /// fake price.
    private var giveaway: some View {
        ScrollView {
            VStack(spacing: 20) {
                marketing
                VStack(spacing: 12) {
                    Button {
                        Task {
                            if await plus.activateGiveaway() { dismiss() }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if plus.busy { ProgressView().tint(TL.ink) }
                            Text("Turn on Plus — free")
                        }
                    }
                    .buttonStyle(.primary)
                    .disabled(plus.busy)

                    Text("Free while we build it. No card, no trial that bills you. If it ever costs money you'll be asked first.")
                        .font(.caption)
                        .foregroundStyle(TL.fg3)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var store: some View {
        SubscriptionStoreView(productIDs: Plus.ids) {
            marketing
        }
        .subscriptionStoreControlStyle(.prominentPicker)
        .subscriptionStoreButtonLabel(.multiline)
        .storeButton(.visible, for: .restorePurchases)
        .storeButton(.hidden, for: .cancellation)
        .containerBackground(TL.bg, for: .subscriptionStore)
        .subscriptionStoreControlBackground(.gradientMaterial)
        .onInAppPurchaseCompletion { _, result in
            if case .success(.success) = result {
                await plus.refresh()
            }
        }
        .tint(TL.accent)
    }

    private var marketing: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Everything you use\ntoday stays free.")
                .font(.displayL)
                .tracking(-0.6)
            Text("Scanning, results, verifying, adding products — none of it is behind Plus, and it won't be. Plus is the extra layer for people who want to go deeper.")
                .font(.subheadline)
                .foregroundStyle(TL.fg2)

            VStack(spacing: 12) {
                perk("chart.line.uptrend.xyaxis", "Trends over months", "Where sugar and sodium actually come from in what you buy, over 30 and 90 days.")
                perk("arrow.left.arrow.right", "Compare up to four", "Line up a whole shelf side by side, not just two.")
                perk("sparkles", "Ranked swaps", "Sort same-shelf alternatives by any nutrient, and see the full list.")
                perk("heart", "Keeps the lights on", "Servers, Open Food Facts contributions, no ads, no data sold.")
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private func perk(_ icon: String, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(TL.brass)
                .frame(width: 36, height: 36)
                .background(TL.brassDeep.opacity(0.18), in: RoundedRectangle(cornerRadius: TL.R.sm, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(body).font(.footnote).foregroundStyle(TL.fg2)
            }
        }
        .card(.flat)
    }

    private var active: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(TL.plusGradient)
            Text("You're on Plus")
                .font(.displayL)
            Text(plus.isComplimentary
                 ? "Trends, four-way compare and ranked swaps are on, free while we build it."
                 : "Trends, four-way compare and ranked swaps are all on. Thank you for keeping this independent.")
                .font(.subheadline)
                .foregroundStyle(TL.fg2)
                .multilineTextAlignment(.center)
            Spacer()
            if plus.isComplimentary {
                Button("Turn Plus off") { Task { await plus.cancel() } }
                    .buttonStyle(.secondary)
                    .disabled(plus.busy)
            } else {
                ManageSubscriptionButton()
            }
            Button("Done") { dismiss() }
                .buttonStyle(.primary)
        }
        .padding(28)
    }
}

/// Opens the system subscription management sheet.
struct ManageSubscriptionButton: View {
    @State private var showing = false
    var body: some View {
        Button("Manage subscription") { showing = true }
            .buttonStyle(.secondary)
            .manageSubscriptionsSheet(isPresented: $showing)
    }
}

/// Inline upsell used on Home and Profile.
struct PlusBanner: View {
    var compact: Bool = false
    @State private var showing = false

    var body: some View {
        Button { showing = true } label: {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: TL.R.sm, style: .continuous)
                        .fill(TL.plusGradient)
                        .frame(width: 44, height: 44)
                    Image(systemName: "sparkles")
                        .font(.body.weight(.bold))
                        .foregroundStyle(TL.ink)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text("TrueLabel Plus").font(.subheadline.weight(.semibold))
                    }
                    Text(Plus.shared.isGiveaway
                         ? "Trends, four-way compare, ranked swaps — free right now."
                         : "Trends over months, compare up to four, swaps ranked by any nutrient.")
                        .font(.footnote)
                        .foregroundStyle(TL.fg2)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(TL.fg3)
            }
            .card(.flat, fill: TL.elevated)
        }
        .buttonStyle(.pressable)
        .sheet(isPresented: $showing) { PlusView() }
    }
}

/// A row that says "this needs Plus" and opens the store.
struct PlusGate: View {
    var text: String
    @State private var showing = false

    var body: some View {
        Button { showing = true } label: {
            HStack(spacing: 12) {
                PlusTag()
                Text(text).font(.footnote.weight(.medium)).foregroundStyle(TL.fg2)
                Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(TL.fg3)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .sheet(isPresented: $showing) { PlusView() }
    }
}
