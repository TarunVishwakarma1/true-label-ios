//
//  TrueLabelApp.swift
//  truelable
//

import SwiftUI
import SwiftData
import UIKit

@main
struct TrueLabelApp: App {
    @State private var router = AppRouter()

    init() {
        // Open Food Facts photos are immutable, so the default 20 MB shared
        // cache is the only reason a thumbnail is ever fetched twice.
        URLCache.shared = URLCache(memoryCapacity: 32 << 20, diskCapacity: 256 << 20)
        Self.styleNavigationBar()
        CrashReporter.shared.start()
        Self.resetStateIfUITesting()
    }

    /// UserDefaults (and so @AppStorage) survives across `XCUIApplication
    /// .launch()` calls within one simulator — a test that completes
    /// onboarding leaves every later test starting already-onboarded, not
    /// fresh-install. Real installs never pass this argument, so this is a
    /// no-op outside a UI test run.
    private static func resetStateIfUITesting() {
        guard ProcessInfo.processInfo.arguments.contains("UITEST_RESET_STATE") else { return }
        UserDefaults.standard.removeObject(forKey: Keys.onboarded)
        UserDefaults.standard.removeObject(forKey: Keys.dietary)
    }

    /// SwiftUI has no API for a navigation title's font, and leaving it as
    /// the system sans meant every screen but Home spoke in a different
    /// voice from the one the app was designed in.
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
                .preferredColorScheme(.dark)
                .tint(TL.accent)
                .onOpenURL(perform: handleOpenURL)
        }
        .modelContainer(Self.container)
    }

    /// The Home Screen widget's only trigger: `truelabel://scan` sets the
    /// exact same flag the empty History state's "Scan your first product"
    /// button already sets — one path into the scanner, not two.
    private func handleOpenURL(_ url: URL) {
        guard url.scheme == "truelabel", url.host == "scan" else { return }
        router.scannerPresented = true
    }

    /// Own store file — this bundle ID shipped v1 with a different schema,
    /// and a store that fails to open loses local history rather than the
    /// whole app.
    private static let container: ModelContainer = {
        let url = URL.applicationSupportDirectory.appending(path: "truelabel-v2.store")
        let config = ModelConfiguration(url: url)
        if let c = try? ModelContainer(for: ScanRecord.self, configurations: config) { return c }
        try? FileManager.default.removeItem(at: url)
        return try! ModelContainer(for: ScanRecord.self, configurations: config)
    }()
}

/// The few pieces of navigation state more than one screen needs to reach:
/// which tab is up, and whether the scanner is presented.
@Observable
final class AppRouter {
    enum Tab: Hashable { case home, history, verify, you }

    /// One sheet at a time, by value. Two `.sheet` modifiers on one view is
    /// not supported and races within a frame.
    enum Sheet: String, Identifiable {
        case manualEntry, search
        var id: String { rawValue }
    }

    var tab: Tab = .home
    var scannerPresented = false
    var sheet: Sheet?
}
