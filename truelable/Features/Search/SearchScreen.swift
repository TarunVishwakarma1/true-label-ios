//
//  SearchScreen.swift
//  truelable
//
//  Find a product without the pack in hand. Local catalogue first (fuzzy,
//  ranked), topped up from Open Food Facts by the backend. Digits go
//  straight to a barcode look-up.
//

import SwiftUI

/// Search owns its stack rather than borrowing Home's. A `.searchable`
/// list pushed into another screen's stack, under a hidden navigation bar,
/// is the fragile arrangement this used to be.
struct SearchSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            SearchScreen()
                .navigationDestination(for: String.self) { ProductLoaderScreen(barcode: $0) }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Close", systemImage: "xmark") { dismiss() }
                    }
                }
        }
        .presentationBackground(TL.bg)
        .presentationCornerRadius(TL.R.xl)
    }
}

struct SearchScreen: View {
    @State private var query = ""
    @State private var results: [ProductCard] = []
    @State private var trending: [ProductCard] = []
    @State private var searching = false
    @State private var failed = false
    @AppStorage("v2.search.recent") private var recentRaw = ""

    private var recents: [String] { recentRaw.split(separator: "\n").map(String.init).filter { !$0.isEmpty } }
    private var trimmed: String { query.trimmingCharacters(in: .whitespaces) }
    private var looksLikeBarcode: Bool { trimmed.count >= 8 && trimmed.allSatisfy(\.isNumber) }

    var body: some View {
        List {
            if trimmed.count < 2 {
                idle
            } else {
                resultsSection
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Product, brand or barcode")
        .searchPresentationToolbarBehavior(.avoidHidingContent)
        .task(id: trimmed) { await search() }
        .task { trending = (try? await API.trending(limit: 8)) ?? [] }
    }

    @ViewBuilder
    private var idle: some View {
        if !recents.isEmpty {
            Section {
                ForEach(recents, id: \.self) { term in
                    Button {
                        query = term
                    } label: {
                        Label(term, systemImage: "clock.arrow.circlepath")
                            .font(.subheadline)
                            .foregroundStyle(TL.fg)
                    }
                    .listRowBackground(Color.clear)
                }
                .onDelete { offsets in
                    var r = recents
                    r.remove(atOffsets: offsets)
                    recentRaw = r.joined(separator: "\n")
                }
            } header: {
                Eyebrow(text: "Recent searches")
            }
        }
        if !trending.isEmpty {
            Section {
                ForEach(trending) { card in
                    NavigationLink(value: card.barcode) { ProductCardRow(card: card) }
                        .listRowBackground(Color.clear)
                        .listRowSeparatorTint(TL.line)
                }
            } header: {
                Eyebrow(text: "Popular in \(API.country)")
            }
        }
    }

    @ViewBuilder
    private var resultsSection: some View {
        if looksLikeBarcode {
            NavigationLink(value: BarcodeChecksum.normalized(trimmed)) {
                Label("Look up barcode \(trimmed)", systemImage: "barcode.viewfinder")
                    .font(.subheadline.weight(.semibold))
            }
            .listRowBackground(Color.clear)
        }
        if searching && results.isEmpty {
            ForEach(0..<4, id: \.self) { _ in
                HStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: TL.R.md).fill(Color.white.opacity(0.08)).frame(width: 56, height: 56)
                    Skeleton(lines: 2)
                }
                .listRowBackground(Color.clear)
            }
        } else if failed {
            ContentUnavailableView("Couldn't search", systemImage: "wifi.slash", description: Text("Check your connection and try again."))
                .listRowBackground(Color.clear)
        } else if results.isEmpty && !searching {
            ContentUnavailableView.search(text: trimmed)
                .listRowBackground(Color.clear)
        } else {
            ForEach(results) { card in
                NavigationLink(value: card.barcode) {
                    ProductCardRow(card: card)
                }
                .listRowBackground(Color.clear)
                .listRowSeparatorTint(TL.line)
            }
        }
    }

    private func search() async {
        guard trimmed.count >= 2 else {
            results = []
            searching = false
            return
        }
        // Debounce: typing cancels the previous task before it fires.
        try? await Task.sleep(for: .milliseconds(320))
        guard !Task.isCancelled else { return }
        searching = true
        failed = false
        defer { searching = false }
        do {
            let found = try await API.search(trimmed)
            guard !Task.isCancelled else { return }
            withAnimation(.tl(0.3)) { results = found }
            if !found.isEmpty { remember(trimmed) }
        } catch {
            if !Task.isCancelled { failed = true }
        }
    }

    private func remember(_ term: String) {
        var r = recents.filter { $0.caseInsensitiveCompare(term) != .orderedSame }
        r.insert(term, at: 0)
        recentRaw = r.prefix(6).joined(separator: "\n")
    }
}
