//
//  ProductNotFoundView.swift
//  truelable
//

import SwiftUI

/// Shown when a scanned barcode is valid but isn't in the catalogue yet.
/// Owns presenting the contribution wizard itself, so ScannerView only
/// needs to know "show this screen for this barcode."
struct ProductNotFoundView: View {
    var barcode: String
    var onDismiss: () -> Void

    @State private var isContributing = false

    var body: some View {
        ZStack {
            // Paused while the contribution flow covers this screen —
            // otherwise this aurora keeps rendering, unseen, underneath it.
            DotGridBackground(isPaused: isContributing)

            VStack(spacing: 20) {
                Spacer()

                statusBadge

                Image(systemName: "questionmark.square.dashed")
                    .font(.system(size: 44))
                    .foregroundStyle(.white.opacity(0.7))

                Text("Not in the catalogue yet")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Help us add it — it only takes a photo of the ingredient label.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)

                Text(barcode)
                    .font(.system(.footnote, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.4))

                Spacer()

                Button {
                    isContributing = true
                } label: {
                    Text("Help Us Add It")
                        .font(.headline)
                        .foregroundStyle(.accentLabel)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .glassEffect(.regular.tint(.accentColor), in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())

                Button("Not Now", action: onDismiss)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.top, 4)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)

            VStack {
                topBar
                Spacer()
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $isContributing) {
            ContributeProductView(barcode: barcode, onFinished: onDismiss)
        }
    }

    /// Same monospace HUD-status language as `ScannerView`'s badge — this
    /// screen used to look like a different app pasted into this one.
    private var statusBadge: some View {
        Text("NOT FOUND")
            .font(.system(.caption, design: .monospaced))
            .fontWeight(.medium)
            .tracking(1.2)
            .foregroundStyle(TLColor.warn)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(TLColor.warn.opacity(0.15), in: Capsule())
            .overlay(Capsule().strokeBorder(TLColor.warn.opacity(0.4)))
    }

    private var topBar: some View {
        HStack {
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .padding(12)
                    .glassEffect(.regular, in: Circle())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}

#Preview {
    ProductNotFoundView(barcode: "1234567890123", onDismiss: {})
}
