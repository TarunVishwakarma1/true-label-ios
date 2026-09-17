//
//  ScanActivity.swift
//  truelable
//
//  Puts the scan you just did in the Dynamic Island and keeps it there while
//  you are still in the aisle. One activity at a time: scanning a second
//  product replaces the first rather than stacking, because a column of
//  identical islands is worse than none.
//

import ActivityKit
import Foundation

@MainActor
enum ScanActivity {
    /// Held so a re-scan of the same barcode updates in place instead of
    /// tearing the island down and building an identical one.
    private static var current: Activity<ScanActivityAttributes>?

    /// Long enough to still be useful two aisles later, short enough that a
    /// forgotten island doesn't sit on the lock screen all evening. After
    /// this the system dims it as stale on its own.
    private static let staleAfter: TimeInterval = 30 * 60

    static func show(_ product: Product) {
        // Respects the per-app Live Activities switch in Settings. Without
        // this, `request` throws every time for a user who turned them off.
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let content = ActivityContent(
            state: state(for: product),
            staleDate: .now.addingTimeInterval(staleAfter)
        )

        if let live = current, live.attributes.barcode == product.barcode {
            Task { await live.update(content) }
            return
        }

        let previous = current
        current = try? Activity.request(
            attributes: ScanActivityAttributes(barcode: product.barcode),
            content: content
        )
        if let previous {
            Task { await previous.end(nil, dismissalPolicy: .immediate) }
        }
    }

    static func dismiss() {
        guard let live = current else { return }
        current = nil
        Task { await live.end(nil, dismissalPolicy: .immediate) }
    }

    private static func state(for product: Product) -> ScanActivityAttributes.ContentState {
        let prefs = DietaryPreference.decode(
            UserDefaults.standard.string(forKey: Keys.dietary) ?? ""
        )
        let flagged = PersonalCheck.run(prefs, on: product).filter {
            $0.status == .avoid || $0.status == .caution
        }

        return ScanActivityAttributes.ContentState(
            productName: trimmed(product.name),
            brand: product.brand,
            grade: product.nutriscoreGrade,
            headline: headline(for: product),
            concerns: flagged.count
        )
    }

    /// The island's expanded slot fits roughly this much before truncating
    /// mid-word, and a name cut at a word boundary reads better than one cut
    /// by the layout engine.
    private static func trimmed(_ name: String, limit: Int = 30) -> String {
        guard name.count > limit else { return name }
        let clipped = name.prefix(limit)
        guard let lastSpace = clipped.lastIndex(of: " ") else { return String(clipped) + "…" }
        return clipped[..<lastSpace] + "…"
    }

    /// A number beats an adjective at a glance, and sugar-in-teaspoons is the
    /// app's own way of putting it. Falls back down the chain only when the
    /// product genuinely has no figures.
    private static func headline(for product: Product) -> String {
        if let sugar = product.nutrition.sugar {
            let tsp = sugar / 4
            let text = tsp < 10
                ? String(format: "%.1f", tsp).replacingOccurrences(of: ".0", with: "")
                : String(Int(tsp.rounded()))
            return "\(text) tsp sugar per 100 g"
        }
        if let calories = product.calories {
            return "\(calories) kcal per 100 g"
        }
        return product.verdict?.headline ?? "No label data yet"
    }
}
