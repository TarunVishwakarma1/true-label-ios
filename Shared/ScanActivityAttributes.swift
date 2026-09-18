import ActivityKit
import Foundation

struct ScanActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {

        var productName: String
        var brand: String?

        var grade: String?

        var headline: String

        var concerns: Int
    }

    var barcode: String
}
