import Foundation
import SwiftUI

enum Keys {
    static let onboarded = "v2.onboarded"
    static let dietary = "v2.prefs.dietary"
    static let verifiedCount = "v2.stats.verified"
    static let verifiedBarcodes = "v2.verified.barcodes"
}

enum DietaryPreference: String, CaseIterable, Identifiable, Sendable {
    case vegetarian = "Vegetarian"
    case vegan = "Vegan"
    case lowSugar = "Low sugar"
    case lowSodium = "Low sodium"
    case highProtein = "High protein"
    case peanutAllergy = "Peanut allergy"
    case lactoseSensitive = "Lactose sensitive"
    case glutenFree = "Gluten-free"
    case noPalmOil = "No palm oil"
    case jain = "Jain"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .vegetarian: "leaf"
        case .vegan: "leaf.fill"
        case .lowSugar: "cube"
        case .lowSodium: "drop"
        case .highProtein: "bolt"
        case .peanutAllergy: "exclamationmark.triangle"
        case .lactoseSensitive: "mug"
        case .glutenFree: "circle.slash"
        case .noPalmOil: "tree"
        case .jain: "hand.raised"
        }
    }

    static func decode(_ raw: String) -> Set<DietaryPreference> {
        Set(raw.split(separator: ",").compactMap { DietaryPreference(rawValue: String($0)) })
    }

    static func encode(_ set: Set<DietaryPreference>) -> String {
        allCases.filter(set.contains).map(\.rawValue).joined(separator: ",")
    }
}

enum Threshold {
    static let sugarHigh = 22.5, sugarLow = 5.0
    static let sodiumHigh = 600.0, sodiumLow = 120.0
    static let proteinHigh = 10.0
}

struct PersonalCheck: Identifiable, Hashable {
    enum Status { case good, caution, avoid, unknown }
    let preference: DietaryPreference
    let status: Status
    let message: String
    var id: String { preference.rawValue }

    static func run(_ prefs: Set<DietaryPreference>, on p: Product) -> [PersonalCheck] {
        let text = p.ingredientText
        return DietaryPreference.allCases.filter(prefs.contains).map { pref in
            let (status, message) = evaluate(pref, p, text)
            return PersonalCheck(preference: pref, status: status, message: message)
        }
    }

    private static func evaluate(_ pref: DietaryPreference, _ p: Product, _ text: String) -> (Status, String) {
        switch pref {
        case .vegetarian:
            if p.labels?.contains("vegetarian") == true { return (.good, "Certified vegetarian") }
            switch p.isVegetarian {
            case true: return (.good, "Vegetarian")
            case false: return (.avoid, "Not vegetarian")
            default: return (.unknown, "Vegetarian status unknown")
            }
        case .vegan:
            if p.labels?.contains("vegan") == true { return (.good, "Certified vegan") }
            switch p.isVegan {
            case true: return (.good, "Vegan")
            case false: return (.avoid, "Not vegan")
            default: return (.unknown, "Vegan status unknown")
            }
        case .lowSugar:
            return level(p, "sugar", p.nutrition.sugar, Threshold.sugarHigh, Threshold.sugarLow, "sugar", "g/100g")
        case .lowSodium:
            return level(p, "sodium", p.nutrition.sodiumMg, Threshold.sodiumHigh, Threshold.sodiumLow, "sodium", "mg/100g")
        case .highProtein:
            guard let pr = p.nutrition.protein else { return (.unknown, "No protein data") }
            return pr >= Threshold.proteinHigh
                ? (.good, "High protein · \(pr.compact) g/100g")
                : (.caution, "Not a protein source · \(pr.compact) g/100g")
        case .peanutAllergy:
            return allergen(p, text, slugs: ["peanut", "groundnut"], keywords: ["peanut", "groundnut", "arachis"], name: "peanuts")
        case .lactoseSensitive:
            return allergen(p, text, slugs: ["milk", "lactose"],
                            keywords: ["milk", "lactose", "whey", "casein", "butter", "cream", "cheese", "ghee", "curd", "yogurt", "yoghurt", "paneer"],
                            name: "dairy", present: .caution)
        case .glutenFree:
            if p.labels?.contains(where: { $0.contains("gluten-free") }) == true {
                return (.good, "Certified gluten-free")
            }
            return allergen(p, text, slugs: ["gluten", "wheat"],
                            keywords: ["wheat", "gluten", "barley", "rye", "maida", "semolina", "suji", "atta", "malt"],
                            name: "gluten")
        case .noPalmOil:
            if p.labels?.contains(where: { $0.contains("palm-oil-free") }) == true {
                return (.good, "Certified palm oil free")
            }
            switch p.isPalmOilFree {
            case true: return (.good, "Palm oil free")
            case false: return (.avoid, "Contains palm oil")
            default:
                guard !text.isEmpty else { return (.unknown, "Ingredients not listed") }
                return mentions(text, "palm") ? (.avoid, "Contains palm oil") : (.good, "No palm oil listed")
            }
        case .jain:
            if p.isVegetarian == false { return (.avoid, "Not vegetarian") }
            guard !text.isEmpty else { return (.unknown, "Ingredients not listed") }
            let roots = ["onion", "garlic", "potato", "carrot", "radish", "beetroot", "ginger", "turnip"]
            return roots.contains(where: { mentions(text, $0) })
                ? (.caution, "Has root vegetables or onion/garlic")
                : (.good, "No root vegetables or onion/garlic listed")
        }
    }

    private static func allergen(
        _ p: Product, _ text: String, slugs: [String], keywords: [String], name: String,
        present: Status = .avoid
    ) -> (Status, String) {
        if let declared = p.allergens {
            if declared.contains(where: { tag in slugs.contains { tag.contains($0) } }) {
                return (present, "Contains \(name)")
            }
            if (p.traces ?? []).contains(where: { tag in slugs.contains { tag.contains($0) } }) {
                return (.caution, "May contain \(name)")
            }
            return (.good, "No \(name) declared")
        }
        guard !text.isEmpty else { return (.unknown, "Ingredients not listed") }
        return keywords.contains(where: { mentions(text, $0) })
            ? (present, "Contains \(name)")
            : (.good, "No \(name) listed")
    }

    private static func mentions(_ text: String, _ word: String) -> Bool {
        guard text.contains(word) else { return false }
        let negations = ["\(word) free", "\(word)-free", "no \(word)", "\(word)free"]
        return !negations.contains { text.contains($0) }
    }

    private static func level(
        _ p: Product, _ key: String, _ value: Double?, _ high: Double, _ low: Double,
        _ name: String, _ unit: String
    ) -> (Status, String) {
        let shown = value.map { key == "sodium" ? "\(Int($0)) \(unit)" : "\($0.compact) \(unit)" }
        switch p.nutrientLevels?[key] {
        case "high": return (.avoid, "High \(name)\(shown.map { " · \($0)" } ?? "")")
        case "low": return (.good, "Low \(name)\(shown.map { " · \($0)" } ?? "")")
        case "moderate": return (.caution, "Moderate \(name)\(shown.map { " · \($0)" } ?? "")")
        default: break
        }
        guard let value, let shown else { return (.unknown, "No \(name) data") }
        if value >= high { return (.avoid, "High \(name) · \(shown)") }
        if value <= low { return (.good, "Low \(name) · \(shown)") }
        return (.caution, "Moderate \(name) · \(shown)")
    }
}

extension PersonalCheck.Status {
    var color: Color {
        switch self {
        case .good: TL.good
        case .caution: TL.warn
        case .avoid: TL.danger
        case .unknown: TL.fg3
        }
    }
    var icon: String {
        switch self {
        case .good: "checkmark.circle.fill"
        case .caution: "exclamationmark.circle.fill"
        case .avoid: "xmark.octagon.fill"
        case .unknown: "questionmark.circle"
        }
    }

    var rank: Int {
        switch self {
        case .avoid: 0
        case .caution: 1
        case .unknown: 2
        case .good: 3
        }
    }
}
