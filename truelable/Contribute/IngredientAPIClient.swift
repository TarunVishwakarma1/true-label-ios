//
//  IngredientAPIClient.swift
//  truelable
//

import UIKit
import Vision

enum IngredientAPIClient {
    enum OCRError: Error {
        case noTextRecognized
    }

    /// Runs Vision's on-device text recognizer against the captured photo —
    /// no network call. Hardware-accelerated and fast enough (well under a
    /// second to ~1-2s in `.accurate` mode) that it doesn't need a
    /// server round-trip just to populate the review screen; the real
    /// network call happens once, in `submitContribution`, so the source of
    /// truth is parsed exactly once, server-side.
    static func extractIngredients(image: UIImage) async throws -> ExtractedProductData {
        let rawText = try await recognizeText(in: image)
        guard !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OCRError.noTextRecognized
        }

        return ExtractedProductData(
            guessedName: Self.guessProductName(rawText),
            ingredients: Self.parseIngredients(rawText),
            allergens: Self.detectAllergens(rawText),
            rawText: rawText
        )
    }

    static func submitContribution(barcode: String, data: ExtractedProductData) async throws -> Bool {
        let country = Locale.current.region?.identifier ?? "US"

        var request = URLRequest(url: APIEnvironment.baseURL.appendingPathComponent("/api/v1/ocr/submit"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(
            SubmitLabelRequest(
                barcode: barcode,
                country: country,
                extractedText: data.rawText,
                reviewedIngredients: data.ingredients,
                reviewedAllergens: data.allergens
            )
        )

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { return false }
        return (200..<300).contains(http.statusCode)
    }

    // MARK: - On-device text recognition

    private static func recognizeText(in image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else { throw OCRError.noTextRecognized }

        // handler.perform is synchronous and this project defaults to
        // @MainActor — without detaching, this blocks the UI thread.
        return try await Task.detached(priority: .userInitiated) {
            try await withCheckedThrowingContinuation { continuation in
                let request = VNRecognizeTextRequest { request, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    let observations = request.results as? [VNRecognizedTextObservation] ?? []
                    let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                    continuation.resume(returning: lines.joined(separator: "\n"))
                }
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true

                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }.value
    }

    // MARK: - Local preview parsing (mirrors the backend's heuristic in
    // truelabel-backend/src/services/ocr_service.rs — kept intentionally
    // simple since it's only for the instant local preview; the backend's
    // parse of the same `rawText` is what actually gets stored)

    private static let sectionBoundaries = [
        "contains", "may contain", "allergen", "manufactured", "distributed by",
        "storage", "best before", "net wt", "nutrition facts", "nutritional information"
    ]

    private static let knownAllergens = [
        "milk", "wheat", "soy", "soya", "peanut", "peanuts", "tree nut", "tree nuts",
        "egg", "eggs", "fish", "shellfish", "sesame", "gluten", "mustard", "celery",
        "lupin", "sulphites", "sulfites"
    ]

    private static func parseIngredients(_ raw: String) -> String {
        var body = raw
        if let labelRange = raw.range(of: "ingredients", options: .caseInsensitive),
           let colonRange = raw.range(of: ":", range: labelRange.upperBound..<raw.endIndex) {
            body = String(raw[colonRange.upperBound...])
        }

        if let boundary = sectionBoundaries
            .compactMap({ body.range(of: $0, options: .caseInsensitive) })
            .min(by: { $0.lowerBound < $1.lowerBound }) {
            body = String(body[body.startIndex..<boundary.lowerBound])
        }

        return body
            .split(whereSeparator: { $0 == "," || $0.isNewline })
            .map { $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: ".")) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    private static func detectAllergens(_ raw: String) -> [String] {
        let lower = raw.lowercased()
        let found = knownAllergens
            .filter { lower.contains($0) }
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
        return Array(Set(found)).sorted()
    }

    private static func guessProductName(_ raw: String) -> String {
        raw
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty && !$0.lowercased().hasPrefix("ingredient") }
            ?? ""
    }
}

private struct SubmitLabelRequest: Encodable {
    var barcode: String
    var country: String
    var extractedText: String
    var reviewedIngredients: String
    var reviewedAllergens: [String]
}
