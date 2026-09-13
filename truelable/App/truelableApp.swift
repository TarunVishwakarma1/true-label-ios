//
//  truelableApp.swift
//  truelable
//
//  Created by Tarun Vishwakarma on 08/09/26.
//

import SwiftUI
import SwiftData

@main
struct truelableApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: ScanHistoryEntry.self)
    }
}
