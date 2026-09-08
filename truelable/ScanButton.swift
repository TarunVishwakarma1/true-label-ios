//
//  ScanButton.swift
//  truelable
//

import SwiftUI

struct ScanButton: View {
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
                TimelineView(.animation) { timeline in
                    let duration = 2.5
                    let raw = timeline.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: duration) / duration
                    let progress = (1 - cos(.pi * 2 * raw)) / 2 // eased, seamless loop

                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(0.06), location: 0),
                                    .init(color: .white.opacity(0.7), location: progress),
                                    .init(color: .white.opacity(0.06), location: 1)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1.5
                        )
                }
            }
            .shadow(color: .black.opacity(0.25), radius: 20, y: 8)
        }
        .buttonStyle(ScaleButtonStyle())
        .task {
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
