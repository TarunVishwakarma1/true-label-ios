//
//  BarcodeChecksum.swift
//  truelable
//

import Foundation

/// Mod-10 check digit for EAN-13 / UPC-A / EAN-8 — the retail formats on
/// packaged food. Weighting runs from the right so UPC-A and its EAN-13
/// (leading-zero) form validate identically.
enum BarcodeChecksum {
    static func isValid(_ code: String) -> Bool {
        guard [8, 12, 13].contains(code.count), let digits = digitValues(of: code) else { return false }
        let check = digits.last!
        let sum = digits.dropLast().reversed().enumerated().reduce(0) { total, entry in
            total + entry.element * (entry.offset % 2 == 0 ? 3 : 1)
        }
        return (10 - sum % 10) % 10 == check
    }

    /// UPC-A is EAN-13 with a leading 0 — same product, one lookup key.
    static func normalized(_ code: String) -> String {
        code.count == 12 ? "0" + code : code
    }

    private static func digitValues(of code: String) -> [Int]? {
        var out: [Int] = []
        out.reserveCapacity(code.count)
        for ch in code {
            guard let d = ch.wholeNumberValue else { return nil }
            out.append(d)
        }
        return out
    }
}
