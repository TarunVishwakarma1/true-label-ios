//
//  ProductInfo.swift
//  truelable
//

import Foundation

struct ProductInfo: Identifiable, Equatable {
    var id: String { barcode }
    var barcode: String
    var name: String
    var brand: String
    var servingSize: String
    var calories: Int
    var nutrients: [Nutrient]
    var ingredients: String
    var allergens: String = ""
    /// E-numbers, e.g. "E150D" — empty doesn't distinguish "none" from
    /// "unknown"; the backend only ever sends entries it's actually found.
    var additives: [String] = []
    /// NOVA processing classification, 1 (unprocessed) – 4 (ultra-processed).
    var novaGroup: Int?
    /// Open Food Facts' overall nutrition grade, "a"–"e".
    var nutriscoreGrade: String?
    /// Tri-state: `nil` means "the source doesn't have a definitive answer",
    /// not "no" — never treat a missing badge as a negative claim.
    var isVegan: Bool?
    var isVegetarian: Bool?
    var isPalmOilFree: Bool?
    var verified: Bool = false
    var verificationCount: Int = 0
    /// Raw grams/milligrams per 100g, threaded through separately from
    /// `nutrients` (whose `amount` is a pre-formatted display string) so
    /// the teaspoons visualization and health-profile flagging have real
    /// numbers to do math on.
    var sugarGrams: Double?
    var sodiumMg: Double?
    var fatGrams: Double?
    var carbsGrams: Double?
    var proteinGrams: Double?

    /// A derived 0–100 estimate from real published signals (Nutri-Score
    /// grade + NOVA processing group) — not an official industry number,
    /// so it's always shown with the "estimated from…" caption
    /// (`HealthScoreCard`) rather than presented as authoritative. `nil`
    /// when neither input exists, rather than guessing.
    var estimatedHealthScore: Int? {
        guard nutriscoreGrade != nil || novaGroup != nil else { return nil }
        var score = 100
        switch nutriscoreGrade?.lowercased() {
        case "a": break
        case "b": score -= 10
        case "c": score -= 25
        case "d": score -= 40
        case "e": score -= 55
        default: break
        }
        switch novaGroup {
        case 2: score -= 5
        case 3: score -= 10
        case 4: score -= 15
        default: break
        }
        return max(0, min(100, score))
    }

    var healthVerdict: (headline: String, color: HealthVerdictColor)? {
        guard let score = estimatedHealthScore else { return nil }
        switch score {
        case 80...: return ("A genuinely good pick", .good)
        case 60..<80: return ("Fine now and then", .fair)
        case 40..<60: return ("Worth a second look", .fair)
        default: return ("Better as a rare treat", .poor)
        }
    }
}

enum HealthVerdictColor {
    case good, fair, poor
}

struct Nutrient: Identifiable, Equatable {
    var id: String { name }
    var name: String
    var amount: String
    var dailyValuePercent: Int?
}

/// What comes back from on-device OCR of an ingredient-label photo, for the
/// user to confirm before it's submitted. `rawText` is the unparsed Vision
/// recognition output, carried along so the final submission re-parses from
/// the source of truth server-side rather than trusting this preview twice.
struct ExtractedProductData: Equatable {
    var guessedName: String
    var ingredients: String
    var allergens: [String]
    var rawText: String
}
