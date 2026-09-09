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

            VStack(spacing: 16) {
                Spacer()

                Image(systemName: "questionmark.square.dashed")
                    .font(.system(size: 44))
                    .foregroundStyle(.white.opacity(0.7))

                Text("This product isn't in our catalogue yet")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Help us add it — it only takes a photo of the ingredient label.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)

                Text(barcode)
                    .font(.system(.footnote, design: .monospaced))
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
