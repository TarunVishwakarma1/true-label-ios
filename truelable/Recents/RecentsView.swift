//
//  RecentsView.swift
//  truelable
//

import SwiftUI
import SwiftData

/// Every product this device has scanned, newest first, with a Compare
/// mode for picking 2–4 to send to `CompareView`.
///
/// `ScanHistoryEntry` only snapshots a handful of fields (see its own doc
/// comment) — not the full ingredients/additives/nutrient list — so
/// reopening the full `ProductDetailView` from here re-fetches fresh via
/// the existing `ProductAPIClient` rather than presenting an incomplete
/// screen from a partial snapshot. The backend already caches product
/// lookups, so this is cheap.
struct RecentsView: View {
    @Query(sort: \ScanHistoryEntry.scannedAt, order: .reverse) private var entries: [ScanHistoryEntry]
    @Environment(\.modelContext) private var modelContext

    @State private var compareMode = false
    @State private var selected: Set<String> = [] // barcodes
    @State private var loadingBarcode: String?
    @State private var openedProduct: ProductInfo?
    @State private var comparing: [ScanHistoryEntry] = []
    @State private var tab: RecentsTab = .recent

    private enum RecentsTab: String, CaseIterable {
        case recent = "Recent", insights = "Insights"
    }

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    emptyState
                } else if tab == .insights {
                    InsightsView(entries: entries)
                } else {
                    list
                }
            }
            .navigationTitle("History")
            .toolbar {
                if !entries.isEmpty {
                    ToolbarItem(placement: .principal) {
                        Picker("", selection: $tab) {
                            ForEach(RecentsTab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 180)
                    }
                    if tab == .recent {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(compareMode ? "Cancel" : "Compare") {
                                withAnimation(.easeOutExpo()) {
                                    compareMode.toggle()
                                    if !compareMode { selected.removeAll() }
                                }
                            }
                            .disabled(entries.count < 2)
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if compareMode && selected.count >= 2 {
                    compareBar
                }
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(item: $openedProduct) { product in
            ProductDetailView(product: product, onDismiss: { openedProduct = nil })
        }
        .sheet(isPresented: Binding(get: { !comparing.isEmpty }, set: { if !$0 { comparing = [] } })) {
            CompareView(entries: comparing)
        }
    }

    private var list: some View {
        List {
            ForEach(entries) { entry in
                row(entry)
                    .swipeActions {
                        if !compareMode {
                            Button(role: .destructive) {
                                modelContext.delete(entry)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(TLColor.bg)
    }

    private func row(_ entry: ScanHistoryEntry) -> some View {
        Button {
            if compareMode {
                toggleSelection(entry.barcode)
            } else {
                open(entry)
            }
        } label: {
            HStack(spacing: 14) {
                if compareMode {
                    Image(systemName: selected.contains(entry.barcode) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected.contains(entry.barcode) ? TLColor.accent : .white.opacity(0.3))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(entry.brand.isEmpty ? entry.barcode : entry.brand)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(1)
                }

                Spacer()

                if loadingBarcode == entry.barcode {
                    ProgressView().tint(.white)
                } else {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("\(entry.calories) kcal")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.7))
                        Text(entry.scannedAt.formatted(.relative(presentation: .named)))
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                }
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .listRowBackground(TLColor.bg)
    }

    private var compareBar: some View {
        Button {
            comparing = entries.filter { selected.contains($0.barcode) }
        } label: {
            Text("Compare \(selected.count) products")
                .font(.headline)
                .foregroundStyle(TLColor.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(TLColor.accent, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(ScaleButtonStyle())
        .padding()
        .background(.ultraThinMaterial)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.3))
            Text("NO SCANS YET")
                .font(.system(.caption, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.4))
            Text("Products you scan will show up here.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TLColor.bg.ignoresSafeArea())
    }

    private func toggleSelection(_ barcode: String) {
        if selected.contains(barcode) {
            selected.remove(barcode)
        } else if selected.count < 4 {
            selected.insert(barcode)
        }
    }

    private func open(_ entry: ScanHistoryEntry) {
        loadingBarcode = entry.barcode
        Task {
            let fresh = try? await ProductAPIClient.lookupProduct(barcode: entry.barcode)
            loadingBarcode = nil
            openedProduct = fresh
        }
    }
}

#Preview {
    RecentsView()
        .modelContainer(for: ScanHistoryEntry.self, inMemory: true)
}
