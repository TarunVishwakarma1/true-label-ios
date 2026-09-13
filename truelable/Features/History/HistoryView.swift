//
//  HistoryView.swift
//  truelable
//
//  Everything this device has looked up, searchable, with a compare mode
//  for 2–4 products. Rows open instantly from the stored snapshot.
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \ScanRecord.scannedAt, order: .reverse) private var records: [ScanRecord]
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router

    @State private var query = ""
    @State private var filter: Filter = .all
    @State private var compareMode = false
    @State private var selected: Set<String> = []
    @State private var comparing: [ScanRecord] = []
    private let plus = Plus.shared
    private var compareLimit: Int { plus.isActive ? 4 : Plus.freeCompareLimit }

    private enum Filter: String, CaseIterable, Identifiable {
        case all = "All", verified = "Verified", good = "Nutri-Score A–B", poor = "Nutri-Score D–E"
        var id: String { rawValue }
    }

    private var visible: [ScanRecord] {
        records.filter { r in
            switch filter {
            case .all: true
            case .verified: r.verified
            case .good: ["a", "b"].contains(r.nutriscoreGrade ?? "")
            case .poor: ["d", "e"].contains(r.nutriscoreGrade ?? "")
            }
        }
        .filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || $0.brand.localizedCaseInsensitiveContains(query) || $0.barcode.contains(query) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    empty
                } else {
                    list
                }
            }
            .screenBackground()
            .navigationTitle("History")
            .navigationDestination(for: String.self) { barcode in
                ProductLoaderScreen(barcode: barcode, initial: records.first { $0.barcode == barcode }?.product)
            }
            .toolbar {
                if !records.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Menu {
                            Picker("Filter", selection: $filter) {
                                ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                            }
                        } label: {
                            Image(systemName: filter == .all ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(compareMode ? "Done" : "Compare") {
                            withAnimation(.tl(0.3)) {
                                compareMode.toggle()
                                if !compareMode { selected.removeAll() }
                            }
                        }
                        .disabled(records.count < 2)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if compareMode {
                    compareBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .sheet(isPresented: Binding(get: { !comparing.isEmpty }, set: { if !$0 { comparing = [] } })) {
                CompareView(records: comparing)
            }
        }
    }

    /// "Today / Yesterday / This week / Earlier" buckets.
    private var grouped: [(title: String, records: [ScanRecord])] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let weekAgo = cal.date(byAdding: .day, value: -7, to: today)!
        var buckets: [(String, [ScanRecord])] = [("Today", []), ("Yesterday", []), ("This week", []), ("Earlier", [])]
        for r in visible {
            let i = r.scannedAt >= today ? 0 : r.scannedAt >= yesterday ? 1 : r.scannedAt >= weekAgo ? 2 : 3
            buckets[i].1.append(r)
        }
        return buckets.filter { !$0.1.isEmpty }
    }

    private var list: some View {
        List {
            if visible.isEmpty {
                ContentUnavailableView.search(text: query)
                    .listRowBackground(Color.clear)
            }
            ForEach(grouped, id: \.title) { group in
                Section {
                    ForEach(group.records) { record in
                        row(record)
                            .listRowBackground(Color.clear)
                            .listRowSeparatorTint(TL.line)
                            .swipeActions(edge: .trailing) {
                                if !compareMode {
                                    Button(role: .destructive) {
                                        context.delete(record)
                                    } label: { Label("Delete", systemImage: "trash") }
                                }
                            }
                    }
                } header: {
                    Eyebrow(text: group.title)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .searchable(text: $query, prompt: "Product, brand or barcode")
    }

    @ViewBuilder
    private func row(_ record: ScanRecord) -> some View {
        if compareMode {
            Button { toggle(record.barcode) } label: { rowBody(record) }
                .buttonStyle(.plain)
        } else {
            NavigationLink(value: record.barcode) { rowBody(record) }
        }
    }

    private func rowBody(_ record: ScanRecord) -> some View {
        HStack(spacing: 16) {
            if compareMode {
                Image(systemName: selected.contains(record.barcode) ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected.contains(record.barcode) ? TL.accent : TL.fg3)
            }
            ProductThumb(url: record.imageURL, size: 56, radius: 16)
            VStack(alignment: .leading, spacing: 4) {
                Text(record.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                HStack(spacing: 8) {
                    if !record.brand.isEmpty {
                        Text(record.brand).lineLimit(1)
                    }
                    Text("·")
                    Text(record.scannedAt.formatted(.relative(presentation: .named)))
                }
                .font(.caption)
                .foregroundStyle(TL.fg3)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                GradeBadge(grade: record.nutriscoreGrade)
                if record.verified {
                    Image(systemName: "checkmark.seal.fill").font(.caption).foregroundStyle(TL.accent)
                }
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private var compareBar: some View {
        VStack(spacing: 12) {
            if !plus.isActive && selected.count >= compareLimit {
                PlusGate(text: "Compare up to four with Plus")
            }
            Button {
                comparing = records.filter { selected.contains($0.barcode) }
            } label: {
                Text(selected.count < 2 ? "Pick 2–\(compareLimit) products" : "Compare \(selected.count) products")
            }
            .buttonStyle(.primary)
            .disabled(selected.count < 2)
            .opacity(selected.count < 2 ? 0.6 : 1)
        }
        .padding(.horizontal, TL.gutter)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .animation(.tl(0.3), value: selected.count)
    }

    private var empty: some View {
        VStack(spacing: 20) {
            ContentUnavailableView(
                "Nothing scanned yet",
                systemImage: "clock",
                description: Text("Products you look up will show here — and open instantly, even offline.")
            )
            Button("Scan your first product") { router.scannerPresented = true }
                .buttonStyle(.primary)
                .padding(.horizontal, 40)
        }
    }

    private func toggle(_ barcode: String) {
        withAnimation(.tl(0.25)) {
            if selected.contains(barcode) { selected.remove(barcode) } else if selected.count < compareLimit { selected.insert(barcode) }
        }
    }
}

#Preview {
    HistoryView()
        .environment(AppRouter())
        .modelContainer(for: ScanRecord.self, inMemory: true)
        .preferredColorScheme(.dark)
}
