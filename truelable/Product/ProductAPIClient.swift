//
//  ProductAPIClient.swift
//  truelable
//

import Foundation
import UIKit

enum ProductAPIClient {
    /// `nil` means either the barcode isn't in the catalogue (backend 404)
    /// or the request failed outright — both collapse to the same
    /// "not found" screen at the call site in ScannerView, matching how
    /// this client has always signaled "nothing to show" here.
    static func lookupProduct(barcode: String) async throws -> ProductInfo? {
        let country = currentCountry()

        var components = URLComponents(
            url: APIEnvironment.baseURL.appendingPathComponent("/api/v1/products/search"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "barcode", value: barcode),
            URLQueryItem(name: "country", value: country)
        ]

        let (data, response) = try await URLSession.shared.data(from: components.url!)
        guard let http = response as? HTTPURLResponse else { return nil }

        if http.statusCode == 404 {
            return nil
        }
        guard (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let envelope = try decoder.decode(ApiEnvelope<ProductResponseDTO>.self, from: data)
        guard let dto = envelope.data else { return nil }

        return dto.asProductInfo(barcode: barcode)
    }

    /// Records a community confirmation against the real, already-existing
    /// `/api/v1/products/verify` endpoint (not the `/api/v1/verifications/
    /// submit` route, which is an unimplemented placeholder on the backend
    /// today) and returns the product with its refreshed verified/count.
    static func submitVerification(barcode: String) async throws -> ProductInfo {
        let country = currentCountry()
        let deviceID = UIDevice.current.identifierForVendor?.uuidString

        var request = URLRequest(
            url: APIEnvironment.baseURL.appendingPathComponent("/api/v1/products/verify")
        )
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            VerifyRequestBody(barcode: barcode, country: country, deviceId: deviceID)
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let envelope = try decoder.decode(ApiEnvelope<ProductResponseDTO>.self, from: data)
        guard let dto = envelope.data else { throw URLError(.cannotParseResponse) }

        return dto.asProductInfo(barcode: barcode)
    }

    /// Same-category products cheapest-first on `sortBy` ("sugar" or
    /// "sodium"). Empty is a legitimate answer — no category match, or this
    /// product has no category on file yet — never fabricated.
    static func fetchAlternatives(barcode: String, sortBy: String) async throws -> [ProductAlternative] {
        let country = currentCountry()

        var components = URLComponents(
            url: APIEnvironment.baseURL.appendingPathComponent("/api/v1/products/alternatives"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "barcode", value: barcode),
            URLQueryItem(name: "country", value: country),
            URLQueryItem(name: "sort_by", value: sortBy)
        ]

        let (data, response) = try await URLSession.shared.data(from: components.url!)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let envelope = try decoder.decode(ApiEnvelope<[ProductAlternative]>.self, from: data)
        return envelope.data ?? []
    }

    private static func currentCountry() -> String {
        Locale.current.region?.identifier ?? "US"
    }
}

private struct VerifyRequestBody: Encodable {
    var barcode: String
    var country: String
    var deviceId: String?
}

struct ProductAlternative: Decodable, Identifiable {
    var id: String { barcode }
    var barcode: String
    var productName: String
    var sortValue: Double?
}

private struct ApiEnvelope<T: Decodable>: Decodable {
    var status: String
    var data: T?
}

private struct ProductResponseDTO: Decodable {
    var productName: String
    var brand: String?
    var nutritionFacts: NutritionFactsDTO
    var ingredients: String?
    var allergens: String?
    var additives: [String]?
    var novaGroup: Int?
    var nutriscoreGrade: String?
    var isVegan: Bool?
    var isVegetarian: Bool?
    var isPalmOilFree: Bool?
    var verified: Bool?
    var verificationCount: Int?

    /// Open Food Facts' `nutriments` (what the backend passes through) are
    /// per-100g figures, not per-serving — labeling this "1 serving" would
    /// be flatly wrong, so this says what the numbers actually represent.
    func asProductInfo(barcode: String) -> ProductInfo {
        ProductInfo(
            barcode: barcode,
            name: productName,
            brand: brand ?? "",
            servingSize: "Per 100g",
            calories: Int((nutritionFacts.energyKcal ?? 0).rounded()),
            nutrients: nutritionFacts.asNutrients(),
            ingredients: ingredients ?? "",
            allergens: allergens ?? "",
            additives: additives ?? [],
            novaGroup: novaGroup,
            nutriscoreGrade: nutriscoreGrade,
            isVegan: isVegan,
            isVegetarian: isVegetarian,
            isPalmOilFree: isPalmOilFree,
            verified: verified ?? false,
            verificationCount: verificationCount ?? 0,
            sugarGrams: nutritionFacts.sugar,
            sodiumMg: nutritionFacts.sodium.map { $0 * 1000 }
        )
    }
}

private struct NutritionFactsDTO: Decodable {
    var energyKcal: Double?
    var protein: Double?
    var carbs: Double?
    var fat: Double?
    var saturatedFat: Double?
    var transFat: Double?
    var fiber: Double?
    var sugar: Double?
    /// Grams, per OFF convention — converted to mg in `asNutrients()` to
    /// match how sodium is normally shown on a nutrition label.
    /// Grams, per OFF convention, same as `sodium` — converted to mg below.
    var sodium: Double?
    var cholesterol: Double?
    var potassium: Double?
    var calcium: Double?
    var iron: Double?

    func asNutrients() -> [Nutrient] {
        [
            fat.map { Nutrient(name: "Total Fat", amount: "\(Self.trimmed($0))g", dailyValuePercent: nil) },
            saturatedFat.map { Nutrient(name: "Saturated Fat", amount: "\(Self.trimmed($0))g", dailyValuePercent: nil) },
            transFat.map { Nutrient(name: "Trans Fat", amount: "\(Self.trimmed($0))g", dailyValuePercent: nil) },
            cholesterol.map { Nutrient(name: "Cholesterol", amount: "\(Self.milligrams($0))mg", dailyValuePercent: nil) },
            sodium.map { Nutrient(name: "Sodium", amount: "\(Self.milligrams($0))mg", dailyValuePercent: nil) },
            carbs.map { Nutrient(name: "Total Carbohydrate", amount: "\(Self.trimmed($0))g", dailyValuePercent: nil) },
            fiber.map { Nutrient(name: "Dietary Fiber", amount: "\(Self.trimmed($0))g", dailyValuePercent: nil) },
            sugar.map { Nutrient(name: "Sugars", amount: "\(Self.trimmed($0))g", dailyValuePercent: nil) },
            protein.map { Nutrient(name: "Protein", amount: "\(Self.trimmed($0))g", dailyValuePercent: nil) },
            potassium.map { Nutrient(name: "Potassium", amount: "\(Self.milligrams($0))mg", dailyValuePercent: nil) },
            calcium.map { Nutrient(name: "Calcium", amount: "\(Self.milligrams($0))mg", dailyValuePercent: nil) },
            iron.map { Nutrient(name: "Iron", amount: "\(Self.milligrams($0))mg", dailyValuePercent: nil) }
        ].compactMap { $0 }
    }

    private static func trimmed(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(format: "%.1f", value)
    }

    private static func milligrams(_ grams: Double) -> Int {
        Int((grams * 1000).rounded())
    }
}

