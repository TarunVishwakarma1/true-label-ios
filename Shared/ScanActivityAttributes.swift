//
//  ScanActivityAttributes.swift
//  Shared between the app and QuickScanWidgetExtension
//
//  This folder exists for exactly one reason: ActivityKit matches a running
//  activity to the widget that draws it by the attributes type, so the app
//  and the extension have to compile the *same* type rather than two
//  identical copies. A third synchronized folder owned by both targets is
//  the clean way to express that — the alternative is making the whole app
//  folder a member of the widget target and excluding 30-odd files by hand,
//  which would silently pull every new app file into the extension.
//
//  Keep this file dependency-free. It is compiled into an extension with a
//  tight memory budget, and anything imported here is imported there.
//

import ActivityKit
import Foundation

/// A scan result, parked in the Dynamic Island so the phone can go back in a
/// pocket. The case this is for: you are standing in an aisle comparing two
/// packs, and re-opening the app to remember what the last one said is the
/// part that makes people stop using a scanner.
struct ScanActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Trimmed on the way in — the island's compact slot is a few
        /// characters wide and a 60-character product name helps nobody.
        var productName: String
        var brand: String?
        /// Nutri-Score letter, lowercased a-e, or nil when the product has
        /// no published grade. The widget colours itself from this.
        var grade: String?
        /// The one number worth glancing at, already formatted for display
        /// ("4 tsp sugar", "18 g fat"). Formatting happens app-side so the
        /// extension does no unit maths.
        var headline: String
        /// How many of the user's own dietary checks this product tripped.
        /// Zero is a meaningful, good answer, so it is not optional.
        var concerns: Int
    }

    /// Identifies the activity so a second scan replaces the first rather
    /// than stacking a new island on top of it.
    var barcode: String
}
