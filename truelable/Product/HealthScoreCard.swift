//
//  HealthScoreCard.swift
//  truelable
//

import SwiftUI

/// `product.estimatedHealthScore` is a derived heuristic (Nutri-Score +
/// NOVA), not an official industry number — this card says so explicitly
/// rather than presenting it as authoritative. Hidden entirely when the
/// underlying data doesn't exist, never backfilled with a guess.
struct HealthScoreCard: View {
    var product: ProductInfo
    var primaryWatch: WatchedNutrient?

    var body: some View {
        if let score = product.estimatedHealthScore, let verdict = product.healthVerdict {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 18) {
                    scoreRing(score, color: verdict.color.uiColor)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(verdict.headline)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(verdict.color.uiColor)
                        Text(verdictBody)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                FlowLayout(spacing: 7) {
                    ForEach(flags, id: \.label) { flag in
                        flagChip(flag)
                    }
                }

                Text("Estimated from Nutri-Score and NOVA processing group — not an official score.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(20)
            .liquidGlassCard(cornerRadius: 26)
        }
    }

    private var verdictBody: String {
        var parts: [String] = []
        if let grade = product.nutriscoreGrade {
            parts.append("Nutri-Score \(grade.uppercased())")
        }
        if let nova = product.novaGroup {
            parts.append("NOVA \(nova)/4 processed")
        }
        return parts.isEmpty ? "Limited nutrition data available." : parts.joined(separator: " · ")
    }

    private func scoreRing(_ score: Int, color: Color) -> some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.09), lineWidth: 9)
            Circle()
                .trim(from: 0, to: CGFloat(score) / 100)
                .stroke(color, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text("\(score)").font(.system(size: 24, weight: .bold))
                Text("/ 100").font(.system(size: 9, weight: .medium)).foregroundStyle(.white.opacity(0.4))
            }
        }
        .frame(width: 84, height: 84)
    }

    private struct Flag {
        var label: String
        var color: Color
    }

    /// Every flag here traces to a real field — nothing invented to fill
    /// the row out.
    private var flags: [Flag] {
        var result: [Flag] = []
        if let sugar = product.sugarGrams {
            if WatchedNutrient.sugar.isHigh(sugar) { result.append(Flag(label: "Sugar high", color: TLColor.danger)) }
            else if WatchedNutrient.sugar.isLow(sugar) { result.append(Flag(label: "Low sugar", color: TLColor.accent)) }
        }
        if let sodium = product.sodiumMg {
            if WatchedNutrient.sodium.isHigh(sodium) { result.append(Flag(label: "Sodium high", color: TLColor.danger)) }
            else if WatchedNutrient.sodium.isLow(sodium) { result.append(Flag(label: "Low sodium", color: TLColor.accent)) }
        }
        if product.isPalmOilFree == true { result.append(Flag(label: "No palm oil", color: TLColor.accent)) }
        else if product.isPalmOilFree == false { result.append(Flag(label: "Contains palm oil", color: TLColor.warn)) }
        if product.isVegan == true { result.append(Flag(label: "Vegan", color: TLColor.accent)) }
        else if product.isVegetarian == true { result.append(Flag(label: "Vegetarian", color: TLColor.accent)) }
        return result
    }

    private func flagChip(_ flag: Flag) -> some View {
        HStack(spacing: 6) {
            Circle().fill(flag.color).frame(width: 6, height: 6)
            Text(flag.label).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(flag.color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(flag.color.opacity(0.13), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(flag.color.opacity(0.3)))
    }
}

private extension HealthVerdictColor {
    var uiColor: Color {
        switch self {
        case .good: return TLColor.accent
        case .fair: return TLColor.warn
        case .poor: return TLColor.danger
        }
    }
}

#Preview {
    ZStack {
        TLColor.bg.ignoresSafeArea()
        HealthScoreCard(product: ProductInfo(
            barcode: "1", name: "Aloo Bhujia", brand: "Haldiram's", servingSize: "Per 100g",
            calories: 546, nutrients: [], ingredients: "",
            novaGroup: 4, nutriscoreGrade: "d", isPalmOilFree: false,
            sugarGrams: 2.4, sodiumMg: 1180
        ))
        .padding(24)
    }
}
