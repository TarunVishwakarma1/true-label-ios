//
//  ProductDetailView.swift
//  truelable
//

import SwiftUI

/// Nutrition facts for a product the scan recognized. Same chrome language
/// as every other screen — custom top bar, glass cards, dot-grid/aurora
/// backdrop — nothing new invented for this one screen.
struct ProductDetailView: View {
    var product: ProductInfo
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            DotGridBackground()

            VStack(spacing: 0) {
                topBar

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        caloriesCard
                        nutrientsCard
                        ingredientsCard
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
                    .glassEffect(.regular, in: Circle())
            }
            .buttonStyle(ScaleButtonStyle())
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
            Text("Per serving: \(product.servingSize)")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    private var caloriesCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Calories")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                Text("\(product.calories)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
    }

    private var nutrientsCard: some View {
        VStack(spacing: 0) {
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
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
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
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
    }
}

#Preview {
    ProductDetailView(
        product: ProductInfo(
            barcode: "8901030895564",
            name: "Crunchy Masala Chips",
            brand: "Farmland",
            servingSize: "30g (about 12 chips)",
            calories: 154,
            nutrients: [
                Nutrient(name: "Total Fat", amount: "9.8g", dailyValuePercent: 13),
                Nutrient(name: "Sodium", amount: "180mg", dailyValuePercent: 8)
            ],
            ingredients: "Potatoes, Vegetable Oil, Spice Mix, Salt"
        ),
        onDismiss: {}
    )
}
