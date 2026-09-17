//
//  HistoryView.swift
//  truelable
//
//  Everything this device has looked up, searchable, with a compare mode
//  for 2–4 products. Rows open instantly from the stored snapshot.
//
//  The filter used to hide inside a toolbar menu, which meant the only
//  indication the list was filtered was a slightly different icon. It is a
//  chip rail now: the state of the list is visible from the list itself.
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
    @Namespace private var hero
    private let plus = Plus.shared
    private var compareLimit: Int { plus.isActive ? 4 : Plus.freeCompareLimit }

    private enum Filter: String, CaseIterable, Identifiable {
        case all = "All", verified = "Verified", good = "Nutri-Score A–B", poor = "Nutri-Score D–E"
        var id: String { rawValue }

        var short: String {
            switch self {
            case .all: "All"
            case .verified: "Verified"
            case .good: "A–B"
            case .poor: "D–E"
            }
        }

        var icon: String {
            switch self {
            case .all: "square.grid.2x2"
            case .verified: "checkmark.seal.fill"
            case .good: "leaf.fill"
            case .poor: "exclamationmark.triangle.fill"
            }
        }
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
                    .zoomDestination(barcode, in: hero)
            }
            .toolbar {
                if !records.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(compareMode ? "Done" : "Compare") {
                            withAnimation(.tlSettle) {
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
            .sensoryFeedback(.selection, trigger: filter)
            .sensoryFeedback(.selection, trigger: selected)
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

    private var filterRail: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(Filter.allCases) { option in
                    let on = filter == option
                    Button {
                        withAnimation(.tlSnap) { filter = option }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: option.icon)
                                .font(.caption2.weight(.semibold))
                            Text(option.short)
                                .font(.footnote.weight(.semibold))
                        }
                        .foregroundStyle(on ? TL.ink : TL.fg2)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background {
                            if on {
                                Capsule().fill(TL.accentGradient)
                            } else {
                                Capsule().fill(TL.surface).overlay(Capsule().stroke(TL.line))
                            }
                        }
                    }
                    .buttonStyle(.pressable)
                }
            }
            .padding(.horizontal, TL.gutter)
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }

    private var list: some View {
        List {
            Section {
                EmptyView()
            } header: {
                filterRail
                    .listRowInsets(EdgeInsets())
                    .textCase(nil)
            }
            .listRowBackground(Color.clear)

            if visible.isEmpty {
                noMatches
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
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
                                        withAnimation(.tlSettle) { context.delete(record) }
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
                .zoomSource(record.barcode, in: hero)
        }
    }

    private func rowBody(_ record: ScanRecord) -> some View {
        let picked = selected.contains(record.barcode)
        return HStack(spacing: 14) {
            if compareMode {
                Image(systemName: picked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(picked ? TL.accent : TL.fg3)
                    .contentTransition(.symbolEffect(.replace))
            }
            ProductThumb(url: record.imageURL, size: 56, radius: 16)
            VStack(alignment: .leading, spacing: 4) {
                Text(record.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if !record.brand.isEmpty {
                        Text(record.brand).lineLimit(1)
                        Text("·")
                    }
                    Text(record.scannedAt.formatted(.relative(presentation: .named)))
                        .lineLimit(1)
                }
                .font(.caption)
                .foregroundStyle(TL.fg3)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 5) {
                GradeBadge(grade: record.nutriscoreGrade)
                if record.verified {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption2)
                        .foregroundStyle(TL.accent)
                        .accessibilityLabel("Verified by the community")
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        // Picking for compare should feel like picking something up.
        .scaleEffect(compareMode && picked ? 0.985 : 1)
        .animation(.tlSnap, value: picked)
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
                    .contentTransition(.numericText())
            }
            .buttonStyle(.primary)
            .disabled(selected.count < 2)
            .opacity(selected.count < 2 ? 0.6 : 1)
        }
        .padding(.horizontal, TL.gutter)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.regularMaterial)
        .animation(.tlSettle, value: selected.count)
    }

    /// Filtered down to nothing is a different situation from having scanned
    /// nothing, and it needs the filter back — not a shrug.
    private var noMatches: some View {
        VStack(spacing: 14) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.largeTitle)
                .foregroundStyle(TL.fg3)
            Text(query.isEmpty ? "Nothing matches this filter" : "No match for “\(query)”")
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
            if filter != .all {
                Button("Show all") { withAnimation(.tlSnap) { filter = .all } }
                    .buttonStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var empty: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle()
                    .fill(TL.surface)
                    .frame(width: 96, height: 96)
                    .overlay(Circle().stroke(TL.line))
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(TL.fg3)
            }

            VStack(spacing: 8) {
                Text("Nothing scanned yet")
                    .font(.displayM)
                Text("Products you look up land here — and open instantly, even offline.")
                    .font(.subheadline)
                    .foregroundStyle(TL.fg2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)

            Button("Scan your first product") { router.scannerPresented = true }
                .buttonStyle(.primary)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appear()
    }

    private func toggle(_ barcode: String) {
        withAnimation(.tlSnap) {
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
