import SwiftUI
import SwiftData
import UIKit

@main
struct TrueLabelApp: App {
    @State private var router = AppRouter()

    init() {

        URLCache.shared = URLCache(memoryCapacity: 32 << 20, diskCapacity: 256 << 20)
        Self.styleNavigationBar()
        CrashReporter.shared.start()
        Self.resetStateIfUITesting()
    }

    private static func resetStateIfUITesting() {
        guard ProcessInfo.processInfo.arguments.contains("UITEST_RESET_STATE") else { return }
        UserDefaults.standard.removeObject(forKey: Keys.onboarded)
        UserDefaults.standard.removeObject(forKey: Keys.dietary)
    }

    private static func styleNavigationBar() {
        func serif(_ size: CGFloat, _ weight: UIFont.Weight) -> UIFont {
            let base = UIFont.systemFont(ofSize: size, weight: weight)
            guard let descriptor = base.fontDescriptor.withDesign(.serif) else { return base }
            return UIFont(descriptor: descriptor, size: size)
        }

        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [
            .font: serif(17, .semibold),
            .foregroundColor: UIColor(TL.fg)
        ]
        appearance.largeTitleTextAttributes = [
            .font: serif(32, .bold),
            .foregroundColor: UIColor(TL.fg)
        ]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .tint(TL.accent)
                .onOpenURL(perform: handleOpenURL)
        }
        .modelContainer(Self.container)
    }

    private func handleOpenURL(_ url: URL) {
        guard url.scheme == "truelabel", url.host == "scan" else { return }
        router.scannerPresented = true
    }

    private static let container: ModelContainer = {
        let url = URL.applicationSupportDirectory.appending(path: "truelabel-v2.store")
        let config = ModelConfiguration(url: url)
        if let c = try? ModelContainer(for: ScanRecord.self, configurations: config) { return c }
        try? FileManager.default.removeItem(at: url)
        return try! ModelContainer(for: ScanRecord.self, configurations: config)
    }()
}

@Observable
final class AppRouter {
    enum Tab: Hashable { case home, history, verify, you }

    enum Sheet: String, Identifiable {
        case manualEntry, search
        var id: String { rawValue }
    }

    var tab: Tab = .home
    var scannerPresented = false
    var sheet: Sheet?
}
