import Foundation

enum APIEnvironment {
    private static let developmentURL = "https://api.truelabel.fun"
    private static let productionURL = "https://api.truelabel.fun"

    static var baseURL: URL {
        if let override = ProcessInfo.processInfo.environment["API_BASE_URL"], let url = URL(string: override) {
            return url
        }
        #if DEBUG
        return URL(string: developmentURL)!
        #else
        return URL(string: productionURL)!
        #endif
    }
}
