//
//  CompareView.swift
//  truelable
//
//  Side-by-side. The best value in each row is lit — a number alone
//  doesn't tell you which one to pick, a highlighted one does.
//

import SwiftUI

struct CompareView: View {
    let records: [ScanRecord]
    @Environment(\.dismiss) private var dismiss

    private let labelWidth: CGFloat = 96
    private let columnWidth: CGFloat = 124

    var body: some View {
        NavigationStack {
            ScrollView([.horizontal, .vertical]) {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 0) {
                    header
                    numeric("Calories", unit: "kcal") { $0.calories.map(Double.init) }
                    numeric("Sugar", unit: "g") { $0.sugarGrams }
                    numeric("Sodium", unit: "mg") { $0.sodiumMg }
                    numeric("Protein", unit: "g", lowerIsBetter: false) { $0.proteinGrams }
                    grade
                    nova
                }
                .padding(TL.gutter)
            }
            .scrollBounceBehavior(.basedOnSize)
            .screenBackground()
            .navigationTitle("Compare")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationBackground(TL.bg)
        .presentationCornerRadius(32)
    }

    private var header: some View {
        GridRow(alignment: .top) {
            Color.clear.frame(width: labelWidth, height: 1)
            ForEach(records) { r in
                VStack(alignment: .leading, spacing: 8) {
                    ProductThumb(url: r.imageURL, size: 56, radius: 16)
                    Text(r.name).font(.subheadline.weight(.semibold)).lineLimit(2)
                    if !r.brand.isEmpty {
                        Text(r.brand).font(.caption).foregroundStyle(TL.fg3).lineLimit(1)
                    }
                }
                .frame(width: columnWidth, alignment: .leading)
                .padding(.bottom, 16)
            }
        }
    }

    private func numeric(_ label: String, unit: String, lowerIsBetter: Bool = true, value: (ScanRecord) -> Double?) -> some View {
        let values = records.map(value)
        let present = values.compactMap { $0 }
        let best = lowerIsBetter ? present.min() : present.max()
        return GridRow {
            rowLabel(label)
            ForEach(Array(records.enumerated()), id: \.element.id) { i, _ in
                let v = values[i]
                cell(v.map { "\($0.compact) \(unit)" } ?? "—", highlighted: v != nil && v == best && present.count > 1)
            }
        }
    }

    private var grade: some View {
        GridRow {
            rowLabel("Nutri-Score")
            ForEach(records) { r in
                HStack {
                    if Nutriscore.letter(r.nutriscoreGrade) != nil {
                        GradeBadge(grade: r.nutriscoreGrade)
                    } else {
                        Text("—").foregroundStyle(TL.fg3)
                    }
                }
                .frame(width: columnWidth, alignment: .leading)
                .padding(.vertical, 12)
                .overlay(alignment: .top) { Hairline() }
            }
        }
    }

    private var nova: some View {
        GridRow {
            rowLabel("Processing")
            ForEach(records) { r in
                Text(r.novaGroup.map { "NOVA \($0)" } ?? "—")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(TL.nova(r.novaGroup))
                    .frame(width: columnWidth, alignment: .leading)
                    .padding(.vertical, 12)
                    .overlay(alignment: .top) { Hairline() }
            }
        }
    }

    private func rowLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(TL.fg3)
            .frame(width: labelWidth, alignment: .leading)
            .padding(.vertical, 12)
            .overlay(alignment: .top) { Hairline() }
    }

    private func cell(_ text: String, highlighted: Bool) -> some View {
        Text(text)
            .font(.subheadline.weight(highlighted ? .bold : .regular))
            .numeric()
            .foregroundStyle(highlighted ? TL.good : TL.fg)
            .frame(width: columnWidth, alignment: .leading)
            .padding(.vertical, 12)
            .overlay(alignment: .top) { Hairline() }
    }
}
