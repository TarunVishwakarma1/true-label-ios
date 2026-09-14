//
//  ScanShortcut.swift
//  truelable
//
//  "Scan a product" as a Siri Shortcut / Spotlight / Action Button intent.
//  No new Xcode target needed — unlike QuickScanWidgetExtension, App
//  Intents live in the app's own target and are discovered automatically
//  by the AppIntentsMetadataProcessor build step already in the toolchain.
//
//  perform() reuses the exact truelabel://scan path QuickScanWidget's
//  widgetURL and the empty History state already trigger, rather than
//  reaching for AppRouter directly — an intent runs outside the SwiftUI
//  view hierarchy, with no access to TrueLabelApp's @State var router, and
//  the URL path is already the one thing here that's actually been built
//  and verified end to end.
//

import AppIntents
import UIKit

struct ScanProductIntent: AppIntent {
    static var title: LocalizedStringResource = "Scan a Product"
    static var description = IntentDescription("Jump straight into TrueLabel's scanner.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        if let url = URL(string: "truelabel://scan") {
            await UIApplication.shared.open(url)
        }
        return .result()
    }
}

struct TrueLabelShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ScanProductIntent(),
            phrases: [
                "Scan a product with \(.applicationName)",
                "Open the scanner in \(.applicationName)",
            ],
            shortTitle: "Scan a Product",
            systemImageName: "barcode.viewfinder"
        )
    }
}
