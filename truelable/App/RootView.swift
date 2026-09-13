//
//  RootView.swift
//  truelable
//
//  Four places to be (Home, History, Verify, You) and one action — Scan —
//  which lives in the tab bar's bottom accessory so it's one tap away from
//  every screen, the way a quick-commerce cart button is.
//

import SwiftUI
import SwiftData

struct RootView: View {
    @AppStorage(Keys.onboarded) private var onboarded = false
    @AppStorage(Keys.dietary) private var dietaryRaw = ""
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        Group {
            if onboarded {
                tabs
                    .transition(.opacity)
            } else {
                OnboardingView { withAnimation(.tl(0.5)) { onboarded = true } }
                    .transition(.opacity)
            }
        }
        .fullScreenCover(isPresented: $router.scannerPresented) {
            ScanScreen()
        }
        .sheet(item: $router.sheet) { sheet in
            switch sheet {
            case .manualEntry: ManualEntrySheet()
            case .search: SearchSheet()
            }
        }
        .task {
            // Adopt the saved profile only when this device has none of its
            // own — a fresh install after a reinstall, not an overwrite.
            guard let profile = try? await API.profile(), !profile.dietaryPreferences.isEmpty,
                  DietaryPreference.decode(dietaryRaw).isEmpty else { return }
            dietaryRaw = DietaryPreference.encode(Set(profile.dietaryPreferences.compactMap(DietaryPreference.init(rawValue:))))
        }
        .onChange(of: dietaryRaw) { _, updated in
            Task {
                _ = try? await API.updateProfile(
                    dietaryPreferences: DietaryPreference.decode(updated).map(\.rawValue)
                )
            }
        }
    }

    private var tabs: some View {
        @Bindable var router = router
        return TabView(selection: $router.tab) {
            Tab("Home", systemImage: "house.fill", value: AppRouter.Tab.home) { HomeView() }
            Tab("History", systemImage: "clock.fill", value: AppRouter.Tab.history) { HistoryView() }
            Tab("Verify", systemImage: "checkmark.seal.fill", value: AppRouter.Tab.verify) { VerifyView() }
            Tab("You", systemImage: "person.fill", value: AppRouter.Tab.you) { ProfileView() }
        }
        .tabViewBottomAccessory {
            ScanAccessory()
        }
    }
}

/// v1's scan button, in the place v2 keeps scanning: the tab bar accessory.
/// Glass capsule, a highlight travelling its border, and the symbol swapping
/// between the two things it reads. The system draws the glass here, so this
/// adds the highlight and the swap rather than a second glass layer.
private struct ScanAccessory: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    @State private var showQR = true

    var body: some View {
        Button {
            router.scannerPresented = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: showQR ? "qrcode" : "barcode")
                    .contentTransition(.symbolEffect(.replace))
                Text(placement == .inline ? "Scan" : "Scan a product")
            }
            .font(.headline)
            .foregroundStyle(TL.fg)
            .engraved()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .overlay {
                AnimatedGradientBorder(shape: Capsule(), isPaused: router.scannerPresented)
            }
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Scan a product")
        // Paused while the scanner covers the screen — the accessory is
        // still mounted and still rendering behind it.
        .task(id: router.scannerPresented) {
            guard !router.scannerPresented else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.2))
                withAnimation { showQR.toggle() }
            }
        }
    }
}

#Preview {
    RootView()
        .environment(AppRouter())
        .modelContainer(for: ScanRecord.self, inMemory: true)
        .preferredColorScheme(.dark)
}
