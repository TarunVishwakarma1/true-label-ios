//
//  RootView.swift
//  truelable
//

import SwiftUI
import UIKit

/// Four top-level destinations — Scan, History, Verify, You — matching
/// the "TrueLabel iOS v3" design and how every app this was benchmarked
/// against (Zomato, Blinkit, Paytm, CRED) structures itself. Scan's own
/// camera flow stays a `fullScreenCover` triggered from the Scan tab's
/// content, not a fifth destination: it's a momentary action, not a place
/// you browse.
struct RootView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded = false

    init() {
        // Dark tab bar chrome by default — otherwise UIKit's system
        // material shows through light, clashing with every other screen
        // in this app being dark-first.
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(TLColor.surface)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        Group {
            if hasOnboarded {
                tabs
            } else {
                OnboardingView(onFinished: {
                    withAnimation(.easeOutExpo(duration: 0.4)) { hasOnboarded = true }
                })
            }
        }
        .preferredColorScheme(.dark)
    }

    private var tabs: some View {
        TabView {
            ContentView()
                .tabItem { Label("Scan", systemImage: "barcode.viewfinder") }

            RecentsView()
                .tabItem { Label("History", systemImage: "clock.fill") }

            VerifyQueueView()
                .tabItem { Label("Verify", systemImage: "checkmark.shield.fill") }

            ProfileView()
                .tabItem { Label("You", systemImage: "person.fill") }
        }
        .tint(TLColor.accent)
    }
}

#Preview {
    RootView()
}
