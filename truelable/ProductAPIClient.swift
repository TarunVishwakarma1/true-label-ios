//
//  ProductAPIClient.swift
//  truelable
//

import Foundation

enum ProductAPIClient {
    /// TODO: point this at the real endpoint once it exists. `nil` means
    /// the barcode isn't in the catalogue. Stubbed with one deterministic
    /// "known" barcode so both the found/not-found flows are testable
    /// without a real backend.
    static func lookupProduct(barcode: String) async throws -> ProductInfo? {
        try await Task.sleep(for: .seconds(0.6))

        guard barcode == "0028400251488" else { return nil } // real, verified UPC/EAN checksum (Lay's Kettle Cooked chips)

        return ProductInfo(
            barcode: barcode,
            name: "Kettle Cooked Potato Chips",
            brand: "Lay's",
            servingSize: "28g (about 13 chips)",
            calories: 150,
            nutrients: [
                Nutrient(name: "Total Fat", amount: "9g", dailyValuePercent: 12),
                Nutrient(name: "Saturated Fat", amount: "1g", dailyValuePercent: 5),
                Nutrient(name: "Sodium", amount: "135mg", dailyValuePercent: 6),
                Nutrient(name: "Total Carbohydrate", amount: "16g", dailyValuePercent: 6),
                Nutrient(name: "Dietary Fiber", amount: "1g", dailyValuePercent: 4),
                Nutrient(name: "Sugars", amount: "0g", dailyValuePercent: nil),
                Nutrient(name: "Protein", amount: "2g", dailyValuePercent: nil)
            ],
            ingredients: "Potatoes, Vegetable Oil, Salt"
        )
    }
}
