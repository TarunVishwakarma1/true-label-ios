//
//  NutritionParser.swift
//  truelable
//
//  Turns OCR'd nutrition-table text into per-100g numbers. Line-based, so
//  it survives the usual OCR damage: labels and values on separate lines,
//  two columns (per 100 g first, per serving second), kJ-only energy, salt
//  instead of sodium. Anything it can't read stays nil.
//

import Foundation

enum NutritionParser {
    static func parse(_ text: String) -> Nutrition {
        var n = Nutrition()
        let lines = text.split(whereSeparator: \.isNewline).map { String($0).trimmingCharacters(in: .whitespaces) }
        var salt: Double?

        for (i, raw) in lines.enumerated() {
            let line = raw.lowercased()
            let next = i + 1 < lines.count ? lines[i + 1] : ""

            if line.contains("energy") || line.contains("calorie") || line.contains("kcal") {
                if n.energyKcal == nil { n.energyKcal = energy(in: raw + " " + next) }
                continue
            }
            let value = firstNumber(in: raw, fallback: next)
            guard let value else { continue }
            let mg = line.contains("mg")

            if line.contains("saturat") {
                if n.saturatedFat == nil { n.saturatedFat = value }
            } else if line.contains("trans") {
                if n.transFat == nil { n.transFat = value }
            } else if line.contains("fat") {
                if n.fat == nil { n.fat = value }
            } else if line.contains("sugar") {
                if n.sugar == nil { n.sugar = value }
            } else if line.contains("carbohydrate") || line.contains("carbs") {
                if n.carbs == nil { n.carbs = value }
            } else if line.contains("fibre") || line.contains("fiber") {
                if n.fiber == nil { n.fiber = value }
            } else if line.contains("protein") {
                if n.protein == nil { n.protein = value }
            } else if line.contains("sodium") {
                if n.sodium == nil { n.sodium = mg ? value / 1000 : value }
            } else if line.contains("salt") {
                if salt == nil { salt = mg ? value / 1000 : value }
            } else if line.contains("cholesterol") {
                if n.cholesterol == nil { n.cholesterol = mg ? value / 1000 : value }
            }
        }

        // Salt is 40% sodium by mass; labels in India/EU print salt.
        if n.sodium == nil, let salt { n.sodium = (salt * 0.4 * 1000).rounded() / 1000 }
        return n
    }

    /// kcal if present anywhere; else the first number, converted from kJ.
    private static func energy(in text: String) -> Double? {
        let lower = text.lowercased()
        if let kcal = try? /(\d+(?:[.,]\d+)?)\s*kcal/.firstMatch(in: lower) {
            return number(kcal.1)
        }
        if let kj = try? /(\d+(?:[.,]\d+)?)\s*kj/.firstMatch(in: lower), let v = number(kj.1) {
            return (v / 4.184).rounded()
        }
        guard let v = firstNumber(in: text, fallback: "") else { return nil }
        return v > 900 ? (v / 4.184).rounded() : v   // no unit: >900 per 100 g is almost certainly kJ
    }

    /// First number after the label's letters; if the line has none, the
    /// leading number of the next line (OCR often splits label and value).
    private static func firstNumber(in line: String, fallback: String) -> Double? {
        let stripped = line.drop(while: { !$0.isNumber })
        if let m = try? /(\d+(?:[.,]\d+)?)/.firstMatch(in: stripped) { return number(m.1) }
        let next = fallback.trimmingCharacters(in: .whitespaces)
        if let m = try? /^(\d+(?:[.,]\d+)?)/.firstMatch(in: next) { return number(m.1) }
        return nil
    }

    private static func number(_ s: Substring) -> Double? {
        Double(s.replacingOccurrences(of: ",", with: "."))
    }
}
