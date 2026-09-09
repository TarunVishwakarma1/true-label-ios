//
//  ProductDetailView.swift
//  truelable
//

import SwiftUI

/// Nutrition facts for a scanned product. Cards here are opaque, not glass
/// or Material — a translucent surface re-sampling an animating backdrop
/// behind it degrades over sustained use (both `.glassEffect()` and
/// `Material` did this), and no amount of tuning fixed that; removing the
/// live backdrop-sampling entirely does. The aurora still animates in the
/// background and margins, just not blurred through the cards.
struct ProductDetailView: View {
    var product: ProductInfo
    var onDismiss: () -> Void

    /// Fixed-size hero numbers don't grow with the user's chosen text size
    /// by default — `@ScaledMetric` keeps this one respecting Dynamic Type
    /// instead of silently opting out of an accessibility setting.
    @ScaledMetric private var calorieFontSize: CGFloat = 40

    private let cardColor = Color(red: 0.07, green: 0.07, blue: 0.09)
    private let warningCardColor = Color(red: 0.18, green: 0.1, blue: 0.05)

    private func cardBackground(_ shape: some InsettableShape, warning: Bool = false) -> some View {
        shape.fill(warning ? warningCardColor : cardColor)
            .overlay(shape.strokeBorder(.white.opacity(0.08), lineWidth: 1))
    }

    var body: some View {
        ZStack {
            DotGridBackground()

            VStack(spacing: 0) {
                topBar

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        if hasBadges {
                            badgesRow
                        }
                        nutritionFactsCard
                        ingredientsCard
                        if !product.allergens.isEmpty || !product.additives.isEmpty {
                            safetyCard
                        }
                    }
                    .padding(20)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var topBar: some View {
        HStack {
            Text("Nutrition Facts")
                .font(.headline)
                .foregroundStyle(.white)

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .padding(12)
                    .background(cardBackground(Circle()))
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(product.name)
                .font(.title2.bold())
                .foregroundStyle(.white)
            Text(product.brand)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
            Text(product.servingSize)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    /// Calories header + the full nutrient list as one panel — a real
    /// nutrition label is one unified block, not scattered cards, and it's
    /// one `.glassEffect()` surface instead of two.
    private var nutritionFactsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Calories")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                Text("\(product.calories)")
                    .font(.system(size: calorieFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 14)

            Divider().overlay(.white.opacity(0.15))
                .padding(.bottom, 6)

            ForEach(Array(product.nutrients.enumerated()), id: \.element.id) { index, nutrient in
                if index > 0 {
                    Divider().overlay(.white.opacity(0.1))
                }
                HStack {
                    Text(nutrient.name)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                    Spacer()
                    Text(nutrient.amount)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.75))
                    if let dv = nutrient.dailyValuePercent {
                        Text("\(dv)%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.white.opacity(0.45))
                            .frame(width: 40, alignment: .trailing)
                    }
                }
                .padding(.vertical, 10)
                // Without this, VoiceOver stops on "Total Fat", then "9.8g",
                // then "13%" as three separate swipes instead of one
                // coherent "Total Fat, 9.8g, 13%" reading.
                .accessibilityElement(children: .combine)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground(RoundedRectangle(cornerRadius: 20)))
    }

    private var ingredientsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ingredients")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
            Text(product.ingredients)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground(RoundedRectangle(cornerRadius: 20)))
    }

    /// Allergens + additives together — both are "things to watch out for",
    /// and merging them is one fewer glass surface competing for GPU time
    /// with everything else on this screen.
    private var safetyCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !product.allergens.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Allergens")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                    Text(product.allergens.capitalized)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            if !product.allergens.isEmpty && !product.additives.isEmpty {
                Divider().overlay(.white.opacity(0.15))
            }

            if !product.additives.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Preservatives & Additives")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(product.additives, id: \.self) { code in
                                Text(code)
                                    .font(.caption.bold().monospaced())
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(.white.opacity(0.12), in: Capsule())
                                    .accessibilityLabel("Food additive \(code)")
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground(RoundedRectangle(cornerRadius: 20), warning: !product.allergens.isEmpty))
    }

    // MARK: - Badges (NOVA / Nutri-Score / dietary flags)

    private var hasBadges: Bool {
        product.novaGroup != nil || product.nutriscoreGrade != nil
            || product.isVegan != nil || product.isVegetarian != nil || product.isPalmOilFree != nil
    }

    private var badgesRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                if let grade = product.nutriscoreGrade {
                    badge(
                        title: "Nutri-Score \(grade.uppercased())",
                        icon: "chart.bar.fill",
                        tint: nutriscoreColor(grade)
                    )
                }
                if let nova = product.novaGroup {
                    badge(title: novaLabel(nova), icon: novaIcon(nova), tint: novaColor(nova))
                }
                if product.isVegan == true {
                    badge(title: "Vegan", icon: "leaf.fill", tint: .green)
                }
                if product.isVegetarian == true {
                    badge(title: "Vegetarian", icon: "leaf", tint: .green)
                }
                if product.isPalmOilFree == true {
                    badge(title: "Palm Oil Free", icon: "checkmark.seal.fill", tint: .teal)
                } else if product.isPalmOilFree == false {
                    badge(title: "Contains Palm Oil", icon: "exclamationmark.triangle.fill", tint: .orange)
                }
            }
        }
    }

    /// Icon alongside the (already descriptive) label, not a bare color
    /// swatch — color alone isn't a reliable signal for colorblind users.
    /// A plain tinted background, not `.glassEffect()`: these are small,
    /// numerous, and horizontally scrolling — real-time glass compositing
    /// on every one of them, on top of everything else on this screen, is
    /// the kind of stacking that made this screen laggy in the first place.
    private func badge(title: String, icon: String, tint: Color) -> some View {
        Label(title, systemImage: icon)
            .font(.caption.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(tint.opacity(0.35), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 1))
    }

    private func novaLabel(_ group: Int) -> String {
        switch group {
        case 1: return "NOVA 1 · Unprocessed"
        case 2: return "NOVA 2 · Processed Ingredient"
        case 3: return "NOVA 3 · Processed"
        default: return "NOVA 4 · Ultra-Processed"
        }
    }

    private func novaIcon(_ group: Int) -> String {
        switch group {
        case 1: return "leaf.fill"
        case 2: return "leaf"
        case 3: return "gearshape.fill"
        default: return "flame.fill"
        }
    }

    private func novaColor(_ group: Int) -> Color {
        switch group {
        case 1: return .green
        case 2: return .mint
        case 3: return .orange
        default: return .red
        }
    }

    private func nutriscoreColor(_ grade: String) -> Color {
        switch grade.lowercased() {
        case "a": return .green
        case "b": return .mint
        case "c": return .yellow
        case "d": return .orange
        default: return .red
        }
    }
}

#Preview {
    ProductDetailView(
        product: ProductInfo(
            barcode: "8901030895564",
            name: "Crunchy Masala Chips",
            brand: "Farmland",
            servingSize: "Serving size: 30g (about 12 chips)",
            calories: 154,
            nutrients: [
                Nutrient(name: "Total Fat", amount: "9.8g", dailyValuePercent: 13),
                Nutrient(name: "Sodium", amount: "180mg", dailyValuePercent: 8)
            ],
            ingredients: "Potatoes, Vegetable Oil, Spice Mix, Salt",
            allergens: "None declared",
            additives: ["E322", "E500ii"],
            novaGroup: 4,
            nutriscoreGrade: "d",
            isVegan: true,
            isVegetarian: true,
            isPalmOilFree: false
        ),
        onDismiss: {}
    )
}
