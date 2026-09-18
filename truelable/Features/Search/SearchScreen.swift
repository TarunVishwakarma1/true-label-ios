import SwiftUI

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
        .presentationCornerRadius(TL.R.sheet)
    }
}

struct SearchScreen: View {
    @State private var query = ""
    @State private var results: [ProductCard] = []
    @State private var trending: [ProductCard] = []
    @State private var searching = false
    @State private var failed = false
    @AppStorage("v2.search.recent") private var recentRaw = ""

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
                                .plate(TL.surface, lifted: true)
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

            ForEach(0..<6, id: \.self) { i in
                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: TL.R.sm, style: .continuous)
                        .fill(TL.track)
                        .frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 7) {
                        Capsule().fill(TL.track)
                            .frame(width: [172.0, 138.0, 196.0][i % 3], height: 12)
                        Capsule().fill(TL.track).frame(width: 88, height: 10)
                    }
                    Spacer(minLength: 8)
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(TL.track)
                        .frame(width: 26, height: 26)
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
