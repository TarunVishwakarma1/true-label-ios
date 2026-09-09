//
//  BarcodeScannerRepresentable.swift
//  truelable
//

import SwiftUI
import Vision
import VisionKit

enum ScanResult: Equatable {
    case barcode(String)
    case qr(String)
}

/// Wraps VisionKit's `DataScannerViewController` — the current system
/// scanner API (live camera feed, on-device recognition, no AVFoundation
/// plumbing to hand-roll). Reports every newly recognized item once via
/// `onScan`; duplicate reads of the same still-visible code are ignored by
/// the caller instead of here, since "already showing this result" is a
/// screen-level concern, not a camera-level one.
///
/// The chrome (`overlay`) is hosted as a real child `UIViewController`
/// added directly onto the scanner's own view, not as a plain SwiftUI
/// ZStack sibling — `DataScannerViewController` has its own gesture
/// recognizers for tap-to-focus/item-selection, and those can win against
/// SwiftUI-composited siblings regardless of declared z-order. A genuine
/// UIKit subview added last is guaranteed to be hit-tested first.
struct BarcodeScannerRepresentable<Overlay: View>: UIViewControllerRepresentable {
    var onScan: (ScanResult) -> Void
    /// The camera + on-device Vision recognition are genuinely CPU/GPU
    /// heavy, running continuously while active. Pausing them (e.g. while
    /// the user is typing into a manual-entry field instead) frees up the
    /// main thread — otherwise things like the keyboard's own presentation
    /// animation visibly stall competing with it.
    var isScanningActive: Bool = true
    @ViewBuilder var overlay: () -> Overlay

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [
                // Trimmed to the symbologies actually printed on retail
                // food packaging (EAN-13/8, UPC-E) plus QR — every extra
                // symbology Vision checks for is real per-frame cost.
                .barcode(symbologies: [.ean13, .ean8, .upce, .qr])
            ],
            qualityLevel: .balanced, // accuracy matters more than raw scan speed for a product lookup
            recognizesMultipleItems: false,
            // We react the instant one item is found and move to a result
            // screen — we never need the extra power draw of smoothly
            // tracking an already-highlighted item over time.
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: false,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        try? controller.startScanning()

        let hosting = UIHostingController(rootView: overlay())
        hosting.view.backgroundColor = .clear
        controller.addChild(hosting)
        controller.view.addSubview(hosting.view)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: controller.view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: controller.view.bottomAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: controller.view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: controller.view.trailingAnchor)
        ])
        hosting.didMove(toParent: controller)
        context.coordinator.hostingController = hosting

        return controller
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        context.coordinator.hostingController?.rootView = overlay()

        guard context.coordinator.isScanningActive != isScanningActive else { return }
        context.coordinator.isScanningActive = isScanningActive
        if isScanningActive {
            try? uiViewController.startScanning()
        } else {
            uiViewController.stopScanning()
        }
    }

    static func dismantleUIViewController(_ uiViewController: DataScannerViewController, coordinator: Coordinator) {
        uiViewController.stopScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (ScanResult) -> Void
        var hostingController: UIHostingController<Overlay>?
        var isScanningActive = true

        // A checksum only catches ~90% of misreads — a single garbage frame
        // can coincidentally pass. Requiring the same payload twice in a
        // row filters that out: a real barcode held in view decodes
        // identically frame after frame, a misread essentially never
        // repeats itself exactly.
        private var pendingValue: String?
        private var pendingCount = 0

        init(onScan: @escaping (ScanResult) -> Void) {
            self.onScan = onScan
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            addedItems.forEach(confirm)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            updatedItems.forEach(confirm)
        }

        private func confirm(_ item: RecognizedItem) {
            guard case let .barcode(barcode) = item, let value = barcode.payloadStringValue else { return }

            if value == pendingValue {
                pendingCount += 1
            } else {
                pendingValue = value
                pendingCount = 1
            }
            guard pendingCount >= 2 else { return }

            if barcode.observation.symbology == .qr {
                onScan(.qr(value))
            } else {
                onScan(.barcode(value))
            }
        }
    }
}
