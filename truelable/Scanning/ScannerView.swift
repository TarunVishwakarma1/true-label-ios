//
//  ScannerView.swift
//  truelable
//

import SwiftUI
import UIKit
import VisionKit

/// Full-screen scan flow: live camera via VisionKit, a manual-entry
/// fallback for typed barcode digits, and a result card for whichever
/// happens — a QR payload just gets displayed, a barcode gets checksum-
/// validated locally then handed to `ProductAPIClient`.
struct ScannerView: View {
    var onDismiss: () -> Void

    private enum Phase: Equatable {
        case scanning
        case submitting
        case result(Outcome)
        case showingProduct // a full-screen destination is up; keep the camera paused
    }

    private enum Outcome: Equatable {
        case qr(String)
        case invalidBarcode(String)
    }

    /// Identifiable so it can drive a single `.fullScreenCover(item:)` for
    /// whichever destination a barcode lookup lands on.
    private enum ProductLookupResult: Identifiable, Equatable {
        case found(ProductInfo)
        case notFound(String)

        var id: String {
            switch self {
            case .found(let info): return info.barcode
            case .notFound(let code): return code
            }
        }
    }

    @State private var phase: Phase = .scanning
    @State private var manualCode: String = ""
    @State private var didCopyQR = false
    @State private var productLookup: ProductLookupResult?
    @State private var caretVisible = true
    @FocusState private var manualFieldFocused: Bool

    /// Mirrors the website's `scan-demo.tsx`: `found = phase !== "scan"`.
    /// Only meaningful while the viewfinder itself is on screen — briefly
    /// true the instant a lookup starts, until the result sheet takes over.
    private var found: Bool { phase == .submitting }

    // DataScannerViewController needs real camera hardware, so it's never
    // available in the simulator. Checked once at screen open — manual
    // entry works either way, so that's not fatal, just less convenient.
    private let scannerAvailable = DataScannerViewController.isSupported && DataScannerViewController.isAvailable

    var body: some View {
        Group {
            if scannerAvailable {
                // The chrome is hosted *inside* the scanner's own view
                // controller (see BarcodeScannerRepresentable) so it's a
                // real UIKit subview guaranteed to win touches, instead of
                // a SwiftUI sibling that DataScannerViewController's own
                // gesture recognizers could steal from.
                BarcodeScannerRepresentable(onScan: handle, isScanningActive: !manualFieldFocused && phase == .scanning) { chrome }
            } else {
                PremiumBackground(isPaused: productLookup != nil)
                    .overlay { chrome }
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .onAppear { print("[ScannerView] appeared") }
        .onDisappear { print("[ScannerView] disappeared") }
        .fullScreenCover(item: $productLookup) { lookup in
            switch lookup {
            case .found(let product):
                ProductFoundFlow(product: product, onDismiss: finishProductLookup)
            case .notFound(let code):
                ProductNotFoundView(barcode: code, onDismiss: finishProductLookup)
            }
        }
    }

    @ViewBuilder
    private var chrome: some View {
        VStack {
            topBar

            Spacer()

            if scannerAvailable, phase == .scanning || phase == .submitting {
                VStack(spacing: 16) {
                    statusBadge
                    viewfinder
                }
            } else if !scannerAvailable {
                unavailableNotice
            }

            Spacer()

            bottomCard
        }
        .contentShape(Rectangle())
        .onTapGesture { manualFieldFocused = false } // tap anywhere empty to dismiss the keyboard; tapping the field re-focuses it as usual
        .overlay {
            if case .result(let outcome) = phase {
                resultOverlay(outcome)
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                print("[ScannerView] close button tapped")
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .padding(12)
                    .glassEffect(.regular, in: Circle())
            }
            .buttonStyle(ScaleButtonStyle())

            Spacer()

            Text("Scan Product")
                .font(.headline)
                .foregroundStyle(.white)

            Spacer()

            Color.clear.frame(width: 44, height: 44) // balances the close button so the title stays centered
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    /// Monospace status pill above the viewfinder, matching the website's
    /// `scan-demo.tsx`: "POINT AT A BARCODE" with a blinking caret while
    /// scanning, a solid-accent "FOUND · VERIFIED" pill the instant a
    /// lookup starts.
    private var statusBadge: some View {
        HStack(spacing: 2) {
            Text(found ? "FOUND · VERIFIED" : "POINT AT A BARCODE")
            if !found {
                Text("_").opacity(caretVisible ? 1 : 0)
            }
        }
        .font(.system(.caption, design: .monospaced))
        .fontWeight(.medium)
        .tracking(1.2)
        .foregroundStyle(found ? TLColor.ink : .white.opacity(0.85))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(found ? TLColor.accent : Color.white.opacity(0.1), in: Capsule())
        .animation(.easeOutExpo(duration: 0.5), value: found)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                caretVisible.toggle()
            }
        }
    }

    private var viewfinder: some View {
        Color.clear
            .frame(width: 260, height: 260)
            .overlay(AnimatedGradientBorder(shape: RoundedRectangle(cornerRadius: 28)))
            .overlay(
                ViewfinderCorners()
                    .stroke(found ? TLColor.accent : .white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .animation(.easeOutExpo(duration: 0.5), value: found)
            )
            .overlay {
                // One animating line, not a background — cheap enough to
                // stay well clear of the glass-over-animation lesson learned
                // elsewhere in this app (see ProductDetailView's doc comment).
                if phase == .scanning {
                    ScanLine()
                }
            }
            .overlay {
                if phase == .submitting {
                    ProgressView().tint(.white)
                }
            }
    }

    private var unavailableNotice: some View {
        VStack(spacing: 8) {
            Image(systemName: "camera.metering.unknown")
                .font(.system(size: 28))
                .foregroundStyle(.white.opacity(0.6))
            Text("Camera scanning isn't available here")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var bottomCard: some View {
        VStack(spacing: 12) {
            Text("Or enter the barcode digits")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))

            HStack(spacing: 10) {
                TextField("", text: $manualCode, prompt: Text("e.g. 8901234567890").foregroundStyle(.white.opacity(0.35)))
                    .keyboardType(.numberPad)
                    .focused($manualFieldFocused)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .glassEffect(.regular, in: Capsule())

                Button {
                    print("[ScannerView] manual submit tapped")
                    manualFieldFocused = false
                    handle(.barcode(manualCode.trimmingCharacters(in: .whitespaces)))
                } label: {
                    Image(systemName: "arrow.right")
                        .font(.headline)
                        .foregroundStyle(.accentLabel)
                        .padding(14)
                        .glassEffect(.regular.tint(.accentColor), in: Circle())
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(manualCode.isEmpty)
            }
        }
        .padding(20)
    }

    @ViewBuilder
    private func resultOverlay(_ outcome: Outcome) -> some View {
        // No tap-anywhere-to-dismiss on this scrim: a full-screen gesture
        // recognizer sitting behind the card is a prime suspect for
        // stealing taps meant for controls inside the card (like the copy
        // button) — "Scan Again" already covers dismissal explicitly.
        Color.black.opacity(0.55)
            .ignoresSafeArea()

        VStack(spacing: 16) {
            switch outcome {
            case .qr(let value):
                Image(systemName: "qrcode")
                    .font(.system(size: 34))
                    .foregroundStyle(.white)
                Text("QR Code")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                HStack(spacing: 10) {
                    Text(value)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Button {
                        print("[ScannerView] copy button tapped, value=\(value)")
                        copyToClipboard(value)
                        withAnimation { didCopyQR = true }
                        Task {
                            try? await Task.sleep(for: .seconds(1.5))
                            withAnimation { didCopyQR = false }
                        }
                    } label: {
                        Image(systemName: didCopyQR ? "checkmark" : "doc.on.doc")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .padding(8)
                            .glassEffect(.regular, in: Circle())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }

            case .invalidBarcode(let code):
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.yellow)
                Text(code)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.white)
                Text("That doesn't look like a valid barcode")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }

            Button("Scan Again", action: reset)
                .font(.headline)
                .foregroundStyle(.accentLabel)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .glassEffect(.regular.tint(.accentColor), in: Capsule())
                .buttonStyle(ScaleButtonStyle())
        }
        .padding(28)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28))
        .padding(.horizontal, 40)
    }

    private func handle(_ result: ScanResult) {
        print("[ScannerView] handle called with \(result), current phase=\(phase)")
        guard phase == .scanning else { return } // still showing/submitting a previous result
        switch result {
        case .qr(let value):
            withAnimation { phase = .result(.qr(value)) }

        case .barcode(let code):
            guard BarcodeChecksum.isValid(code) else {
                withAnimation { phase = .result(.invalidBarcode(code)) }
                return
            }
            let normalized = BarcodeChecksum.normalized(code)
            phase = .submitting
            Task {
                let product = try? await ProductAPIClient.lookupProduct(barcode: normalized)
                withAnimation { phase = .showingProduct }
                productLookup = product.map(ProductLookupResult.found) ?? .notFound(code)
            }
        }
    }

    private func finishProductLookup() {
        productLookup = nil
        reset()
    }

    /// UIPasteboard can transiently fail right after camera/session activity
    /// with "Pasteboard ... is not available at this time" — seen in
    /// on-device testing. One quick retry clears it up.
    private func copyToClipboard(_ value: String) {
        UIPasteboard.general.string = value
        if UIPasteboard.general.string == value {
            print("[ScannerView] pasteboard write succeeded")
        } else {
            print("[ScannerView] pasteboard write failed, retrying")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                UIPasteboard.general.string = value
                print("[ScannerView] retry result: \(UIPasteboard.general.string == value ? "succeeded" : "failed again")")
            }
        }
    }

    private func reset() {
        withAnimation {
            phase = .scanning
            manualCode = ""
        }
    }
}

/// A single accent line sweeping top-to-bottom while the viewfinder waits
/// for a barcode — matches the website's `@keyframes scan` (2.2s, 6%→94%).
private struct ScanLine: View {
    @State private var atBottom = false

    var body: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(TLColor.accent)
                .frame(height: 2)
                .shadow(color: TLColor.accent.opacity(0.8), radius: 6)
                .offset(y: atBottom ? geo.size.height * 0.94 : geo.size.height * 0.06)
                .opacity(0.9)
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                atBottom = true
            }
        }
    }
}

/// Four corner brackets, the classic scanner-reticle targeting mark.
private struct ViewfinderCorners: Shape {
    var cornerLength: CGFloat = 24

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let c = cornerLength

        path.move(to: CGPoint(x: rect.minX, y: rect.minY + c))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + c, y: rect.minY))

        path.move(to: CGPoint(x: rect.maxX - c, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + c))

        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - c))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - c, y: rect.maxY))

        path.move(to: CGPoint(x: rect.minX + c, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - c))

        return path
    }
}

#Preview {
    ScannerView(onDismiss: {})
}
