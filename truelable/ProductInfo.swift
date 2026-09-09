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
}

struct Nutrient: Identifiable, Equatable {
    var id: String { name }
    var name: String
    var amount: String
    var dailyValuePercent: Int?
}

/// What comes back from the (stubbed) ingredient-photo analysis, for the
/// user to confirm before it's submitted.
struct ExtractedProductData: Equatable {
    var guessedName: String
    var ingredients: String
    var allergens: [String]
}
