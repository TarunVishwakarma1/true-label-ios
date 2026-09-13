//
//  CompareView.swift
//  truelable
//

import SwiftUI

/// Side-by-side comparison of 2–4 recently scanned products. Lowest value
/// in each row is highlighted — a bare number doesn't tell you which
/// product is actually the better pick, a highlighted one does.
struct CompareView: View {
    var entries: [ScanHistoryEntry]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView([.horizontal, .vertical]) {
                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 16) {
                    header
                    Divider().gridCellColumns(entries.count + 1).overlay(.white.opacity(0.15))

                    numericRow("Calories", unit: "kcal", lowerIsBetter: true) { $0.calories }
                    numericRow("Sugar", unit: "g", lowerIsBetter: true) { $0.sugarGrams }
                    numericRow("Sodium", unit: "mg", lowerIsBetter: true) { $0.sodiumMg }
                    textRow("Nutri-Score") { $0.nutriscoreGrade?.uppercased() }
                    textRow("NOVA group") { $0.novaGroup.map(String.init) }
                    boolRow("Vegetarian") { $0.isVegetarian }
                }
                .padding(20)
            }
            .background(TLColor.bg.ignoresSafeArea())
            .navigationTitle("Compare")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        GridRow {
            Text("")
                .frame(width: 110, alignment: .leading)
            ForEach(entries) { entry in
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    if !entry.brand.isEmpty {
                        Text(entry.brand)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.45))
                            .lineLimit(1)
                    }
                }
                .frame(width: 140, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func numericRow<T: Comparable & CustomStringConvertible>(
        _ label: String, unit: String, lowerIsBetter: Bool, value: @escaping (ScanHistoryEntry) -> T?
    ) -> some View {
        let values = entries.map(value)
        let best: T? = lowerIsBetter ? values.compactMap { $0 }.min() : values.compactMap { $0 }.max()

        GridRow {
            rowLabel(label)
            ForEach(entries) { entry in
                let v = value(entry)
                cell(v.map { "\($0) \(unit)" } ?? "—", highlighted: v != nil && v == best)
                    .frame(width: 140, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func textRow(_ label: String, value: @escaping (ScanHistoryEntry) -> String?) -> some View {
        GridRow {
            rowLabel(label)
            ForEach(entries) { entry in
                cell(value(entry) ?? "—")
                    .frame(width: 140, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func boolRow(_ label: String, value: @escaping (ScanHistoryEntry) -> Bool?) -> some View {
        GridRow {
            rowLabel(label)
            ForEach(entries) { entry in
                let v = value(entry)
                cell(v == nil ? "—" : (v == true ? "Yes" : "No"), highlighted: v == true)
                    .frame(width: 140, alignment: .leading)
            }
        }
    }

    private func rowLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(.white.opacity(0.5))
            .frame(width: 110, alignment: .leading)
    }

    private func cell(_ text: String, highlighted: Bool = false) -> some View {
        Text(text)
            .font(.system(.subheadline, design: .monospaced).weight(highlighted ? .bold : .regular))
            .foregroundStyle(highlighted ? TLColor.accent : .white.opacity(0.85))
    }
}

#Preview {
    CompareView(entries: [
        ScanHistoryEntry(product: ProductInfo(
            barcode: "1", name: "Mango Drink", brand: "Farmland", servingSize: "Per 100g",
            calories: 55, nutrients: [], ingredients: "",
            novaGroup: 4, nutriscoreGrade: "d", isVegetarian: true,
            sugarGrams: 13, sodiumMg: 6
        )),
        ScanHistoryEntry(product: ProductInfo(
            barcode: "2", name: "Nimbu Pani", brand: "Local", servingSize: "Per 100g",
            calories: 30, nutrients: [], ingredients: "",
            novaGroup: 1, nutriscoreGrade: "b", isVegetarian: true,
            sugarGrams: 4.5, sodiumMg: 2
        ))
    ])
}
