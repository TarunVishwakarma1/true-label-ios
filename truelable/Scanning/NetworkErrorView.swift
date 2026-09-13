//
//  NetworkErrorView.swift
//  truelable
//

import SwiftUI

/// A real connectivity failure — distinct from `ProductNotFoundView`
/// (a successful lookup that genuinely isn't in the catalogue). See
/// `ScannerView.handle(_:)`'s `catch` branch.
struct NetworkErrorView: View {
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            DotGridBackground()

            VStack(spacing: 16) {
                Spacer()

                Image(systemName: "wifi.slash")
                    .font(.system(size: 40))
                    .foregroundStyle(.white.opacity(0.7))

                Text("No connection")
                    .font(.system(size: 24, weight: .bold))
                    .tracking(-0.4)

                Text("Couldn't reach the server. Check your connection and try scanning again.")
                    .font(.system(size: 15.5))
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)

                Spacer()

                Button("Try again", action: onDismiss)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .primaryCTAStyle()
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 40)

            VStack {
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
                Spacer()
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    NetworkErrorView(onDismiss: {})
}
