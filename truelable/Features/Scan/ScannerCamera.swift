//
//  ScannerCamera.swift
//  truelable
//
//  VisionKit's DataScannerViewController, with the SwiftUI chrome hosted
//  *inside* the scanner's own view hierarchy. The scanner has its own
//  gesture recognizers (tap-to-focus, item selection) that can beat a
//  SwiftUI sibling for touches; a UIKit child view added last always wins.
//

import SwiftUI
import AVFoundation
import Vision
import VisionKit

enum ScanResult: Equatable {
    case barcode(String)
    case qr(String)
}

struct ScannerCamera<Overlay: View>: UIViewControllerRepresentable {
    /// Mounted means scanning. The screen unmounts this view entirely while
    /// anything renders over it, so the capture session and Vision stop
    /// costing anything until they're needed again.
    var torch: Bool
    var onScan: (ScanResult) -> Void
    @ViewBuilder var overlay: () -> Overlay

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce, .qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
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
        context.coordinator.torch = torch
        if torch {
            // The torch only takes once the session is running.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(450))
                Torch.set(true)
            }
        }
        return controller
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {
        context.coordinator.hosting?.rootView = overlay()
        guard context.coordinator.torch != torch else { return }
        context.coordinator.torch = torch
        Torch.set(torch)
    }

    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) {
        controller.stopScanning()
        Torch.set(false)
    }

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (ScanResult) -> Void
        var hosting: UIHostingController<Overlay>?
        var torch = false

        // A checksum alone lets ~1 in 10 misreads through. Requiring the same
        // payload on two consecutive frames filters out the rest — a real
        // barcode decodes identically frame after frame, a misread doesn't.
        private var pending: String?
        private var pendingCount = 0

        init(onScan: @escaping (ScanResult) -> Void) { self.onScan = onScan }

        func dataScanner(_ scanner: DataScannerViewController, didAdd items: [RecognizedItem], allItems: [RecognizedItem]) {
            items.forEach(confirm)
        }

        func dataScanner(_ scanner: DataScannerViewController, didUpdate items: [RecognizedItem], allItems: [RecognizedItem]) {
            items.forEach(confirm)
        }

        private func confirm(_ item: RecognizedItem) {
            guard case let .barcode(barcode) = item, let value = barcode.payloadStringValue else { return }
            if value == pending { pendingCount += 1 } else { pending = value; pendingCount = 1 }
            guard pendingCount >= 2 else { return }
            pendingCount = 0
            onScan(barcode.observation.symbology == .qr ? .qr(value) : .barcode(value))
        }
    }
}

/// Device-level torch — independent of who owns the capture session.
enum Torch {
    static var isAvailable: Bool { AVCaptureDevice.default(for: .video)?.hasTorch ?? false }

    static func set(_ on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        try? device.lockForConfiguration()
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
    }
}
