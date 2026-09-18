import Foundation
import SwiftData

@Model
final class ScanRecord {
    @Attribute(.unique) var barcode: String
    var name: String
    var brand: String
    var imageURL: URL?
    var scannedAt: Date
    var scanCount: Int
    var calories: Int?
    var sugarGrams: Double?
    var sodiumMg: Double?
    var proteinGrams: Double?
    var nutriscoreGrade: String?
    var novaGroup: Int?
    var verified: Bool
    var snapshot: Data

    @MainActor
    init(product: Product, at date: Date = .now) {
        barcode = product.barcode
        name = product.name
        brand = product.brand ?? ""
        imageURL = product.imageURL
        scannedAt = date
        scanCount = 1
        calories = product.calories
        sugarGrams = product.nutrition.sugar
        sodiumMg = product.nutrition.sodiumMg
        proteinGrams = product.nutrition.protein
        nutriscoreGrade = product.nutriscoreGrade
        novaGroup = product.novaGroup
        verified = product.verified
        snapshot = (try? JSONEncoder().encode(product)) ?? Data()
    }

    @MainActor
    var product: Product? {
        try? JSONDecoder().decode(Product.self, from: snapshot)
    }

    @MainActor
    func refresh(with product: Product, bump: Bool) {
        name = product.name
        brand = product.brand ?? ""
        imageURL = product.imageURL
        calories = product.calories
        sugarGrams = product.nutrition.sugar
        sodiumMg = product.nutrition.sodiumMg
        proteinGrams = product.nutrition.protein
        nutriscoreGrade = product.nutriscoreGrade
        novaGroup = product.novaGroup
        verified = product.verified
        snapshot = (try? JSONEncoder().encode(product)) ?? snapshot
        if bump {
            scannedAt = .now
            scanCount += 1
        }
    }

    @MainActor
    static func record(_ product: Product, in context: ModelContext, bump: Bool = true, createIfMissing: Bool = true) {
        let barcode = product.barcode
        let existing = try? context.fetch(FetchDescriptor<ScanRecord>(predicate: #Predicate { $0.barcode == barcode })).first
        if let existing {
            existing.refresh(with: product, bump: bump)
        } else if createIfMissing {
            context.insert(ScanRecord(product: product))
        }
    }
}
