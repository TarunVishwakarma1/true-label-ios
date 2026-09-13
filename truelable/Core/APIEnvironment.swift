//
//  APIEnvironment.swift
//  truelable
//

import Foundation

/// `API_BASE_URL` in the scheme's environment overrides everything — point a
/// Debug build at a LAN backend without touching code.
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
