//
//  VerifyPromptView.swift
//  truelable
//

import SwiftUI
import SwiftData

/// What actually shows in `ScannerView`'s in-place overlay once a barcode
/// resolves: a lightweight verify step first (matches the website's
/// "verify" phase), then the full nutrition screen — one continuous view
/// hierarchy (if/else, not separate presentations) so `namespace`'s
/// `matchedGeometryEffect` can interpolate all the way through: viewfinder
/// → verify card → the paper nutrition label.
struct ProductFoundFlow: View {
    let product: ProductInfo
    var namespace: Namespace.ID
    var onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var currentProduct: ProductInfo
    @State private var showingDetail = false

    init(product: ProductInfo, namespace: Namespace.ID, onDismiss: @escaping () -> Void) {
        self.product = product
        self.namespace = namespace
        self.onDismiss = onDismiss
        _currentProduct = State(initialValue: product)
    }

    var body: some View {
        Group {
            if showingDetail {
                ProductDetailView(product: currentProduct, namespace: namespace, onDismiss: onDismiss)
            } else {
                VerifyPromptView(product: product, namespace: namespace) { updated in
                    if let updated { currentProduct = updated }
                    withAnimation(.easeOutExpo(duration: 0.5)) { showingDetail = true }
                }
            }
        }
        // Recorded once, the moment a lookup actually resolves to a real
        // product — regardless of whether the user finishes verifying or
        // backs out early, this genuinely was a successful scan.
        .onAppear {
            modelContext.insert(ScanHistoryEntry(product: product))
        }
    }
}

/// "Does this match what's on the label?" — real crowdsourced verification,
/// not decoration: Matches calls the already-existing (previously unused by
/// iOS) `POST /api/v1/products/verify` and the returned count is what's
/// shown here and after. Opaque background per this app's established
/// no-live-glass-over-animation rule (see `ProductDetailView`'s doc
/// comment) — nothing here is animating behind it, so that lesson doesn't
/// block a card treatment here, but staying consistent costs nothing.
struct VerifyPromptView: View {
    let product: ProductInfo
    var namespace: Namespace.ID?
    /// Called once the user is done here: the refreshed product if
    /// "Matches" actually succeeded, otherwise the original — the flow
    /// continues into the detail screen either way.
    var onContinue: (ProductInfo?) -> Void

    @AppStorage("stats.verificationsSubmitted") private var verificationsSubmitted = 0
    @State private var submitting = false
    @State private var flash = false
    @State private var didSubmit = false

    var body: some View {
        ZStack {
            TLColor.bg.ignoresSafeArea()

            card
                .padding(24)
                .frame(maxHeight: .infinity, alignment: .bottom)

            // A brief flash when the community confirms the label —
            // matches the website's flash-on-verify.
            TLColor.accent
                .opacity(flash ? 0.5 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .preferredColorScheme(.dark)
        .sensoryFeedback(.impact(weight: .medium), trigger: didSubmit)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 20) {
            Capsule()
                .fill(.white.opacity(0.15))
                .frame(width: 40, height: 4)
                .frame(maxWidth: .infinity)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.white)
                    Text(product.servingSize)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                Text("\(product.verificationCount) verified")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(TLColor.accent)
            }

            Divider().overlay(.white.opacity(0.1))

            Text("Does the label match what's on file?")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))

            HStack(spacing: 10) {
                Button {
                    Task { await submitMatches() }
                } label: {
                    HStack(spacing: 8) {
                        if submitting {
                            ProgressView().tint(TLColor.ink)
                        }
                        Text("Matches")
                            .font(.subheadline.weight(.medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(TLColor.ink)
                    .background(TLColor.accent, in: RoundedRectangle(cornerRadius: 14))
                }
                .disabled(submitting)

                Button {
                    didSubmit.toggle()
                    onContinue(nil)
                } label: {
                    Text("Doesn't")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(.white.opacity(0.7))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.15)))
                }
                .disabled(submitting)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .padding(20)
        .background(TLColor.surface, in: RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(.white.opacity(0.08)))
        .modifier(OptionalMatchedGeometryCard(namespace: namespace))
    }

    private func submitMatches() async {
        submitting = true
        withAnimation(.easeOut(duration: 0.12)) { flash = true }

        let updated = try? await ProductAPIClient.submitVerification(barcode: product.barcode)
        if updated != nil {
            verificationsSubmitted += 1
        }

        withAnimation(.easeOut(duration: 0.7)) { flash = false }
        submitting = false
        didSubmit.toggle()
        onContinue(updated)
    }
}

/// Same "skip matched geometry if no namespace was passed" helper as
/// `NutritionLabelView` — kept file-local rather than shared, since each
/// call site's `id` differs.
private struct OptionalMatchedGeometryCard: ViewModifier {
    var namespace: Namespace.ID?

    func body(content: Content) -> some View {
        if let namespace {
            content.matchedGeometryEffect(id: "scannedLabel", in: namespace)
        } else {
            content
        }
    }
}

#Preview {
    VerifyPromptView(
        product: ProductInfo(
            barcode: "8901030895564",
            name: "Mango Fruit Drink",
            brand: "Farmland",
            servingSize: "Per 100g",
            calories: 55,
            nutrients: [],
            ingredients: "",
            verified: false,
            verificationCount: 22
        ),
        onContinue: { _ in }
    )
}
