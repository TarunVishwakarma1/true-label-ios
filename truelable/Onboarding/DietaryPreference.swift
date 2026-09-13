//
//  DietaryPreference.swift
//  truelable
//

import Foundation

/// Shared between onboarding's preference step and the Health screen —
/// same 8 options, same stored state, edited from either place.
///
/// The design mockup this is built from ships several of these ON by
/// default (e.g. "Peanut allergy"). That's fine as mockup filler but wrong
/// as real behavior — defaulting an allergy flag on for someone who
/// doesn't have it is a real safety-adjacent UX mistake, not a style
/// choice. Every option here starts OFF; the user opts in explicitly.
enum DietaryPreference: String, CaseIterable, Identifiable {
    case vegetarian = "Vegetarian"
    case peanutAllergy = "Peanut allergy"
    case noPalmOil = "No palm oil"
    case lactoseSensitive = "Lactose sensitive"
    case lowSugar = "Low sugar"
    case highProtein = "High protein"
    case jain = "Jain"
    case glutenFree = "Gluten-free"

    var id: String { rawValue }

    private static let storageKey = "dietaryPreferences.enabled"

    static func loadEnabled() -> Set<DietaryPreference> {
        let raw = UserDefaults.standard.stringArray(forKey: storageKey) ?? []
        return Set(raw.compactMap(DietaryPreference.init(rawValue:)))
    }

    static func save(_ enabled: Set<DietaryPreference>) {
        UserDefaults.standard.set(enabled.map(\.rawValue), forKey: storageKey)
    }
}
