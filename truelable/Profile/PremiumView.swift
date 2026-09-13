//
//  PremiumView.swift
//  truelable
//

import SwiftUI

/// Marketing/values content, not a working purchase flow — there's no
/// StoreKit/IAP integration anywhere in this app yet (same call made for
/// the free health-profile feature earlier in this project). The "Try
/// Plus" button is disabled with "Coming soon" rather than pretending to
/// start a trial it can't actually fulfill.
struct PremiumView: View {
    var onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Everything you\nuse today stays free.")
                            .font(.system(size: 30, weight: .bold))
                            .tracking(-0.4)
                        Text("Scanning, results, submitting, verifying — none of it is behind Plus, and it won't be. Plus is for people who want the extra layer.")
                            .font(.system(size: 15.5))
                            .foregroundStyle(.white.opacity(0.6))
                    }

                    VStack(spacing: 14) {
                        featureRow(icon: "arrow.triangle.2.circlepath", title: "Swap suggestions", body: "A lower-sodium option at a similar price, from products near you.")
                        featureRow(icon: "chart.line.uptrend.xyaxis", title: "Trends over months", body: "Where sugar and sodium actually come from in your basket.")
                        featureRow(icon: "person.2.fill", title: "Household sharing", body: "One profile for the family's allergies, on up to five phones.")
                    }

                    HStack(spacing: 12) {
                        pricingCard(title: "Yearly", price: "₹799", note: "₹67/mo")
                        pricingCard(title: "Monthly", price: "₹99", note: "cancel anytime")
                    }

                    VStack(spacing: 8) {
                        Text("Try Plus free for 14 days")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .foregroundStyle(.white.opacity(0.4))
                            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
                        Text("Coming soon")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.35))
                    }

                    Button("I'm good on free", action: onDismiss)
                        .font(.system(size: 15.5))
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                }
                .padding(20)
            }
            .background(TLColor.bg.ignoresSafeArea())
            .navigationTitle("TrueLabel Plus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onDismiss)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func featureRow(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(TLColor.accent)
                .frame(width: 30, height: 30)
                .background(TLColor.accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 15, weight: .semibold))
                Text(body).font(.system(size: 13.5)).foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    private func pricingCard(title: String, price: String, note: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(.caption2, design: .monospaced))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.5))
            Text(price).font(.system(size: 24, weight: .bold))
            Text(note).font(.system(size: 12)).foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .liquidGlassCard(cornerRadius: 18)
    }
}

#Preview {
    PremiumView(onDismiss: {})
}
