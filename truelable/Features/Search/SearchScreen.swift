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
    /// Declared here rather than in `SearchSheet` so the zoom transition's
    /// source and destination live in the same view — the destination moved
    /// down here with it.
    @Namespace private var hero

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
        .navigationDestination(for: String.self) { barcode in
            ProductLoaderScreen(barcode: barcode)
                .zoomDestination(barcode, in: hero)
        }
        .task(id: trimmed) { await search() }
        .task { trending = (try? await API.trending(limit: 8)) ?? [] }
        .sensoryFeedback(.success, trigger: results.count)
    }

    @ViewBuilder
    private var idle: some View {
        if !recents.isEmpty {
            Section {
                // A rail rather than a stack of rows: six past searches used
                // to cost six full-width rows before the reader reached
                // anything they hadn't already seen.
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(recents, id: \.self) { term in
                            Button {
                                query = term
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.caption2)
                                    Text(term)
                                        .font(.footnote.weight(.medium))
                                        .lineLimit(1)
                                }
                                .foregroundStyle(TL.fg2)
                                .padding(.horizontal, 12)
                                .frame(height: 34)
                                .background {
                                    Capsule().fill(TL.surface).overlay(Capsule().stroke(TL.line))
                                }
                            }
                            .buttonStyle(.pressable)
                        }

                        Button {
                            withAnimation(.tlSnap) { recentRaw = "" }
                        } label: {
                            Text("Clear")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(TL.fg3)
                                .padding(.horizontal, 12)
                                .frame(height: 34)
                        }
                        .buttonStyle(.pressable)
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: TL.gutter, bottom: 8, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } header: {
                Eyebrow(text: "Recent searches")
            }
        }

        if !trending.isEmpty {
            Section {
                ForEach(trending) { card in
                    NavigationLink(value: card.barcode) { ProductCardRow(card: card) }
                        .zoomSource(card.barcode, in: hero)
                        .listRowBackground(Color.clear)
                        .listRowSeparatorTint(TL.line)
                }
            } header: {
                Eyebrow(text: "Popular in \(API.country)")
            }
        } else if recents.isEmpty {
            // First run, nothing typed, nothing fetched yet — say what this
            // box is for instead of showing a blank screen.
            VStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.largeTitle)
                    .foregroundStyle(TL.fg3)
                Text("Search the catalogue")
                    .font(.subheadline.weight(.semibold))
                Text("By product, brand, or a barcode typed in full.")
                    .font(.footnote)
                    .foregroundStyle(TL.fg3)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 56)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    @ViewBuilder
    private var resultsSection: some View {
        if looksLikeBarcode {
            NavigationLink(value: BarcodeChecksum.normalized(trimmed)) {
                HStack(spacing: 12) {
                    Image(systemName: "barcode.viewfinder")
                        .font(.title3)
                        .foregroundStyle(TL.accent)
                        .frame(width: 44, height: 44)
                        .background(TL.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: TL.R.sm, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Look up this barcode")
                            .font(.subheadline.weight(.semibold))
                        Text(trimmed)
                            .font(.caption)
                            .numeric()
                            .foregroundStyle(TL.fg3)
                    }
                }
                .padding(.vertical, 4)
            }
            .zoomSource(BarcodeChecksum.normalized(trimmed), in: hero)
            .listRowBackground(Color.clear)
            .listRowSeparatorTint(TL.line)
        }

        if searching && results.isEmpty {
            ForEach(0..<4, id: \.self) { _ in
                HStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: TL.R.md, style: .continuous)
                        .fill(TL.line)
                        .frame(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: 7) {
                        Capsule().fill(TL.line).frame(width: 160, height: 11)
                        Capsule().fill(TL.line).frame(width: 96, height: 9)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 4)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .loadingPulse()
        } else if failed {
            state(icon: "wifi.slash",
                  title: "Couldn't search",
                  detail: "Check your connection and try again.")
        } else if results.isEmpty && !searching {
            state(icon: "magnifyingglass",
                  title: "No match for “\(trimmed)”",
                  detail: "Try a shorter term, or scan the pack instead.")
        } else {
            ForEach(results) { card in
                NavigationLink(value: card.barcode) {
                    ProductCardRow(card: card)
                }
                .zoomSource(card.barcode, in: hero)
                .listRowBackground(Color.clear)
                .listRowSeparatorTint(TL.line)
            }
        }
    }

    private func state(icon: String, title: String, detail: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(TL.fg3)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(TL.fg3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
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
            withAnimation(.tlSettle) { results = found }
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
