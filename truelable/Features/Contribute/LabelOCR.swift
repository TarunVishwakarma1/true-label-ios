//
//  LabelOCR.swift
//  truelable
//
//  Turns captured takes (front / ingredients / nutrition) into a draft the
//  user reviews. Mirrors the backend's parse of the ingredient side
//  (services/ocr_service.rs); the server re-parses the raw text itself.
//

import Foundation

enum LabelOCR {
    struct Draft: Equatable {
        var name: String
        var brand: String
        /// Largest text on the front of the pack, biggest first — the brand
        /// mark is usually stylised or in another script, so the user picks
        /// rather than the parser guessing.
        var nameCandidates: [String]
        var ingredients: String
        var allergens: [String]
        var nutrition: Nutrition
        var rawText: String
    }

    static func draft(front: TextTake?, ingredients: TextTake, nutrition: TextTake?) -> Draft {
        let candidates = frontCandidates(front)
        let raw = [front?.raw, ingredients.raw, nutrition?.raw].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n")
        return Draft(
            name: candidates.dropFirst().first ?? candidates.first ?? guessName(ingredients.raw),
            brand: candidates.first ?? "",
            nameCandidates: candidates,
            ingredients: parseIngredients(ingredients.raw),
            allergens: detectAllergens(ingredients.raw),
            nutrition: nutrition.map { NutritionParser.parse($0.raw) } ?? Nutrition(),
            rawText: raw
        )
    }

    /// Distinct front-of-pack lines by height, skipping numbers, weights
    /// and marketing fluff too long to be a name.
    static func frontCandidates(_ take: TextTake?) -> [String] {
        guard let take else { return [] }
        var out: [String] = []
        for line in take.lines.sorted(by: { $0.height > $1.height }) {
            let t = line.text.trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))
            guard t.count >= 2, t.count <= 40, t.rangeOfCharacter(from: .letters) != nil,
                  !isWeight(t), !out.contains(where: { $0.caseInsensitiveCompare(t) == .orderedSame }) else { continue }
            out.append(t)
            if out.count == 5 { break }
        }
        return out
    }

    private static func isWeight(_ s: String) -> Bool {
        (try? /^\d+(?:[.,]\d+)?\s*(?:g|kg|ml|l|gm|gms)$/.ignoresCase().wholeMatch(in: s)) != nil
    }

    // MARK: Heuristics (mirror the backend)

    private static let boundaries = [
        "contains", "may contain", "allergen", "manufactured", "distributed by",
        "storage", "best before", "net wt", "nutrition facts", "nutritional information"
    ]

    private static let allergens = [
        "milk", "wheat", "soy", "soya", "peanut", "peanuts", "tree nut", "tree nuts",
        "egg", "eggs", "fish", "shellfish", "sesame", "gluten", "mustard", "celery",
        "lupin", "sulphites", "sulfites"
    ]

    static func parseIngredients(_ raw: String) -> String {
        var body = raw
        if let label = raw.range(of: "ingredients", options: .caseInsensitive),
           let colon = raw.range(of: ":", range: label.upperBound..<raw.endIndex) {
            body = String(raw[colon.upperBound...])
        }
        if let cut = boundaries.compactMap({ body.range(of: $0, options: .caseInsensitive) }).min(by: { $0.lowerBound < $1.lowerBound }) {
            body = String(body[..<cut.lowerBound])
        }
        return body
            .split(whereSeparator: { $0 == "," || $0.isNewline })
            .map { $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: ".")) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    static func detectAllergens(_ raw: String) -> [String] {
        let lower = raw.lowercased()
        return Array(Set(allergens.filter { lower.contains($0) }.map { $0.prefix(1).uppercased() + $0.dropFirst() })).sorted()
    }

    static func guessName(_ raw: String) -> String {
        raw.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty && !$0.lowercased().hasPrefix("ingredient") } ?? ""
    }
}
