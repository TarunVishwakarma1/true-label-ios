//
//  truelableTests.swift
//  truelableTests
//
//  One check per piece of logic that would break silently: check digits,
//  API decoding (including the tolerant nutrition parse), the personal
//  flag engine, and additive classes.
//

import Foundation
import Testing
@testable import truelable

struct ChecksumTests {
    @Test func acceptsRealBarcodes() {
        #expect(BarcodeChecksum.isValid("8901030895562"))   // EAN-13
        #expect(BarcodeChecksum.isValid("036000291452"))    // UPC-A
        #expect(BarcodeChecksum.isValid("0036000291452"))   // same, EAN-13 form
        #expect(BarcodeChecksum.isValid("96385074"))        // EAN-8
    }

    @Test func rejectsBadOnes() {
        #expect(!BarcodeChecksum.isValid("8901030895563"))
        #expect(!BarcodeChecksum.isValid("12345"))
        #expect(!BarcodeChecksum.isValid("89010308955A4"))
    }

    @Test func normalizesUPCA() {
        #expect(BarcodeChecksum.normalized("036000291452") == "0036000291452")
        #expect(BarcodeChecksum.normalized("8901030895564") == "8901030895564")
    }
}

struct DecodingTests {
    static let json = """
    {"status":"success","cached":false,"timestamp":"2026-09-13T00:00:00Z","data":{
      "id":"c2e1","barcode":"8901030895564","country":"IN","product_name":"Aloo Bhujia","brand":"Haldiram's",
      "image_url":"https://images.example/a.jpg",
      "nutrition_facts":{"energy_kcal":546,"protein":"9.2","carbs":43.8,"fat":36.4,"sugar":null,"sodium":1.18},
      "ingredients":"Gram flour, palm oil, potato","allergens":["peanuts","milk"],"traces":["tree-nuts"],
      "labels":["vegetarian"],"serving_size":"30 g","serving_quantity":30,
      "nutrition_per_serving":{"energy_kcal":163.8},"nutrient_levels":{"sodium":"high"},
      "nutriscore_score":18,"ecoscore_grade":"d","quantity":"200 g","source":"open_food_facts",
      "verified":false,"verification_count":1,"additives":["E330","E500II"],"nova_group":4,"nutriscore_grade":"d",
      "is_vegan":true,"is_vegetarian":true,"is_palm_oil_free":false,"category":"namkeen"}}
    """.data(using: .utf8)!

    private struct Envelope: Decodable { var data: Product? }

    static func decode() throws -> Product {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return try #require(try d.decode(Envelope.self, from: json).data)
    }

    @Test func decodesBackendShape() throws {
        let p = try Self.decode()
        #expect(p.name == "Aloo Bhujia")
        #expect(p.imageURL?.host() == "images.example")
        #expect(p.nutrition.energyKcal == 546)
        #expect(p.nutrition.protein == 9.2)        // string number tolerated
        #expect(p.nutrition.sugar == nil)          // null tolerated
        #expect(p.nutrition.sodiumMg == 1180)
        #expect(p.additives == ["E330", "E500II"])
        #expect(p.allergens == ["peanuts", "milk"])
        #expect(p.traces == ["tree-nuts"])
        #expect(p.servingQuantity == 30)
        #expect(p.nutritionPerServing?.energyKcal == 163.8)
        #expect(p.nutrientLevels?["sodium"] == "high")
        #expect(p.healthScore == 45)               // d (-40) + nova 4 (-15)
    }

    @Test func snapshotRoundTrips() throws {
        let p = try Self.decode()
        let data = try JSONEncoder().encode(p)
        let back = try JSONDecoder().decode(Product.self, from: data)
        #expect(back == p)
    }

    @Test func emptyNutritionDecodes() throws {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        let json = #"{"barcode":"1","product_name":"X","nutrition_facts":{},"source":"user_contributed"}"#.data(using: .utf8)!
        let p = try d.decode(Product.self, from: json)
        #expect(p.nutrition.isEmpty)
        #expect(p.isCommunitySourced)
        #expect(p.healthScore == nil)
    }
}

struct PersonalCheckTests {
    @Test func flagsProblemsFirstAndAdmitsUnknowns() throws {
        let p = try DecodingTests.decode()
        let checks = PersonalCheck.run([.peanutAllergy, .noPalmOil, .vegetarian, .lowSugar, .lactoseSensitive], on: p)
            .sorted { $0.status.rank < $1.status.rank }
        #expect(checks.map(\.preference).prefix(2).allSatisfy { [.peanutAllergy, .noPalmOil].contains($0) })
        #expect(checks.first { $0.preference == .peanutAllergy }?.status == .avoid)
        #expect(checks.first { $0.preference == .vegetarian }?.status == .good)
        #expect(checks.first { $0.preference == .lowSugar }?.status == .unknown)
        #expect(checks.first { $0.preference == .lactoseSensitive }?.status == .caution)
    }

    @Test func prefsRoundTrip() {
        let set: Set<DietaryPreference> = [.jain, .lowSodium]
        #expect(DietaryPreference.decode(DietaryPreference.encode(set)) == set)
        #expect(DietaryPreference.decode("").isEmpty)
    }
}

struct AdditiveTests {
    @Test func classifiesByRange() {
        #expect(Additive.kind(of: "E150D") == "Colour")
        #expect(Additive.kind(of: "E211") == "Preservative")
        #expect(Additive.kind(of: "E330") == "Antioxidant · acidity regulator")
        #expect(Additive.kind(of: "E621") == "Flavour enhancer")
        #expect(Additive.kind(of: "E1442") == "Modified starch · other")
    }
}

struct OCRHeuristicTests {
    @Test func parsesIngredientsAndAllergens() {
        let raw = "Nutella\nIngredients: Sugar, Palm Oil, Hazelnuts 13%, Cocoa.\nContains MILK, SOY.\nBest before 12/2027"
        #expect(LabelOCR.parseIngredients(raw) == "Sugar, Palm Oil, Hazelnuts 13%, Cocoa")
        #expect(LabelOCR.detectAllergens(raw) == ["Milk", "Soy"])
        #expect(LabelOCR.guessName(raw) == "Nutella")
    }
}

struct NutritionParserTests {
    @Test func readsTypicalIndianLabel() {
        let text = """
        Nutritional Information (per 100 g)
        Energy 2285 kJ / 546 kcal
        Total Fat 36.4 g
        Saturated Fat 12.1 g
        Trans Fat 0 g
        Carbohydrate 43.8 g
        Sugars
        2.4 g
        Protein 9.2 g
        Salt 1.2 g
        """
        let n = NutritionParser.parse(text)
        #expect(n.energyKcal == 546)
        #expect(n.fat == 36.4)
        #expect(n.saturatedFat == 12.1)
        #expect(n.transFat == 0)
        #expect(n.carbs == 43.8)
        #expect(n.sugar == 2.4)          // label and value on separate lines
        #expect(n.protein == 9.2)
        #expect(n.sodium == 0.48)        // salt 1.2 g → sodium 0.48 g
    }

    @Test func convertsKJOnlyEnergyAndMgSodium() {
        let n = NutritionParser.parse("Energy 1000 kJ\nSodium 480 mg")
        #expect(n.energyKcal == 239)
        #expect(n.sodium == 0.48)
    }
}

struct OCRDraftTests {
    @Test func brandIsTallestFrontLineAndWeightsAreSkipped() {
        let front = TextTake(lines: [
            TextLine(text: "200 g", height: 30, y: 0.9),
            TextLine(text: "HALDIRAM'S", height: 60, y: 0.2),
            TextLine(text: "Aloo Bhujia", height: 40, y: 0.5),
            TextLine(text: "Crispy & tasty, the original recipe since 1937 by the family", height: 12, y: 0.7)
        ])
        let ingredients = TextTake(lines: [TextLine(text: "Ingredients: Gram flour, Palm oil, Salt.", height: 10, y: 0.5)])
        let d = LabelOCR.draft(front: front, ingredients: ingredients, nutrition: nil)
        #expect(d.brand == "HALDIRAM'S")
        #expect(d.name == "Aloo Bhujia")
        #expect(d.nameCandidates == ["HALDIRAM'S", "Aloo Bhujia"])
        #expect(d.ingredients == "Gram flour, Palm oil, Salt")
    }
}

struct NutriscoreTests {
    @Test func onlyLettersSurvive() {
        #expect(Nutriscore.letter("D") == "d")
        #expect(Nutriscore.letter(" a ") == "a")
        // The column is wide enough for these, and a badge can't print them.
        #expect(Nutriscore.letter("unknown") == nil)
        #expect(Nutriscore.letter("not-applicable") == nil)
        #expect(Nutriscore.letter("") == nil)
        #expect(Nutriscore.letter(nil) == nil)
    }
}

struct AllergenCheckTests {
    /// The bug this guards: "gluten free" contains "gluten", so matching the
    /// bare substring flagged exactly the products someone avoiding gluten
    /// should be able to buy.
    @Test func certifiedGlutenFreeIsNotReportedAsContainingGluten() {
        let certified = Product(barcode: "1", name: "Oats", labels: ["en-gluten-free", "gluten-free"])
        #expect(PersonalCheck.run([.glutenFree], on: certified).first?.status == .good)

        // Community products carry no tags, only the text a person typed.
        let statedInText = Product(barcode: "2", name: "Oats", ingredients: "Rolled oats, gluten free")
        #expect(PersonalCheck.run([.glutenFree], on: statedInText).first?.status == .good)

        let genuinelyContains = Product(barcode: "3", name: "Biscuit", ingredients: "Wheat flour, sugar")
        #expect(PersonalCheck.run([.glutenFree], on: genuinelyContains).first?.status == .avoid)
    }

    @Test func mayContainIsACautionNotARefusal() {
        let product = Product(barcode: "1", name: "Chocolate", allergens: ["milk"], traces: ["peanuts"])
        let check = PersonalCheck.run([.peanutAllergy], on: product).first
        #expect(check?.status == .caution)
        #expect(check?.message.contains("May contain") == true)
    }

    @Test func declaredNoneIsNotTheSameAsNotPublished() {
        let declaresNone = Product(barcode: "1", name: "Water", allergens: [])
        #expect(PersonalCheck.run([.peanutAllergy], on: declaresNone).first?.status == .good)

        // Nothing published and no ingredients: we do not know, and saying
        // "no peanuts" would be a claim we cannot support.
        let silent = Product(barcode: "2", name: "Mystery")
        #expect(PersonalCheck.run([.peanutAllergy], on: silent).first?.status == .unknown)
    }

    @Test func thePublishedTrafficLightWinsOverOurThresholds() {
        var nutrition = Nutrition()
        nutrition.sugar = 1.0
        let product = Product(barcode: "1", name: "Drink", nutrition: nutrition,
                              nutrientLevels: ["sugar": "high"])
        // Our own thresholds would call 1 g low; the source says high for a
        // drink, and the source wins.
        #expect(PersonalCheck.run([.lowSugar], on: product).first?.status == .avoid)
    }
}

struct CrashReporterTests {
    @Test func titlesFromExceptionTypeWhenPresent() {
        let s = CrashReporter.submission(
            exceptionType: 1, signal: 6, terminationReason: nil, stackTraceJSON: nil,
            appBuildVersion: "12", osVersion: "26.5", deviceType: "iPhone17,1", deviceId: nil
        )
        // Exception type wins over signal when both are present — a
        // signal accompanies most exception crashes too, and the
        // exception type is the more specific fact.
        #expect(s.title == "Exception type 1")
    }

    @Test func fallsBackToSignalWhenNoExceptionType() {
        let s = CrashReporter.submission(
            exceptionType: nil, signal: 11, terminationReason: nil, stackTraceJSON: nil,
            appBuildVersion: "12", osVersion: "26.5", deviceType: "iPhone17,1", deviceId: nil
        )
        #expect(s.title == "Signal 11")
    }

    @Test func fallsBackToGenericCrashWhenNeitherIsPresent() {
        let s = CrashReporter.submission(
            exceptionType: nil, signal: nil, terminationReason: "abc", stackTraceJSON: nil,
            appBuildVersion: "12", osVersion: "26.5", deviceType: "iPhone17,1", deviceId: nil
        )
        #expect(s.title == "Crash")
    }

    @Test func carriesEveryFieldThrough() {
        let s = CrashReporter.submission(
            exceptionType: nil, signal: 6, terminationReason: "NAMESPACE_SIGNAL, Namespace SIGNAL",
            stackTraceJSON: "{\"callStacks\":[]}",
            appBuildVersion: "42", osVersion: "26.5", deviceType: "iPhone17,1",
            deviceId: "ABCD-1234"
        )
        #expect(s.platform == "ios")
        #expect(s.severity == "critical")
        #expect(s.description == "NAMESPACE_SIGNAL, Namespace SIGNAL")
        #expect(s.stackTrace == "{\"callStacks\":[]}")
        #expect(s.appVersion == "42")
        #expect(s.osVersion == "26.5")
        #expect(s.deviceModel == "iPhone17,1")
        #expect(s.deviceId == "ABCD-1234")
    }
}
