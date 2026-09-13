//
//  ContentView.swift
//  truelable
//
//  Created by Tarun Vishwakarma on 08/09/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var isScanning = false
    @Query(sort: \ScanHistoryEntry.scannedAt, order: .reverse) private var recentEntries: [ScanHistoryEntry]
    @AppStorage("stats.verificationsSubmitted") private var verificationsSubmitted = 0

    private var previewEntries: [ScanHistoryEntry] { Array(recentEntries.prefix(3)) }

    var body: some View {
        ZStack {
            DotGridBackground(isPaused: isScanning)

            VStack(spacing: 0) {
                header
                    .padding(.top, 16)

                Spacer(minLength: 20)

                VStack(spacing: 20) {
                    IdleBarcodeMotif(isPaused: isScanning)
                    Text("READY TO SCAN")
                        .font(.system(.caption2, design: .monospaced))
                        .tracking(2.5)
                        .foregroundStyle(.white.opacity(0.35))
                }

                Spacer(minLength: 20)

                if !previewEntries.isEmpty {
                    recentsPreview
                        .padding(.bottom, 20)
                }

                ScanButton(isPaused: isScanning) {
                    isScanning = true
                }
                .padding(.bottom, 48)
            }
        }
        .fullScreenCover(isPresented: $isScanning) {
            ScannerView(onDismiss: {
                print("[ContentView] onDismiss closure fired, setting isScanning = false")
                isScanning = false
            })
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            wordmark
            Spacer()
            if !recentEntries.isEmpty {
                statPill(value: "\(recentEntries.count)", label: "scanned")
                if verificationsSubmitted > 0 {
                    statPill(value: "\(verificationsSubmitted)", label: "verified")
                }
            }
        }
        .padding(.horizontal, 24)
    }

    private var wordmark: some View {
        HStack(spacing: 6) {
            Text("True")
                .foregroundStyle(.white)
            Text("Label")
                .foregroundStyle(TLColor.accent)
        }
        .font(.system(.title3, design: .rounded).weight(.bold))
    }

    private func statPill(value: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(value).font(.system(.caption, design: .monospaced).bold())
            Text(label).font(.system(.caption2, design: .monospaced))
        }
        .foregroundStyle(.white.opacity(0.5))
        .padding(.horizontal, 4)
    }

    /// The single biggest fix for "the home screen looks empty" — real
    /// content pulled from `ScanHistoryEntry` (see `RecentsView` for the
    /// full list), not a static placeholder.
    private var recentsPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RECENTLY SCANNED")
                .font(.system(.caption2, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.35))
                .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(previewEntries) { entry in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(entry.name)
                                .font(.system(.caption, design: .monospaced).weight(.medium))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text("\(entry.calories) kcal")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                        .frame(width: 140, alignment: .leading)
                        .padding(12)
                        .background(TLColor.surface.opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.08)))
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }
}

/// A quiet "the scanner is alive and ready" heartbeat — reuses the
/// discrete-pulse `.task`/sleep-loop pattern already established in
/// `ScanButton` (not a `TimelineView`, since this is a periodic discrete
/// event, not continuous per-frame motion) so the home screen has some
/// presence instead of reading as an empty placeholder behind one button.
private struct IdleBarcodeMotif: View {
    var isPaused: Bool

    @State private var pulsed = false
    private let bars: [CGFloat] = (0..<28).map { i in CGFloat((i * 37) % 4 + 1) }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(bars.enumerated()), id: \.offset) { _, width in
                RoundedRectangle(cornerRadius: 1)
                    .fill(pulsed ? TLColor.accent : Color.white.opacity(0.22))
                    .frame(width: width, height: 36)
            }
        }
        .animation(.easeOutExpo(duration: 0.7), value: pulsed)
        .task(id: isPaused) {
            guard !isPaused else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2.8))
                pulsed = true
                try? await Task.sleep(for: .seconds(0.7))
                pulsed = false
            }
        }
    }
}

#Preview {
    ContentView()
}
