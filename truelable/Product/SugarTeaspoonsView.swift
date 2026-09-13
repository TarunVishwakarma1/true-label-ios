//
//  SugarTeaspoonsView.swift
//  truelable
//

import SwiftUI

/// Grams of sugar are hard to picture; teaspoons aren't. Matches the
/// website's "know" phase — same 4g/teaspoon public-health rounding, same
/// WHO free-sugar guideline (50g/day) as the reference.
///
/// Our real nutrition data is per-100g (Open Food Facts' `nutriments`), not
/// per-pack like the reference mock's 200ml example — no serving/pack-size
/// grams are ingested anywhere in this pipeline, so this is honestly
/// labeled "per 100g" rather than inventing a per-pack figure.
struct SugarTeaspoonsView: View {
    var sugarGrams: Double

    @ScaledMetric private var blockHeight: CGFloat = 24
    @State private var revealed = false

    private var teaspoons: Int { max(1, Int((sugarGrams / 4).rounded())) }
    private var percentOfDay: Int { Int(((sugarGrams / 50) * 100).rounded()) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Sugar, per 100g")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(TLColor.paperMuted)
                Spacer()
                Text(sugarGrams.formatted(.number.precision(.fractionLength(0...1))) + " g")
                    .font(.system(.caption, design: .monospaced).monospacedDigit())
                    .foregroundStyle(TLColor.paperInk)
            }

            HStack(spacing: 4) {
                ForEach(0..<min(teaspoons, 12), id: \.self) { index in
                    teaspoonBlock(index: index)
                }
            }
            .accessibilityElement()
            .accessibilityLabel("About \(teaspoons) teaspoons of sugar")

            Text("≈\(teaspoons) teaspoon\(teaspoons == 1 ? "" : "s") · \(percentOfDay)% of a 50 g day")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(TLColor.paperMuted)
        }
        .onAppear { revealed = true }
    }

    @ViewBuilder
    private func teaspoonBlock(index: Int) -> some View {
        let fill = TLColor.warn.opacity(0.2)
        let stroke = TLColor.warn.opacity(0.7)
        let scaleY: CGFloat = revealed ? 1 : 0
        let delay = 0.05 + Double(index) * 0.06

        RoundedRectangle(cornerRadius: 2)
            .fill(fill)
            .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(stroke, lineWidth: 1))
            .frame(height: blockHeight)
            .scaleEffect(y: scaleY, anchor: .bottom)
            .animation(.easeOutExpo(duration: 0.4).delay(delay), value: revealed)
    }
}

#Preview {
    ZStack {
        TLColor.paper.ignoresSafeArea()
        SugarTeaspoonsView(sugarGrams: 26)
            .padding(24)
    }
}
