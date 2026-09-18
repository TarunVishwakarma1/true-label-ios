import ActivityKit
import Foundation

@MainActor
enum ScanActivity {

    private static var current: Activity<ScanActivityAttributes>?

    private static let staleAfter: TimeInterval = 30 * 60

    static func show(_ product: Product) {

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

    private static func trimmed(_ name: String, limit: Int = 30) -> String {
        guard name.count > limit else { return name }
        let clipped = name.prefix(limit)
        guard let lastSpace = clipped.lastIndex(of: " ") else { return String(clipped) + "…" }
        return clipped[..<lastSpace] + "…"
    }

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
