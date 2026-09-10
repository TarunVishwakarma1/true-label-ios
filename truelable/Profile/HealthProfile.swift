//
//  HealthProfile.swift
//  truelable
//

import Foundation

/// A nutrient the user has asked the app to watch for them. Sugar and
/// sodium only for now — matches the website's reference exactly, no
/// scope creep to other nutrients yet.
enum WatchedNutrient: String, CaseIterable, Identifiable {
    case sugar = "Sugar"
    case sodium = "Sodium"

    var id: String { rawValue }

    /// The `nutrition_facts` JSON key / backend `sort_by` query value.
    var apiKey: String {
        switch self {
        case .sugar: return "sugar"
        case .sodium: return "sodium"
        }
    }

    /// UK FSA traffic-light "high" threshold per 100g — a real, published
    /// nutrient-profiling reference, not a number invented for this app.
    /// Sodium's is derived from the FSA's salt threshold (1.5g/100g ÷ 2.5).
    var highThresholdPer100g: Double {
        switch self {
        case .sugar: return 22.5
        case .sodium: return 600 // mg
        }
    }

    func isHigh(_ amountPer100g: Double) -> Bool {
        amountPer100g >= highThresholdPer100g
    }
}

/// Local-only, on-device preference — no backend involved. The website
/// marks this a Premium feature, but this app has no StoreKit/IAP
/// integration yet, so gating it behind a fake paywall would be theater;
/// it ships free and functional until real subscription gating exists.
enum HealthProfile {
    @MainActor
    static var watchingSugar: Bool {
        get { UserDefaults.standard.bool(forKey: "healthProfile.watchingSugar") }
        set { UserDefaults.standard.set(newValue, forKey: "healthProfile.watchingSugar") }
    }

    @MainActor
    static var watchingSodium: Bool {
        get { UserDefaults.standard.bool(forKey: "healthProfile.watchingSodium") }
        set { UserDefaults.standard.set(newValue, forKey: "healthProfile.watchingSodium") }
    }

    @MainActor
    static var isActive: Bool { watchingSugar || watchingSodium }

    /// Which nutrient takes priority when more than one is watched — sugar
    /// first, matching the reference's Meera example.
    @MainActor
    static var primaryWatch: WatchedNutrient? {
        if watchingSugar { return .sugar }
        if watchingSodium { return .sodium }
        return nil
    }
}
