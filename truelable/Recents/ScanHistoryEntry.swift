//
//  ScanHistoryEntry.swift
//  truelable
//

import Foundation
import SwiftData

/// One scanned product, recorded the moment a lookup resolves (see
/// `ProductFoundFlow`'s `.onAppear`) — SwiftData, not a hand-rolled
/// UserDefaults array: native persistence, a real query engine for
/// "recent N" and dedup, and it's already on this deployment target.
///
/// Snapshots the handful of fields `RecentsView`/`CompareView` actually
/// need at scan time, rather than re-fetching from the network for every
/// comparison — offline-capable, and a product's label doesn't change
/// often enough for staleness to matter here.
@Model
final class ScanHistoryEntry {
    var barcode: String
    var name: String
    var brand: String
    var scannedAt: Date
    var calories: Int
    var sugarGrams: Double?
    var sodiumMg: Double?
    var nutriscoreGrade: String?
    var novaGroup: Int?
    var isVegetarian: Bool?

    init(product: ProductInfo, scannedAt: Date = .now) {
        self.barcode = product.barcode
        self.name = product.name
        self.brand = product.brand
        self.scannedAt = scannedAt
        self.calories = product.calories
        self.sugarGrams = product.sugarGrams
        self.sodiumMg = product.sodiumMg
        self.nutriscoreGrade = product.nutriscoreGrade
        self.novaGroup = product.novaGroup
        self.isVegetarian = product.isVegetarian
    }
}
