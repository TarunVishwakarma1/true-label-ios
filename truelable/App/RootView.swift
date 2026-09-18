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

        .tint(TL.accent)
        .tabViewBottomAccessory {
            ScanAccessory()
        }
        .sensoryFeedback(.selection, trigger: router.tab)
    }
}

private struct ScanAccessory: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var nudge = 0

    var body: some View {
        Button {
            router.scannerPresented = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 17, weight: .semibold))
                    .symbolEffect(.bounce, options: .nonRepeating, value: nudge)
                Text(placement == .inline ? "Scan" : "Scan a product")
                    .font(.headline)
            }
            .foregroundStyle(TL.ink)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(TL.accent, in: Capsule())
            .overlay { if !reduceMotion { Sheen().clipShape(Capsule()) } }
            .contentShape(Capsule())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Scan a product")
        .sensoryFeedback(.impact(weight: .medium), trigger: router.scannerPresented)

        .onChange(of: router.scannerPresented) { _, presented in
            if !presented { nudge += 1 }
        }
    }
}

private struct Sheen: View {
    @State private var travelled = false

    var body: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [.clear, TL.ink.opacity(0.13), .clear],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(width: geo.size.width * 0.4)
            .offset(x: travelled ? geo.size.width * 1.2 : -geo.size.width * 0.5)
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).delay(1.4).repeatForever(autoreverses: false)) {
                travelled = true
            }
        }
    }
}

#Preview {
    RootView()
        .environment(AppRouter())
        .modelContainer(for: ScanRecord.self, inMemory: true)
}
