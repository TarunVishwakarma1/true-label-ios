//
//  Product.swift
//  truelable
//
//  The one product model: decoded straight from the backend's
//  `ProductResponse`, snapshotted as-is into scan history (`ScanRecord`),
//  and rendered everywhere. Codable keys match the API's snake_case fields
//  after `convertFromSnakeCase`.
//

import Foundation

struct Product: Codable, Hashable, Identifiable, Sendable {
    var id: String { barcode }

    let barcode: String
    let name: String
    let brand: String?
    let imageURL: URL?
    let category: String?
    let source: String
    var verified: Bool
    var verificationCount: Int
    let nutrition: Nutrition
    let ingredients: String?
    /// Slugs as the source publishes them: `"peanuts"`, `"gluten"`. `nil`
    /// means the source doesn't publish allergens at all, `[]` means it
    /// publishes "none" — never treat the first as the second.
    let allergens: [String]?
    /// "May contain". A trace is not an ingredient, and for an allergy it is
    /// the line that matters most.
    let traces: [String]?
    /// Certifications: `"gluten-free"`, `"organic"`, `"vegan"`.
    let labels: [String]?
    let additives: [String]
    let quantity: String?
    let servingSize: String?
    let servingQuantity: Double?
    /// The same figures scaled to one serving, computed server-side from the
    /// serving quantity. Absent when the pack doesn't state one.
    let nutritionPerServing: Nutrition?
    /// `["sugar": "high", ...]` — the source's own traffic light where it
    /// publishes one, the FSA thresholds where it doesn't.
    let nutrientLevels: [String: String]?
    let nutriscoreScore: Int?
    let ecoscoreGrade: String?
    let novaGroup: Int?
    let nutriscoreGrade: String?
    /// Tri-state: `nil` is "source doesn't know", never "no".
    let isVegan: Bool?
    let isVegetarian: Bool?
    let isPalmOilFree: Bool?

    enum CodingKeys: String, CodingKey {
        case barcode
        case name = "productName"
        case brand
        case imageURL = "imageUrl"
        case category, source, verified, verificationCount
        case nutrition = "nutritionFacts"
        case nutritionPerServing, nutrientLevels
        case ingredients, allergens, traces, labels, additives
        case quantity, servingSize, servingQuantity
        case novaGroup, nutriscoreGrade, nutriscoreScore, ecoscoreGrade
        case isVegan, isVegetarian, isPalmOilFree
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        barcode = try c.decode(String.self, forKey: .barcode)
        name = try c.decodeIfPresent(String.self, forKey: .name)?.nilIfBlank ?? "Unknown product"
        brand = try c.decodeIfPresent(String.self, forKey: .brand)?.nilIfBlank
        imageURL = try c.decodeIfPresent(String.self, forKey: .imageURL).flatMap(URL.init(string:))
        category = try c.decodeIfPresent(String.self, forKey: .category)
        source = try c.decodeIfPresent(String.self, forKey: .source) ?? "unknown"
        verified = try c.decodeIfPresent(Bool.self, forKey: .verified) ?? false
        verificationCount = try c.decodeIfPresent(Int.self, forKey: .verificationCount) ?? 0
        nutrition = try c.decodeIfPresent(Nutrition.self, forKey: .nutrition) ?? Nutrition()
        ingredients = try c.decodeIfPresent(String.self, forKey: .ingredients)?.nilIfBlank
        allergens = try c.decodeIfPresent([String].self, forKey: .allergens)
        traces = try c.decodeIfPresent([String].self, forKey: .traces)
        labels = try c.decodeIfPresent([String].self, forKey: .labels)
        additives = try c.decodeIfPresent([String].self, forKey: .additives) ?? []
        quantity = try c.decodeIfPresent(String.self, forKey: .quantity)?.nilIfBlank
        servingSize = try c.decodeIfPresent(String.self, forKey: .servingSize)?.nilIfBlank
        servingQuantity = try c.decodeIfPresent(Double.self, forKey: .servingQuantity)
        nutritionPerServing = try c.decodeIfPresent(Nutrition.self, forKey: .nutritionPerServing)
        nutrientLevels = try c.decodeIfPresent([String: String].self, forKey: .nutrientLevels)
        nutriscoreScore = try c.decodeIfPresent(Int.self, forKey: .nutriscoreScore)
        ecoscoreGrade = try c.decodeIfPresent(String.self, forKey: .ecoscoreGrade)?.nilIfBlank
        novaGroup = try c.decodeIfPresent(Int.self, forKey: .novaGroup)
        nutriscoreGrade = Nutriscore.letter(try c.decodeIfPresent(String.self, forKey: .nutriscoreGrade))
        isVegan = try c.decodeIfPresent(Bool.self, forKey: .isVegan)
        isVegetarian = try c.decodeIfPresent(Bool.self, forKey: .isVegetarian)
        isPalmOilFree = try c.decodeIfPresent(Bool.self, forKey: .isPalmOilFree)
    }

    init(barcode: String, name: String, brand: String? = nil, imageURL: URL? = nil, category: String? = nil,
         source: String = "open_food_facts", verified: Bool = false, verificationCount: Int = 0,
         nutrition: Nutrition = Nutrition(), ingredients: String? = nil, allergens: [String]? = nil,
         traces: [String]? = nil, labels: [String]? = nil,
         additives: [String] = [], quantity: String? = nil, servingSize: String? = nil,
         servingQuantity: Double? = nil, nutritionPerServing: Nutrition? = nil,
         nutrientLevels: [String: String]? = nil, novaGroup: Int? = nil,
         nutriscoreGrade: String? = nil, nutriscoreScore: Int? = nil, ecoscoreGrade: String? = nil,
         isVegan: Bool? = nil, isVegetarian: Bool? = nil, isPalmOilFree: Bool? = nil) {
        self.barcode = barcode; self.name = name; self.brand = brand; self.imageURL = imageURL
        self.category = category; self.source = source; self.verified = verified
        self.verificationCount = verificationCount; self.nutrition = nutrition
        self.ingredients = ingredients; self.allergens = allergens; self.traces = traces
        self.labels = labels; self.additives = additives; self.quantity = quantity
        self.servingSize = servingSize; self.servingQuantity = servingQuantity
        self.nutritionPerServing = nutritionPerServing; self.nutrientLevels = nutrientLevels
        self.novaGroup = novaGroup; self.nutriscoreGrade = nutriscoreGrade
        self.nutriscoreScore = nutriscoreScore; self.ecoscoreGrade = ecoscoreGrade
        self.isVegan = isVegan; self.isVegetarian = isVegetarian; self.isPalmOilFree = isPalmOilFree
    }

    // MARK: Derived

    var isCommunitySourced: Bool { source == "user_contributed" }

    var isBeverage: Bool {
        guard let cat = category?.lowercased() else { return false }
        return cat.contains("beverage") || cat.contains("drink") || cat.contains("soda") || cat.contains("juice") || cat.contains("water")
    }

    var calculatedNutriscore: (score: Int, grade: String)? {
        Nutriscore.calculate(nutrition: nutrition, isBeverage: isBeverage)
    }

    var isNutriscoreCalculated: Bool {
        nutriscoreGrade == nil && calculatedNutriscore != nil
    }

    var effectiveNutriscoreGrade: String? {
        nutriscoreGrade ?? calculatedNutriscore?.grade
    }

    var effectiveNutriscoreScore: Int? {
        nutriscoreScore ?? calculatedNutriscore?.score
    }

    var calories: Int? { nutrition.energyKcal.map { Int($0.rounded()) } }

    /// 0–100 estimate from Nutri-Score + NOVA. Always captioned as an
    /// estimate in the UI; `nil` when neither input exists.
    var healthScore: Int? {
        guard let grade = effectiveNutriscoreGrade else { return nil }
        var score = 100
        switch grade {
        case "a": break
        case "b": score -= 10
        case "c": score -= 25
        case "d": score -= 40
        case "e": score -= 55
        default: return nil
        }
        switch novaGroup {
        case 2: score -= 5
        case 3: score -= 10
        case 4: score -= 15
        default: break
        }
        return max(0, min(100, score))
    }

    var verdict: (headline: String, tone: Tone)? {
        guard let s = healthScore else { return nil }
        switch s {
        case 80...: return ("A genuinely good pick", .good)
        case 60..<80: return ("Fine now and then", .fair)
        case 40..<60: return ("Worth a second look", .fair)
        default: return ("Better as a rare treat", .poor)
        }
    }

    var novaLabel: String? {
        switch novaGroup {
        case 1: return "Unprocessed"
        case 2: return "Processed ingredient"
        case 3: return "Processed"
        case 4: return "Ultra-processed"
        default: return nil
        }
    }

    /// Lower-cased ingredient text, for the fallback checks that run only on
    /// community products with no structured tags.
    var ingredientText: String {
        (ingredients ?? "").lowercased()
    }

    /// Everything the source says is in it, traces included, as slugs.
    var declaredAllergens: [String] { (allergens ?? []) + (traces ?? []) }

    var shareSummary: String {
        var lines = ["\(name)\(brand.map { " · \($0)" } ?? "")"]
        if let grade = effectiveNutriscoreGrade {
            let label = isNutriscoreCalculated ? "TrueLabel Nutri-Score" : "Nutri-Score"
            lines.append("\(label) \(grade.uppercased())")
        }
        if let serving = servingSize { lines.append("Serving \(serving)") }
        if let nova = novaLabel { lines.append("NOVA \(novaGroup ?? 0) · \(nova)") }
        if let kcal = calories { lines.append("\(kcal) kcal per 100g") }
        if let sugar = nutrition.sugar { lines.append("Sugar \(sugar.compact) g per 100g") }
        lines.append("Scanned with TrueLabel")
        return lines.joined(separator: "\n")
    }
}

enum Tone { case good, fair, poor }

/// Open Food Facts also ships "unknown" and "not-applicable" in this field,
/// and the column is wide enough to store them. Only a–e is printable.
enum Nutriscore {
    static let letters = ["a", "b", "c", "d", "e"]

    static func letter(_ raw: String?) -> String? {
        guard let g = raw?.trimmingCharacters(in: .whitespaces).lowercased(),
              letters.contains(g) else { return nil }
        return g
    }

    /// Standard Nutri-Score calculation based on Santé Publique France / EU Nutri-Score specifications.
    static func calculate(nutrition: Nutrition, isBeverage: Bool = false) -> (score: Int, grade: String)? {
        guard let energyKcal = nutrition.energyKcal,
              let sugar = nutrition.sugar,
              let saturatedFat = nutrition.saturatedFat,
              let sodium = nutrition.sodium else {
            return nil
        }

        let kj = energyKcal * 4.184
        let sodiumMg = sodium * 1000.0
        let protein = nutrition.protein ?? 0
        let fiber = nutrition.fiber ?? 0

        if isBeverage {
            return calculateBeverage(kj: kj, sugar: sugar, satFat: saturatedFat, sodiumMg: sodiumMg, protein: protein, fiber: fiber)
        } else {
            return calculateSolid(kj: kj, sugar: sugar, satFat: saturatedFat, sodiumMg: sodiumMg, protein: protein, fiber: fiber)
        }
    }

    private static func calculateSolid(kj: Double, sugar: Double, satFat: Double, sodiumMg: Double, protein: Double, fiber: Double) -> (score: Int, grade: String) {
        let energyPts: Int
        if kj > 3350 { energyPts = 10 }
        else if kj > 3015 { energyPts = 9 }
        else if kj > 2680 { energyPts = 8 }
        else if kj > 2345 { energyPts = 7 }
        else if kj > 2010 { energyPts = 6 }
        else if kj > 1675 { energyPts = 5 }
        else if kj > 1340 { energyPts = 4 }
        else if kj > 1005 { energyPts = 3 }
        else if kj > 670  { energyPts = 2 }
        else if kj > 335  { energyPts = 1 }
        else { energyPts = 0 }

        let sugarPts: Int
        if sugar > 45 { sugarPts = 10 }
        else if sugar > 40 { sugarPts = 9 }
        else if sugar > 36 { sugarPts = 8 }
        else if sugar > 31 { sugarPts = 7 }
        else if sugar > 27 { sugarPts = 6 }
        else if sugar > 22.5 { sugarPts = 5 }
        else if sugar > 18 { sugarPts = 4 }
        else if sugar > 13.5 { sugarPts = 3 }
        else if sugar > 9 { sugarPts = 2 }
        else if sugar > 4.5 { sugarPts = 1 }
        else { sugarPts = 0 }

        let satFatPts: Int
        if satFat > 10 { satFatPts = 10 }
        else if satFat > 9 { satFatPts = 9 }
        else if satFat > 8 { satFatPts = 8 }
        else if satFat > 7 { satFatPts = 7 }
        else if satFat > 6 { satFatPts = 6 }
        else if satFat > 5 { satFatPts = 5 }
        else if satFat > 4 { satFatPts = 4 }
        else if satFat > 3 { satFatPts = 3 }
        else if satFat > 2 { satFatPts = 2 }
        else if satFat > 1 { satFatPts = 1 }
        else { satFatPts = 0 }

        let sodiumPts: Int
        if sodiumMg > 900 { sodiumPts = 10 }
        else if sodiumMg > 810 { sodiumPts = 9 }
        else if sodiumMg > 720 { sodiumPts = 8 }
        else if sodiumMg > 630 { sodiumPts = 7 }
        else if sodiumMg > 540 { sodiumPts = 6 }
        else if sodiumMg > 450 { sodiumPts = 5 }
        else if sodiumMg > 360 { sodiumPts = 4 }
        else if sodiumMg > 270 { sodiumPts = 3 }
        else if sodiumMg > 180 { sodiumPts = 2 }
        else if sodiumMg > 90  { sodiumPts = 1 }
        else { sodiumPts = 0 }

        let nPoints = energyPts + sugarPts + satFatPts + sodiumPts

        let proteinPts: Int
        if protein > 8.0 { proteinPts = 5 }
        else if protein > 6.4 { proteinPts = 4 }
        else if protein > 4.8 { proteinPts = 3 }
        else if protein > 3.2 { proteinPts = 2 }
        else if protein > 1.6 { proteinPts = 1 }
        else { proteinPts = 0 }

        let fiberPts: Int
        if fiber > 4.7 { fiberPts = 5 }
        else if fiber > 3.7 { fiberPts = 4 }
        else if fiber > 2.8 { fiberPts = 3 }
        else if fiber > 1.9 { fiberPts = 2 }
        else if fiber > 0.9 { fiberPts = 1 }
        else { fiberPts = 0 }

        let pPoints = (nPoints >= 11) ? fiberPts : (proteinPts + fiberPts)
        let totalScore = nPoints - pPoints

        let grade: String
        switch totalScore {
        case ...(-1): grade = "a"
        case 0...2:   grade = "b"
        case 3...10:  grade = "c"
        case 11...18: grade = "d"
        default:      grade = "e"
        }

        return (totalScore, grade)
    }

    private static func calculateBeverage(kj: Double, sugar: Double, satFat: Double, sodiumMg: Double, protein: Double, fiber: Double) -> (score: Int, grade: String) {
        let energyPts: Int
        if kj > 270 { energyPts = 10 }
        else if kj > 240 { energyPts = 9 }
        else if kj > 210 { energyPts = 8 }
        else if kj > 180 { energyPts = 7 }
        else if kj > 150 { energyPts = 6 }
        else if kj > 120 { energyPts = 5 }
        else if kj > 90  { energyPts = 4 }
        else if kj > 60  { energyPts = 3 }
        else if kj > 30  { energyPts = 2 }
        else if kj > 0   { energyPts = 1 }
        else { energyPts = 0 }

        let sugarPts: Int
        if sugar > 13.5 { sugarPts = 10 }
        else if sugar > 12.0 { sugarPts = 9 }
        else if sugar > 10.5 { sugarPts = 8 }
        else if sugar > 9.0  { sugarPts = 7 }
        else if sugar > 7.5  { sugarPts = 6 }
        else if sugar > 6.0  { sugarPts = 5 }
        else if sugar > 4.5  { sugarPts = 4 }
        else if sugar > 3.0  { sugarPts = 3 }
        else if sugar > 1.5  { sugarPts = 2 }
        else if sugar > 0.0  { sugarPts = 1 }
        else { sugarPts = 0 }

        let satFatPts = satFat > 10 ? 10 : Int(satFat)
        let sodiumPts = sodiumMg > 900 ? 10 : Int(sodiumMg / 90)

        let nPoints = energyPts + sugarPts + satFatPts + sodiumPts

        let fiberPts: Int
        if fiber > 4.7 { fiberPts = 5 }
        else if fiber > 3.7 { fiberPts = 4 }
        else if fiber > 2.8 { fiberPts = 3 }
        else if fiber > 1.9 { fiberPts = 2 }
        else if fiber > 0.9 { fiberPts = 1 }
        else { fiberPts = 0 }

        let proteinPts = protein > 8.0 ? 5 : Int(protein / 1.6)
        let pPoints = (nPoints >= 11) ? fiberPts : (proteinPts + fiberPts)
        let totalScore = nPoints - pPoints

        let grade: String
        switch totalScore {
        case ...1:   grade = "b"
        case 2...5:  grade = "c"
        case 6...9:  grade = "d"
        default:     grade = "e"
        }

        return (totalScore, grade)
    }
}

struct Nutrition: Codable, Hashable, Sendable {
    var energyKcal: Double?
    var protein: Double?
    var carbs: Double?
    var fat: Double?
    var saturatedFat: Double?
    var transFat: Double?
    var fiber: Double?
    var sugar: Double?
    /// Grams per 100g, as Open Food Facts stores it.
    var sodium: Double?
    var cholesterol: Double?
    var potassium: Double?
    var calcium: Double?
    var iron: Double?

    var sodiumMg: Double? { sodium.map { $0 * 1000 } }

    init() {}

    /// Tolerant decoding: OFF occasionally ships numbers as strings, and
    /// community-contributed products ship `{}`. Neither should fail a scan.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func num(_ key: CodingKeys) -> Double? {
            if let d = try? c.decodeIfPresent(Double.self, forKey: key) { return d }
            if let s = try? c.decodeIfPresent(String.self, forKey: key) { return Double(s) }
            return nil
        }
        energyKcal = num(.energyKcal); protein = num(.protein); carbs = num(.carbs); fat = num(.fat)
        saturatedFat = num(.saturatedFat); transFat = num(.transFat); fiber = num(.fiber)
        sugar = num(.sugar); sodium = num(.sodium); cholesterol = num(.cholesterol)
        potassium = num(.potassium); calcium = num(.calcium); iron = num(.iron)
    }

    var isEmpty: Bool {
        [energyKcal, protein, carbs, fat, saturatedFat, transFat, fiber, sugar, sodium, cholesterol, potassium, calcium, iron]
            .allSatisfy { $0 == nil }
    }

    /// Rows for the printed-label card, in conventional label order.
    var labelRows: [(name: String, value: String)] {
        var rows: [(String, String)] = []
        func g(_ name: String, _ v: Double?) { if let v { rows.append((name, "\(v.compact) g")) } }
        func mg(_ name: String, _ v: Double?) { if let v { rows.append((name, "\(Int((v * 1000).rounded())) mg")) } }
        g("Total fat", fat)
        g("Saturated fat", saturatedFat)
        g("Trans fat", transFat)
        mg("Cholesterol", cholesterol)
        mg("Sodium", sodium)
        g("Total carbohydrate", carbs)
        g("Dietary fibre", fiber)
        g("Sugars", sugar)
        g("Protein", protein)
        mg("Potassium", potassium)
        mg("Calcium", calcium)
        mg("Iron", iron)
        return rows
    }
}

/// Human class for an E-number, by its hundred-block — the standard
/// Codex/EU numbering scheme, not a risk claim.
enum Additive {
    static func kind(of code: String) -> String {
        let digits = code.drop(while: { !$0.isNumber }).prefix(while: \.isNumber)
        guard let n = Int(digits) else { return "Additive" }
        switch n {
        case 100..<200: return "Colour"
        case 200..<300: return "Preservative"
        case 300..<400: return "Antioxidant · acidity regulator"
        case 400..<500: return "Thickener · emulsifier"
        case 500..<600: return "Acidity regulator · anti-caking"
        case 600..<700: return "Flavour enhancer"
        case 900..<1000: return "Glazing agent · sweetener"
        case 1000...: return "Modified starch · other"
        default: return "Additive"
        }
    }
}
