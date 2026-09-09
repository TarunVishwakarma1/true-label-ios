//
//  ScanButton.swift
//  truelable
//

import SwiftUI

struct ScanButton: View {
    /// Freezes the icon-swap loop and the border animation — used while
    /// this button sits (still mounted, still rendering) behind a
    /// fullScreenCover, where none of it is even visible.
    var isPaused: Bool = false
    var action: () -> Void

    @State private var showQRIcon = true

    var body: some View {
        Button(action: action) {
            HStack {
                Text("Scan")
                Image(systemName: showQRIcon ? "qrcode" : "barcode")
                    .contentTransition(.symbolEffect(.replace))
            }
            .font(.headline)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .foregroundStyle(.white)
            .glassEffect(.regular, in: Capsule())
            .overlay {
                AnimatedGradientBorder(shape: Capsule(), isPaused: isPaused)
            }
            .shadow(color: .black.opacity(0.25), radius: 20, y: 8)
        }
        .buttonStyle(ScaleButtonStyle())
        .task(id: isPaused) {
            guard !isPaused else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.2))
                withAnimation {
                    showQRIcon.toggle()
                }
            }
        }
    }
}

#Preview {
    ScanButton(action: {})
}
