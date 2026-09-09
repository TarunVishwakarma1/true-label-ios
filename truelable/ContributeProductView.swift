//
//  ContributeProductView.swift
//  truelable
//

import SwiftUI
import UIKit

/// The 4-step "help us add this product" wizard: capture a photo of the
/// ingredient label, send it off, review what came back, submit. One
/// internal state machine with custom chrome, same pattern as ScannerView,
/// rather than a NavigationStack — this app doesn't use system nav bars
/// anywhere.
struct ContributeProductView: View {
    var barcode: String
    var onFinished: () -> Void

    private enum Step: Equatable {
        case capture
        case processing
        case review(ExtractedProductData)
        case success
    }

    @State private var step: Step = .capture
    @State private var isCameraPresented = false

    private let cameraAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)

    var body: some View {
        ZStack {
            // Paused while the camera cover is up, same reasoning as
            // ProductNotFoundView — a covered screen keeps rendering
            // otherwise.
            DotGridBackground(isPaused: isCameraPresented)

            VStack {
                topBar
                Spacer()
                content
                Spacer()
            }
            .padding(.horizontal, 32)
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $isCameraPresented) {
            CameraCaptureRepresentable(
                onCapture: { image in
                    isCameraPresented = false
                    startProcessing(image)
                },
                onCancel: { isCameraPresented = false }
            )
            .ignoresSafeArea()
        }
    }

    private var topBar: some View {
        HStack {
            Spacer()
            Button {
                print("[ContributeProductView] close button tapped")
                onFinished()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .padding(12)
                    .glassEffect(.regular, in: Circle())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .capture:
            captureStep
        case .processing:
            processingStep
        case .review(let data):
            reviewStep(data)
        case .success:
            successStep
        }
    }

    private var captureStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 44))
                .foregroundStyle(.white.opacity(0.7))

            Text("Take a photo of the ingredient list")
                .font(.title3.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("Make sure the text is flat, well-lit, and in focus.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)

            if cameraAvailable {
                Button {
                    isCameraPresented = true
                } label: {
                    Text("Open Camera")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .glassEffect(.regular.tint(.accentColor), in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.top, 12)
            } else {
                Text("Camera isn't available here")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, 12)
            }
        }
    }

    private var processingStep: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.4)
            Text("Analyzing ingredient list…")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private func reviewStep(_ data: ExtractedProductData) -> some View {
        VStack(spacing: 20) {
            Text("Does this look correct?")
                .font(.title3.bold())
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 16) {
                labeledField(title: "Product Name", value: data.guessedName)
                labeledField(title: "Ingredients", value: data.ingredients)
                labeledField(title: "Allergens", value: data.allergens.isEmpty ? "None detected" : data.allergens.joined(separator: ", "))
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))

            Button {
                submit(data)
            } label: {
                Text("Yes, Submit")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .glassEffect(.regular.tint(.accentColor), in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())

            Button("Retake Photo") {
                step = .capture
            }
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.6))
        }
    }

    private func labeledField(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.bold())
                .foregroundStyle(.white.opacity(0.45))
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.white)
        }
    }

    private var successStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.green)

            Text("Thanks for the help!")
                .font(.title3.bold())
                .foregroundStyle(.white)

            Text("We'll review this and add it to the catalogue soon.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)

            Button {
                print("[ContributeProductView] done button tapped")
                onFinished()
            } label: {
                Text("Done")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .glassEffect(.regular.tint(.accentColor), in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.top, 12)
        }
    }

    private func startProcessing(_ image: UIImage) {
        step = .processing
        Task {
            let data = (try? await IngredientAPIClient.extractIngredients(image: image))
                ?? ExtractedProductData(guessedName: "Unknown", ingredients: "", allergens: [])
            withAnimation { step = .review(data) }
        }
    }

    private func submit(_ data: ExtractedProductData) {
        step = .processing
        Task {
            _ = try? await IngredientAPIClient.submitContribution(barcode: barcode, data: data)
            withAnimation { step = .success }
        }
    }
}

#Preview {
    ContributeProductView(barcode: "1234567890123", onFinished: {})
}
