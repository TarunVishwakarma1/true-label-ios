//
//  QuickScanWidget.swift
//  QuickScanWidgetExtension
//
//  Static on purpose: no scan streak, no live counts. Reading anything from
//  the main app (history, verified count) would need an App Group, which
//  needs a paid Apple Developer Program membership to register — the same
//  constraint that already keeps Sign in with Apple off in
//  truelable.entitlements. A widget with nothing to say until that exists
//  is still a real value: one tap from the Home Screen straight into Scan,
//  no app-switch-then-tap-Scan round trip.
//

import WidgetKit
import SwiftUI

private enum WidgetTL {
    // Mirrors TL.bg / TL.accent in Design/Theme.swift. Duplicated rather
    // than shared because this target can't see the app target's source
    // without cross-target file membership on the synchronized group —
    // two color constants isn't worth that complexity.
    static let bg = Color(red: 0x0C / 255, green: 0x0B / 255, blue: 0x0A / 255)
    static let accent = Color(red: 0xEF / 255, green: 0xE6 / 255, blue: 0xD4 / 255)
}

struct QuickScanEntry: TimelineEntry {
    let date: Date
}

struct QuickScanProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickScanEntry {
        QuickScanEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickScanEntry) -> Void) {
        completion(QuickScanEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickScanEntry>) -> Void) {
        // Content never changes, so one entry with no refresh is correct —
        // there is nothing a reload would ever pick up.
        completion(Timeline(entries: [QuickScanEntry(date: .now)], policy: .never))
    }
}

struct QuickScanWidgetView: View {
    var body: some View {
        ZStack {
            WidgetTL.bg
            VStack(spacing: 10) {
                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(WidgetTL.accent)
                Text("Scan")
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(.white)
            }
        }
        // The one entry point back into the app: TrueLabelApp's onOpenURL
        // matches this scheme+host and sets router.scannerPresented —
        // the exact same trigger the empty History state already uses.
        .widgetURL(URL(string: "truelabel://scan"))
    }
}

struct QuickScanWidget: Widget {
    let kind = "QuickScanWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickScanProvider()) { _ in
            QuickScanWidgetView()
                .containerBackground(WidgetTL.bg, for: .widget)
        }
        .configurationDisplayName("Quick Scan")
        .description("One tap from the Home Screen straight into scanning.")
        .supportedFamilies([.systemSmall])
    }
}

@main
struct QuickScanWidgetBundle: WidgetBundle {
    var body: some Widget {
        QuickScanWidget()
    }
}
