import Foundation

enum BarcodeChecksum {
    static func isValid(_ code: String) -> Bool {
        guard [8, 12, 13].contains(code.count), let digits = digitValues(of: code) else { return false }
        let check = digits.last!
        let sum = digits.dropLast().reversed().enumerated().reduce(0) { total, entry in
            total + entry.element * (entry.offset % 2 == 0 ? 3 : 1)
        }
        return (10 - sum % 10) % 10 == check
    }

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
