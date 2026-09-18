import WidgetKit
import SwiftUI

private enum WidgetTL {

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
        ScanLiveActivity()
    }
}
