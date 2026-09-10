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
