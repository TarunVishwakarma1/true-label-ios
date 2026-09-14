//
//  ScanScreen.swift
//  truelable
//
//  Full-screen camera. A recognised barcode opens the product as a sheet
//  over the (paused) camera — swipe it away and you're scanning again, no
//  re-entry. Chrome is one static reticle and one moving line; nothing
//  else animates, so the camera + Vision get the whole GPU budget.
//

import SwiftUI
import AVFoundation
import UIKit
import VisionKit

struct ScanScreen: View {
    @Environment(\.dismiss) private var dismiss

    /// One sheet, by value — two `.sheet` modifiers on a single view race
    /// each other within a frame.
    private enum Presented: Identifiable {
        case product(String)
        case manualEntry

        var id: String {
            switch self {
            case .product(let barcode): "product-\(barcode)"
            case .manualEntry: "manual"
            }
        }
    }

    @State private var presented: Presented?
    @State private var qr: String?
    @State private var invalid: String?
    @State private var torch = false
    @State private var lastCode: String?
    @State private var lastSeen = Date.distantPast
    @State private var scanned = 0
    @State private var invalidCount = 0
    /// nil until the camera permission question is settled.
    @State private var authorized: Bool?

    private var usable: Bool { authorized == true && DataScannerViewController.isSupported }
    private var cameraActive: Bool { presented == nil && qr == nil }

    var body: some View {
        Group {
            if usable && cameraActive {
                ScannerCamera(torch: torch, onScan: handle) { chrome }
                    .ignoresSafeArea()
                    .transition(.opacity)
            } else {
                ZStack {
                    if authorized != nil { chrome }
                }
                .screenBackground()
                .transition(.opacity)
            }
        }
        .animation(.tl(0.35), value: cameraActive)
        .task {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: authorized = true
            case .notDetermined: authorized = await AVCaptureDevice.requestAccess(for: .video)
            default: authorized = false
            }
        }
        .preferredColorScheme(.dark)
        .sheet(item: $presented, onDismiss: { lastSeen = .now }) { item in
            switch item {
            case .product(let barcode):
                NavigationStack {
                    ProductLoaderScreen(barcode: barcode, inSheet: true)
                        .navigationDestination(for: String.self) { ProductLoaderScreen(barcode: $0) }
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(TL.bg)
                .presentationCornerRadius(TL.R.xl)
            case .manualEntry:
                ManualEntrySheet()
            }
        }
        .sensoryFeedback(.success, trigger: scanned)
        .sensoryFeedback(.warning, trigger: invalidCount)
        .onDisappear { Torch.set(false) }
    }

    // MARK: Chrome

    private var chrome: some View {
        ZStack {
            VStack(spacing: 0) {
                topBar
                Spacer()
                if usable {
                    reticle
                } else {
                    unavailable
                }
                Spacer()
                bottomBar
            }

            if let invalid {
                toast("“\(invalid)” isn't a product barcode", icon: "exclamationmark.triangle.fill", tint: TL.warn)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 110)
            }

            if let qr {
                qrCard(qr)
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
        }
        .animation(.tl(0.35), value: invalid)
        .animation(.tl(0.35), value: qr)
    }

    private var topBar: some View {
        HStack {
            IconButton(systemImage: "xmark", label: "Close") { dismiss() }
            Spacer()
            Text("Scan")
                .font(.headline)
                .foregroundStyle(.white)
            Spacer()
            if usable && Torch.isAvailable {
                IconButton(systemImage: torch ? "flashlight.on.fill" : "flashlight.off.fill", label: "Torch", active: torch) {
                    torch.toggle()
                    Torch.set(torch)
                }
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var reticle: some View {
        VStack(spacing: 20) {
            Text(cameraActive ? "Point at a barcode" : "Camera off while you read")
                .font(.caption.weight(.semibold))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .glassEffect(.regular, in: .capsule)
                // The frame below is a pure visual guide with nothing for
                // VoiceOver to add — this text already says everything a
                // non-visual user needs, and a barcode-scanning camera has
                // no accessible fallback here besides "Type the barcode"
                // in the bottom bar, which is its own real control already.
                .accessibilityLabel(
                    cameraActive
                        ? "Point your camera at a barcode to scan, or use Type the barcode below"
                        : "Camera off while you read the result"
                )

            ZStack {
                RoundedRectangle(cornerRadius: TL.R.xl, style: .continuous)
                    .fill(TL.accent.opacity(cameraActive ? 0.06 : 0))
                ReticleCorners()
                    .stroke(cameraActive ? .white : TL.fg3, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .shadow(color: TL.accent.opacity(cameraActive ? 0.5 : 0), radius: 12)
                if cameraActive {
                    ScanLine()
                }
            }
            .frame(width: 250, height: 250)
            .accessibilityHidden(true)
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 16) {
            Text("Works on EAN and UPC barcodes on packaged food.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.6))
            Button {
                presented = .manualEntry
            } label: {
                Label("Type the barcode", systemImage: "keyboard")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .glassEffect(.regular.interactive(), in: .capsule)
            }
            .buttonStyle(.pressable)
        }
        .padding(.bottom, 24)
    }

    private var unavailable: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.largeTitle)
                .foregroundStyle(TL.fg3)
            Text("Camera isn't available")
                .font(.title3.weight(.semibold))
            Text("Allow camera access in Settings to scan, or type the barcode below.")
                .font(.subheadline)
                .foregroundStyle(TL.fg2)
                .multilineTextAlignment(.center)
            if let url = URL(string: UIApplication.openSettingsURLString) {
                Link("Open Settings", destination: url)
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding(.horizontal, 40)
    }

    private func toast(_ text: String, icon: String, tint: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: .capsule)
            .padding(.horizontal, 24)
    }

    private func qrCard(_ value: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "qrcode")
                .font(.largeTitle)
            Text("That's a QR code, not a product barcode")
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
            Text(value)
                .font(.footnote.monospaced())
                .foregroundStyle(TL.fg2)
                .lineLimit(4)
                .multilineTextAlignment(.center)
            HStack(spacing: 12) {
                if let url = URL(string: value), url.scheme?.hasPrefix("http") == true {
                    Link(destination: url) {
                        Label("Open", systemImage: "safari").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.secondary)
                }
                Button {
                    UIPasteboard.general.string = value
                    qr = nil
                } label: {
                    Label("Copy", systemImage: "doc.on.doc").frame(maxWidth: .infinity)
                }
                .buttonStyle(.secondary)
            }
            Button("Keep scanning") { qr = nil }
                .buttonStyle(.primary)
        }
        .engraved()
        .padding(22)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: TL.R.xl, style: .continuous))
        .padding(.horizontal, 28)
    }

    // MARK: Handling

    private func handle(_ result: ScanResult) {
        guard cameraActive else { return }
        switch result {
        case .qr(let value):
            qr = value
        case .barcode(let code):
            // The same code lingering in view right after its sheet was
            // dismissed shouldn't reopen it.
            if code == lastCode, Date.now.timeIntervalSince(lastSeen) < 3 { return }
            lastCode = code
            lastSeen = .now
            guard BarcodeChecksum.isValid(code) else {
                invalid = code
                invalidCount += 1
                Task {
                    try? await Task.sleep(for: .seconds(2.2))
                    if invalid == code { invalid = nil }
                }
                return
            }
            scanned += 1
            presented = .product(BarcodeChecksum.normalized(code))
        }
    }
}

private struct ScanLine: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var down = false

    var body: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(TL.accent)
                .frame(height: 2)
                .shadow(color: TL.accent.opacity(0.8), radius: 6)
                .offset(y: down ? geo.size.height * 0.92 : geo.size.height * 0.08)
        }
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) { down = true }
        }
    }
}

private struct ReticleCorners: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c: CGFloat = 26, r: CGFloat = 22
        // Rounded corner brackets.
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + c))
        p.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.minX + c, y: rect.minY), radius: r)
        p.addLine(to: CGPoint(x: rect.minX + c, y: rect.minY))

        p.move(to: CGPoint(x: rect.maxX - c, y: rect.minY))
        p.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.minY + c), radius: r)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + c))

        p.move(to: CGPoint(x: rect.maxX, y: rect.maxY - c))
        p.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.maxX - c, y: rect.maxY), radius: r)
        p.addLine(to: CGPoint(x: rect.maxX - c, y: rect.maxY))

        p.move(to: CGPoint(x: rect.minX + c, y: rect.maxY))
        p.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.maxY - c), radius: r)
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - c))
        return p
    }
}

/// Number pad entry with live check-digit validation; a valid code pushes
/// straight into the loader inside this sheet's own stack.
struct ManualEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var path: [String] = []
    @FocusState private var focused: Bool

    private var digits: String { code.filter(\.isNumber) }
    private var valid: Bool { BarcodeChecksum.isValid(digits) }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(alignment: .leading, spacing: 20) {
                Text("Type the barcode")
                    .font(.title2.weight(.bold))
                Text("The 8, 12 or 13 digits printed under the bars.")
                    .font(.subheadline)
                    .foregroundStyle(TL.fg2)

                TextField("8901234567890", text: $code)
                    .keyboardType(.numberPad)
                    .font(.system(.title2, design: .monospaced).weight(.semibold))
                    .focused($focused)
                    .padding(18)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: TL.R.md, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: TL.R.md, style: .continuous).strokeBorder(valid ? TL.accent : .clear))
                    // Without this, VoiceOver reads the placeholder digits
                    // themselves as the field's name — a real number read
                    // out is a strange way to hear "this is the barcode
                    // field." The digit count already updates live below,
                    // so the hint doesn't need to repeat it.
                    .accessibilityLabel("Barcode")
                    .accessibilityHint("8, 12, or 13 digits")
                    .onChange(of: code) { _, new in
                        let filtered = String(new.filter(\.isNumber).prefix(13))
                        if filtered != new { code = filtered }
                    }

                HStack(spacing: 8) {
                    Image(systemName: valid ? "checkmark.circle.fill" : "circle.dotted")
                        .foregroundStyle(valid ? TL.accent : TL.fg3)
                    Text(valid ? "Looks like a valid barcode" : "\(digits.count) digit\(digits.count == 1 ? "" : "s")")
                        .foregroundStyle(TL.fg3)
                }
                .font(.footnote.weight(.medium))
                .animation(.tl(0.25), value: valid)

                Spacer()

                Button("Look it up") {
                    focused = false
                    path.append(BarcodeChecksum.normalized(digits))
                }
                .buttonStyle(.primary)
                .disabled(!valid)
                .opacity(valid ? 1 : 0.5)
            }
            .padding(24)
            .screenBackground()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
            .navigationDestination(for: String.self) { ProductLoaderScreen(barcode: $0) }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(TL.bg)
        .presentationCornerRadius(32)
    }
}

#Preview {
    ScanScreen()
        .preferredColorScheme(.dark)
}
