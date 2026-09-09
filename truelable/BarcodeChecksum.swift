//
//  BarcodeChecksum.swift
//  truelable
//

import Foundation

/// Validates the check digit on the retail barcode formats you'd find on
/// packaged food (EAN-13, UPC-A, EAN-8) — the standard mod-10 weighted sum,
/// not a network call. Anything that isn't all-digits, or is the wrong
/// length for a known format, is treated as not a valid product barcode.
enum BarcodeChecksum {
    static func isValid(_ code: String) -> Bool {
        guard code.count == 8 || code.count == 12 || code.count == 13,
              let digits = digitValues(of: code) else { return false }

        let checkDigit = digits.last!
        let payload = digits.dropLast()

        // Weight 3 always starts on the digit immediately left of the check
        // digit, alternating from there — i.e. counted from the RIGHT, not
        // the left. This is what makes a 12-digit UPC-A and its 13-digit
        // EAN-13 form (a leading 0 prepended — what a scanner reports) work
        // out to the same check digit: the extra digit lands at the far
        // (left) end, which counting-from-the-right never touches. Counting
        // from the left instead (an earlier version of this file) breaks
        // that equivalence and rejects real barcodes.
        let sum = payload.reversed().enumerated().reduce(0) { total, entry in
            let (index, digit) = entry
            return total + digit * (index % 2 == 0 ? 3 : 1)
        }
        let expectedCheckDigit = (10 - sum % 10) % 10
        return expectedCheckDigit == checkDigit
    }

    /// UPC-A (12 digits) is numerically EAN-13 with a leading 0 — the same
    /// physical barcode, just two ways of writing it depending on whether a
    /// scanner or a manually-typed entry included that leading digit.
    /// Normalizing means both forms look up the same product.
    static func normalized(_ code: String) -> String {
        code.count == 12 ? "0" + code : code
    }

    private static func digitValues(of code: String) -> [Int]? {
        var digits: [Int] = []
        digits.reserveCapacity(code.count)
        for char in code {
            guard let digit = char.wholeNumberValue else { return nil }
            digits.append(digit)
        }
        return digits
    }
}
