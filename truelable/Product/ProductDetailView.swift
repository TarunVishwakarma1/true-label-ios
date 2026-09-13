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
    /// Completes the scan→verify→detail continuity from `ScannerView`'s
    /// viewfinder through `VerifyPromptView`'s card into this screen's
    /// paper label — `nil` when shown on its own (e.g. the `#Preview`
    /// below), which just skips the matched-geometry effect.
    var namespace: Namespace.ID? = nil
    var onDismiss: () -> Void

    /// Fixed-size hero numbers don't grow with the user's chosen text size
    /// by default — `@ScaledMetric` keeps this one respecting Dynamic Type
    /// instead of silently opting out of an accessibility setting.
    @ScaledMetric private var calorieFontSize: CGFloat = 40

    @AppStorage("healthProfile.watchingSugar") private var watchingSugar = false
    @AppStorage("healthProfile.watchingSodium") private var watchingSodium = false
    @State private var showingHealthProfile = false
    @State private var alternatives: [ProductAlternative] = []

    private let cardColor = Color(red: 0.07, green: 0.07, blue: 0.09)
    private let warningCardColor = Color(red: 0.18, green: 0.1, blue: 0.05)

    private var primaryWatch: WatchedNutrient? {
        if watchingSugar { return .sugar }
        if watchingSodium { return .sodium }
        return nil
    }

    /// The primary watched nutrient's raw per-100g value, if this product
    /// has one — `nil` means "don't know", never treated as "low".
    private func rawValue(for nutrient: WatchedNutrient) -> Double? {
        switch nutrient {
        case .sugar: return product.sugarGrams
        case .sodium: return product.sodiumMg
        }
    }

    /// Watched nutrient sorted first, everything else keeping its original
    /// order — matches the website's `profile` phase.
    private var orderedNutrients: [Nutrient] {
        guard let watch = primaryWatch else { return product.nutrients }
        var rest = product.nutrients
        if let index = rest.firstIndex(where: { $0.name.localizedCaseInsensitiveContains(watch.rawValue) }) {
            let flagged = rest.remove(at: index)
            return [flagged] + rest
        }
        return rest
    }

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
                        HealthScoreCard(product: product, primaryWatch: primaryWatch)
                        MacroBreakdownCard(product: product)
                        nutritionFactsCard
                        if primaryWatch != nil {
                            personalizedCard
                        }
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
        .sheet(isPresented: $showingHealthProfile) {
            HealthProfileSheet(onDismiss: { showingHealthProfile = false })
        }
        .task(id: primaryWatch) {
            guard let watch = primaryWatch else {
                alternatives = []
                return
            }
            alternatives = (try? await ProductAPIClient.fetchAlternatives(barcode: product.barcode, sortBy: watch.apiKey)) ?? []
        }
        .sensoryFeedback(.selection, trigger: primaryWatch)
    }

    private var topBar: some View {
        HStack {
            Button {
                showingHealthProfile = true
            } label: {
                Image(systemName: "person.crop.circle")
                    .font(.headline)
                    .foregroundStyle(HealthProfile.isActive ? TLColor.accent : .white)
                    .frame(width: 20, height: 20)
                    .padding(12)
                    .background(cardBackground(Circle()))
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel("Health profile")

            Spacer()

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
            HStack(alignment: .firstTextBaseline) {
                Text(product.name)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Spacer()
                if product.verificationCount > 0 {
                    Text("\(product.verificationCount) verified")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(TLColor.accent)
                }
            }
            Text(product.brand)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
            Text(product.servingSize)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    /// The physical label — this is the one place the "terminal chrome vs.
    /// warm paper" tension in this app's design language pays off: dark HUD
    /// everywhere else, but the actual nutrition truth prints on paper,
    /// same `#F4EFE2` as the website's `LabelCard`. Tilt-responsive (see
    /// `TiltEffect`) so it reads as something you're physically holding.
    private var nutritionFactsCard: some View {
        NutritionLabelView(namespace: namespace) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Calories")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(TLColor.paperMuted)
                    Text("\(product.calories)")
                        .font(.system(size: calorieFontSize, weight: .bold, design: .rounded))
                        .foregroundStyle(TLColor.paperInk)
                }
                .padding(.bottom, 14)

                Divider().overlay(.black.opacity(0.15))
                    .padding(.bottom, 6)

                ForEach(Array(orderedNutrients.enumerated()), id: \.element.id) { index, nutrient in
                    if index > 0 {
                        Divider().overlay(.black.opacity(0.1))
                    }
                    nutrientRow(nutrient, isWatched: index == 0 && primaryWatch != nil)
                        .padding(.vertical, 10)
                        // Without this, VoiceOver stops on "Total Fat", then
                        // "9.8g", then "13%" as three separate swipes instead
                        // of one coherent "Total Fat, 9.8g, 13%" reading.
                        .accessibilityElement(children: .combine)
                }

                if let sugarGrams = product.sugarGrams {
                    Divider().overlay(.black.opacity(0.15))
                        .padding(.vertical, 6)
                    SugarTeaspoonsView(sugarGrams: sugarGrams)
                }
            }
        }
        .tiltResponsive(maxDegrees: 6)
    }

    @ViewBuilder
    private func nutrientRow(_ nutrient: Nutrient, isWatched: Bool) -> some View {
        let flaggedHigh = isWatched && (primaryWatch.map { rawValue(for: $0).map($0.isHigh) ?? false } ?? false)

        HStack {
            Text(nutrient.name)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(TLColor.paperInk)
            Spacer()
            Text(nutrient.amount)
                .font(.system(.subheadline, design: .monospaced).monospacedDigit())
                .foregroundStyle(TLColor.paperInk.opacity(0.8))
            if let dv = nutrient.dailyValuePercent {
                Text("\(dv)%")
                    .font(.system(.caption, design: .monospaced).monospacedDigit())
                    .foregroundStyle(TLColor.paperMuted)
                    .frame(width: 40, alignment: .trailing)
            }
        }
        .padding(.leading, isWatched ? 10 : 0)
        .overlay(alignment: .leading) {
            if isWatched {
                Rectangle()
                    .fill(flaggedHigh ? TLColor.warn : TLColor.accent)
                    .frame(width: 2)
            }
        }
    }

    /// Matches the website's "profile" phase copy exactly. Only shown once
    /// a watched nutrient is active (`primaryWatch != nil`), and the
    /// alternative line only appears once a real one has actually loaded —
    /// no category match is a legitimate, silent outcome, never faked.
    private var personalizedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Flagged first because you asked. Nothing else changes.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.85))

            if let alt = alternatives.first {
                Text("Same shelf · \(alt.productName)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
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
