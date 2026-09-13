//
//  MacroBreakdownCard.swift
//  truelable
//

import SwiftUI

/// Calories ring + fat/carbs/protein bars, all real per-100g values
/// already on `ProductInfo` — hidden if none of the three macros exist,
/// rather than drawing three empty bars.
struct MacroBreakdownCard: View {
    var product: ProductInfo

    private var maxMacro: Double {
        max(product.fatGrams ?? 0, product.carbsGrams ?? 0, product.proteinGrams ?? 0, 1)
    }

    var body: some View {
        if product.fatGrams != nil || product.carbsGrams != nil || product.proteinGrams != nil {
            HStack(spacing: 18) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.09), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: min(CGFloat(product.calories) / 800, 1))
                        .stroke(TLColor.accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 2) {
                        Text("\(product.calories)").font(.system(size: 20, weight: .bold))
                        Text("kcal/100g").font(.system(size: 8.5, weight: .medium)).foregroundStyle(.white.opacity(0.4))
                    }
                }
                .frame(width: 76, height: 76)

                VStack(spacing: 10) {
                    if let fat = product.fatGrams {
                        bar("Fat", fat, color: TLColor.warn)
                    }
                    if let carbs = product.carbsGrams {
                        bar("Carbs", carbs, color: TLColor.accent)
                    }
                    if let protein = product.proteinGrams {
                        bar("Protein", protein, color: TLColor.proteinBlue)
                    }
                }
            }
            .padding(20)
            .liquidGlassCard(cornerRadius: 26)
        }
    }

    private func bar(_ label: String, _ grams: Double, color: Color) -> some View {
        VStack(spacing: 5) {
            HStack {
                Text(label).font(.system(size: 12.5, weight: .medium)).foregroundStyle(.white.opacity(0.62))
                Spacer()
                Text(grams.formatted(.number.precision(.fractionLength(0...1))) + " g")
                    .font(.system(size: 12.5, weight: .medium, design: .monospaced))
            }
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.08))
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(color)
                            .frame(width: geo.size.width * min(grams / maxMacro, 1))
                    }
            }
            .frame(height: 5)
        }
    }
}

#Preview {
    ZStack {
        TLColor.bg.ignoresSafeArea()
        MacroBreakdownCard(product: ProductInfo(
            barcode: "1", name: "Aloo Bhujia", brand: "Haldiram's", servingSize: "Per 100g",
            calories: 546, nutrients: [], ingredients: "",
            fatGrams: 36.4, carbsGrams: 43.8, proteinGrams: 9.2
        ))
        .padding(24)
    }
}
