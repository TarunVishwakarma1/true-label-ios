import SwiftUI
import SwiftData

struct ProductLoaderScreen: View {
    let barcode: String
    var initial: Product? = nil
    var inSheet: Bool = false

    var addsHistory: Bool = false

    @Environment(\.modelContext) private var context

    private enum LoadState { case loading, loaded(Product), notFound, failed(String) }
    @State private var state: LoadState = .loading
    @State private var attempt = 0

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProductSkeleton()
            case .loaded(let product):
                ProductScreen(product: product, inSheet: inSheet)
            case .notFound:
                NotFoundScreen(barcode: barcode, inSheet: inSheet) { reload() }
            case .failed(let message):
                failed(message)
            }
        }
        .screenBackground()
        .task(id: attempt) { await load() }
    }

    private func reload() {
        state = .loading
        attempt += 1
    }

    private func load() async {
        if let initial, case .loading = state {
            state = .loaded(initial)
        }
        do {
            let product = try await API.product(barcode: barcode)
            withAnimation(.tl(0.4)) { state = .loaded(product) }
            ScanRecord.record(product, in: context, bump: addsHistory, createIfMissing: addsHistory)

            if addsHistory { ScanActivity.show(product) }
        } catch APIError.notFound {
            if initial == nil { withAnimation(.tl(0.4)) { state = .notFound } }
        } catch {
            if initial == nil { withAnimation(.tl(0.4)) { state = .failed(error.localizedDescription) } }
        }
    }

    private func failed(_ message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "wifi.slash")
                .font(.largeTitle)
                .foregroundStyle(TL.fg3)
            Text("Couldn't load this product")
                .font(.title3.weight(.semibold))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(TL.fg2)
                .multilineTextAlignment(.center)
            Spacer()
            Button("Try again") { reload() }
                .buttonStyle(.primary)
        }
        .padding(28)
        .toolbar { if inSheet { CloseButton() } }
    }
}

struct CloseButton: ToolbarContent {
    @Environment(\.dismiss) private var dismiss
    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("Close", systemImage: "xmark") { dismiss() }
        }
    }
}

struct ProductSkeleton: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    RoundedRectangle(cornerRadius: TL.R.lg, style: .continuous)
                        .fill(TL.track)
                        .frame(width: 104, height: 104)
                    VStack(alignment: .leading, spacing: 8) {
                        Skeleton(lines: 2, height: 18)
                        Skeleton(lines: 1, height: 10)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 8)

                HStack(spacing: 20) {
                    Circle().fill(TL.track).frame(width: 88, height: 88)
                    Skeleton(lines: 2, height: 14)
                }
                .card(.hero)

                Skeleton(lines: 3).card()
                Skeleton(lines: 5).card()
            }
            .padding(TL.gutter)
        }
        .scrollDisabled(true)
    }
}
