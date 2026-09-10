//
//  HealthProfileSheet.swift
//  truelable
//

import SwiftUI

/// Reachable from `ProductDetailView`'s top bar. Turning a toggle on here
/// immediately changes how that screen's nutrition list sorts and flags —
/// no separate "save" step.
struct HealthProfileSheet: View {
    var onDismiss: () -> Void

    @AppStorage("healthProfile.watchingSugar") private var watchingSugar = false
    @AppStorage("healthProfile.watchingSodium") private var watchingSodium = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle(isOn: $watchingSugar) {
                        Label("Watching sugar", systemImage: "cube.fill")
                    }
                    .tint(TLColor.accent)

                    Toggle(isOn: $watchingSodium) {
                        Label("Watching sodium", systemImage: "drop.fill")
                    }
                    .tint(TLColor.accent)
                } footer: {
                    Text("Flagged first because you asked. Nothing else changes.")
                }
            }
            .navigationTitle("Health Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDismiss)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    HealthProfileSheet(onDismiss: {})
}
