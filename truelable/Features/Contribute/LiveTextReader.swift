//
//  LiveTextReader.swift
//  truelable
//
//  Live, multi-frame text capture. VisionKit keeps recognising while the
//  user holds the label steady; every frame's lines are folded into a
//  running tally so a single blurred or partial frame never decides the
//  result. "Capture" returns the lines that held up across frames, in
//  reading order, with their on-screen height (the brand is nearly always
//  the tallest text on the front of a pack).
//

import SwiftUI
import Vision
import VisionKit

struct TextLine: Hashable, Sendable {
    var text: String
    var height: CGFloat
    var y: CGFloat
}

struct TextTake: Hashable, Sendable {
    var lines: [TextLine]
    var raw: String { lines.map(\.text).joined(separator: "\n") }
    var isEmpty: Bool { lines.isEmpty }
}

/// Owned by the screen; the camera writes into it, the screen reads it.
@Observable
final class TextTally {
    private struct Entry { var count = 0; var height: CGFloat = 0; var y: CGFloat = 0; var variants: [String: Int] = [:] }
    private var entries: [String: Entry] = [:]
    private var latest: Set<String> = []
    private var frames = 0
    private(set) var lockedCount = 0

    func ingest(_ items: [RecognizedItem]) {
        frames += 1
        var seen: Set<String> = []
        for case let .text(text) in items {
            let raw = text.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            guard raw.count >= 2 else { continue }
            let key = raw.lowercased()
            seen.insert(key)
            let b = text.bounds
            let height = hypot(b.bottomLeft.x - b.topLeft.x, b.bottomLeft.y - b.topLeft.y)
            let y = (b.topLeft.y + b.bottomLeft.y) / 2
            var e = entries[key] ?? Entry()
            e.count += 1
            e.height = max(e.height, height)
            e.y = y
            e.variants[raw, default: 0] += 1
            entries[key] = e
        }
        latest = seen
        lockedCount = entries.values.filter { $0.count >= 2 }.count
    }

    /// Lines seen on at least two frames, or on the latest one (so a fresh
    /// steady hold still counts), ordered top-to-bottom.
    func capture() -> TextTake {
        let lines = entries
            .filter { $0.value.count >= 2 || latest.contains($0.key) }
            .map { key, e -> TextLine in
                let best = e.variants.max { $0.value < $1.value }?.key ?? key
                return TextLine(text: best, height: e.height, y: e.y)
            }
            .sorted { $0.y < $1.y }
        return TextTake(lines: lines)
    }

    func reset() {
        entries = [:]
        latest = []
        frames = 0
        lockedCount = 0
    }
}

struct LiveTextReader<Overlay: View>: UIViewControllerRepresentable {
    let tally: TextTally
    @ViewBuilder var overlay: () -> Overlay

    static var isUsable: Bool { DataScannerViewController.isSupported }

    /// English plus whatever the device prefers, limited to what the
    /// recognizer actually supports — Hindi/Devanagari brand marks on
    /// Indian packs come through when the device can read them.
    private static var languages: [String] {
        let supported = DataScannerViewController.supportedTextRecognitionLanguages
        var wanted = ["en-US", "en-IN", "hi-IN"] + Locale.preferredLanguages
        wanted = wanted.filter { supported.contains($0) }
        return wanted.isEmpty ? [] : Array(NSOrderedSet(array: wanted)) as? [String] ?? []
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.text(languages: Self.languages)],
            qualityLevel: .accurate,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: false,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        controller.view.backgroundColor = .black

        let hosting = UIHostingController(rootView: overlay())
        hosting.view.backgroundColor = .clear
        controller.addChild(hosting)
        controller.view.addSubview(hosting.view)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        let guide = controller.view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: guide.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: guide.bottomAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: guide.trailingAnchor)
        ])
        hosting.didMove(toParent: controller)
        context.coordinator.hosting = hosting
        try? controller.startScanning()
        return controller
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {
        context.coordinator.hosting?.rootView = overlay()
    }

    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) {
        controller.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(tally: tally) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let tally: TextTally
        var hosting: UIHostingController<Overlay>?
        init(tally: TextTally) { self.tally = tally }

        func dataScanner(_ scanner: DataScannerViewController, didAdd items: [RecognizedItem], allItems: [RecognizedItem]) {
            tally.ingest(allItems)
        }
        func dataScanner(_ scanner: DataScannerViewController, didUpdate items: [RecognizedItem], allItems: [RecognizedItem]) {
            tally.ingest(allItems)
        }
        func dataScanner(_ scanner: DataScannerViewController, didRemove items: [RecognizedItem], allItems: [RecognizedItem]) {
            tally.ingest(allItems)
        }
    }
}
