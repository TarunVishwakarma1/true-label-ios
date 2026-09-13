//
//  ProfileView.swift
//  truelable
//

import SwiftUI
import SwiftData

/// No accounts or auth anywhere in this app — so this is "your activity
/// and your preferences," not a fake login/avatar screen. Every number
/// here is real: `entries.count` and the verification counter are both
/// earned locally, nothing is invented to make the screen feel fuller.
struct ProfileView: View {
    @Query private var entries: [ScanHistoryEntry]
    @AppStorage("stats.verificationsSubmitted") private var verificationsSubmitted = 0
    @AppStorage("healthProfile.watchingSugar") private var watchingSugar = false
    @AppStorage("healthProfile.watchingSodium") private var watchingSodium = false
    @State private var showingPremium = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    statsRow
                    healthProfileSection
                    premiumBanner
                    aboutSection
                }
                .padding(20)
            }
            .background(TLColor.bg.ignoresSafeArea())
            .navigationTitle("Profile")
        }
        .preferredColorScheme(.dark)
        .sensoryFeedback(.selection, trigger: watchingSugar)
        .sensoryFeedback(.selection, trigger: watchingSodium)
        .sheet(isPresented: $showingPremium) {
            PremiumView(onDismiss: { showingPremium = false })
        }
    }

    private var premiumBanner: some View {
        Button {
            showingPremium = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("TrueLabel Plus").font(.system(size: 15, weight: .bold))
                    Text("Deeper trends and swap suggestions.").font(.system(size: 12.5)).foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.4))
            }
            .padding(16)
            .liquidGlassCard(cornerRadius: 16)
        }
        .buttonStyle(.plain)
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCard(value: "\(entries.count)", label: "SCANNED")
            statCard(value: "\(verificationsSubmitted)", label: "VERIFIED")
        }
    }

    private func statCard(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(.caption2, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(TLColor.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.08)))
    }

    /// Same toggles as `HealthProfileSheet` (still reachable from
    /// `ProductDetailView`'s top bar for a fast in-context change) — this
    /// is the canonical, always-reachable home for them.
    private var healthProfileSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("HEALTH PROFILE")

            VStack(spacing: 4) {
                Toggle(isOn: $watchingSugar) {
                    Label("Watching sugar", systemImage: "cube.fill")
                        .foregroundStyle(.white)
                }
                .tint(TLColor.accent)

                Toggle(isOn: $watchingSodium) {
                    Label("Watching sodium", systemImage: "drop.fill")
                        .foregroundStyle(.white)
                }
                .tint(TLColor.accent)
            }

            Text("Flagged first because you asked. Nothing else changes.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))

            Divider().overlay(.white.opacity(0.1)).padding(.vertical, 4)

            Text("AVOID & ALLERGIES")
                .font(.system(.caption2, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.4))
            DietaryPreferenceChips()
        }
        .padding(16)
        .background(TLColor.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.08)))
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("ABOUT")

            Link(destination: URL(string: "https://github.com/TarunVishwakarma1/true-lable")!) {
                HStack {
                    Label("View source · Apache-2.0", systemImage: "chevron.left.forwardslash.chevron.right")
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

            Divider().overlay(.white.opacity(0.1))

            HStack {
                Text("Version")
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Text(appVersion)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .font(.subheadline)
        }
        .padding(16)
        .background(TLColor.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.08)))
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(.caption2, design: .monospaced))
            .tracking(1.5)
            .foregroundStyle(.white.opacity(0.4))
    }

    private var appVersion: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}

#Preview {
    ProfileView()
        .modelContainer(for: ScanHistoryEntry.self, inMemory: true)
}
