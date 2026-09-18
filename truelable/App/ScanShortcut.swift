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
