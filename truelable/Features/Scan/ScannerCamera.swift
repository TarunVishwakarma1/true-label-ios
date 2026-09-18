import SwiftUI
import AVFoundation
import Vision
import VisionKit

enum ScanResult: Equatable {
    case barcode(String)
    case qr(String)
}

struct ScannerCamera<Overlay: View>: UIViewControllerRepresentable {

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

enum Torch {
    static var isAvailable: Bool { AVCaptureDevice.default(for: .video)?.hasTorch ?? false }

    static func set(_ on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        try? device.lockForConfiguration()
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
    }
}
