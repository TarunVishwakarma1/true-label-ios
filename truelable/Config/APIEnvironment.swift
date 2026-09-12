//
//  APIEnvironment.swift
//  truelable
//

import Foundation

/// Where the backend lives, per build. Debug builds default to the Mac's
/// LAN IP for on-device testing over Wi-Fi (update `developmentURL` if your
/// Mac's IP changes — new network, DHCP renewal). Release builds default to
/// production, once one exists.
///
/// To point a Debug build at something else (a staging/testbed server)
/// without touching code: Xcode > Product > Scheme > Edit Scheme > Run >
/// Arguments > Environment Variables, add `API_BASE_URL` with the full
/// URL — it always wins over the compiled-in defaults below.
enum APIEnvironment {
    // private static let developmentURL = "http://168.144.69.231:8080"
    private static let developmentURL = "https://api.truelabel.fun"


    /// No production deployment exists yet — update this once one does.
    private static let productionURL = "https://api.truelabel.fun"

    static var baseURL: URL {
        if let override = ProcessInfo.processInfo.environment["API_BASE_URL"],
           let url = URL(string: override) {
            return url
        }
        #if DEBUG
        return URL(string: developmentURL)!
        #else
        return URL(string: productionURL)!
        #endif
    }
}
