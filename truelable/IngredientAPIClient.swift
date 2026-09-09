//
//  IngredientAPIClient.swift
//  truelable
//

import UIKit

enum IngredientAPIClient {
    /// TODO: point this at the real OCR/extraction endpoint. Stubbed with a
    /// short delay (simulating a server round-trip) and fabricated data so
    /// the review screen has something real to show against.
    static func extractIngredients(image: UIImage) async throws -> ExtractedProductData {
        try await Task.sleep(for: .seconds(1.5))
        return ExtractedProductData(
            guessedName: "Unnamed Snack Product",
            ingredients: "Wheat Flour, Palm Oil, Sugar, Salt, Raising Agents (INS 503(ii)), Emulsifiers (INS 322), Spices & Condiments",
            allergens: ["Wheat", "Milk"]
        )
    }

    /// TODO: point this at the real submission endpoint.
    static func submitContribution(barcode: String, data: ExtractedProductData) async throws -> Bool {
        try await Task.sleep(for: .seconds(1))
        return true
    }
}
