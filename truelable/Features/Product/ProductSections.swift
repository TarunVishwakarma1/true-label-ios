//
//  ProductSections.swift
//  truelable
//
//  The cards that make up ProductScreen. Each owns exactly one idea.
//

import SwiftUI

// MARK: - Verdict

struct VerdictCard: View {
    let product: Product

    var body: some View {
        if let score = product.healthScore, let verdict = product.verdict {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 20) {
                    ScoreRing(score: score, color: color(verdict.tone))
                    VStack(alignment: .leading, spacing: 8) {
                        Text(verdict.headline)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(color(verdict.tone))
                            .fixedSize(horizontal: false, vertical: true)
                        GradeStrip(grade: product.nutriscoreGrade)
                        if let nova = product.novaLabel {
                            Pill(text: "NOVA \(product.novaGroup ?? 0) · \(nova)", color: TL.nova(product.novaGroup))
                        }
                    }
                    Spacer(minLength: 0)
                }
                Text("Estimated from Nutri-Score and NOVA processing group — not an official score.")
                    .font(.caption2)
                    .foregroundStyle(TL.fg3)
            }
            .card(.hero)
        } else {
            HStack(spacing: 16) {
                Image(systemName: "questionmark.circle")
                    .font(.title2)
                    .foregroundStyle(TL.fg3)
                VStack(alignment: .leading, spacing: 4) {
                    Text("No overall score yet")
                        .font(.subheadline.weight(.semibold))
                    Text("The source hasn't graded this product. The numbers below are still real.")
                        .font(.footnote)
                        .foregroundStyle(TL.fg2)
                }
            }
            .card(.flat)
        }
    }

    private func color(_ tone: Tone) -> Color {
        switch tone {
        case .good: TL.good
        case .fair: TL.warn
        case .poor: TL.danger
        }
    }
}

// MARK: - For you

struct ForYouCard: View {
    let checks: [PersonalCheck]

    private var worst: PersonalCheck.Status { checks.first?.status ?? .good }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                SectionHeader(title: "For you")
                Image(systemName: worst.icon)
                    .foregroundStyle(worst.color)
            }
            VStack(spacing: 0) {
                ForEach(Array(checks.enumerated()), id: \.element.id) { i, check in
                    if i > 0 { Hairline() }
                    HStack(spacing: 12) {
                        Image(systemName: check.status.icon)
                            .font(.body)
                            .foregroundStyle(check.status.color)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(check.message)
                                .font(.subheadline.weight(.medium))
                            Text(check.preference.rawValue)
                                .font(.caption)
                                .foregroundStyle(TL.fg3)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .card(fill: worst == .avoid ? Color(hex: 0x24151A) : TL.surface)
    }
}

// MARK: - Macros

struct MacroCard: View {
    let product: Product

    private var n: Nutrition { product.nutrition }
    private var maxMacro: Double { max(n.fat ?? 0, n.carbs ?? 0, n.protein ?? 0, 1) }

    var body: some View {
        if n.fat != nil || n.carbs != nil || n.protein != nil || n.energyKcal != nil {
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.calories.map { "\($0)" } ?? "—")
                        .font(.displayXL)
                        .numeric()
                    Text("kcal / 100 g")
                        .font(.caption)
                        .foregroundStyle(TL.fg3)
                }
                .frame(minWidth: 96, alignment: .leading)

                VStack(spacing: 12) {
                    if let fat = n.fat { bar("Fat", fat, TL.warn) }
                    if let carbs = n.carbs { bar("Carbs", carbs, TL.info) }
                    if let protein = n.protein { bar("Protein", protein, TL.violet) }
                }
            }
            .card()
        }
    }

    private func bar(_ label: String, _ grams: Double, _ color: Color) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(label).font(.caption.weight(.medium)).foregroundStyle(TL.fg2)
                Spacer()
                Text("\(grams.compact) g").font(.caption.weight(.semibold)).numeric()
            }
            BarMeter(fraction: grams / maxMacro, color: color, height: 5)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Sugar

struct SugarCard: View {
    let sugarGrams: Double

    private var teaspoons: Int { max(1, Int((sugarGrams / 4).rounded())) }
    private var percentOfDay: Int { Int((sugarGrams / 50 * 100).rounded()) }
    private var tint: Color {
        sugarGrams >= Threshold.sugarHigh ? TL.danger : sugarGrams <= Threshold.sugarLow ? TL.good : TL.warn
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeader(title: "Sugar")
                Text("\(sugarGrams.compact) g / 100 g")
                    .font(.footnote.weight(.semibold))
                    .numeric()
                    .foregroundStyle(tint)
            }
            HStack(spacing: 4) {
                ForEach(0..<min(teaspoons, 12), id: \.self) { _ in
                    Image(systemName: "cube.fill")
                        .font(.title3)
                        .foregroundStyle(tint.opacity(0.9))
                }
                if teaspoons > 12 {
                    Text("+\(teaspoons - 12)").font(.caption.weight(.bold)).foregroundStyle(tint)
                }
            }
            .accessibilityElement()
            .accessibilityLabel("About \(teaspoons) teaspoons of sugar per 100 grams")
            Text("≈ \(teaspoons) teaspoon\(teaspoons == 1 ? "" : "s") · \(percentOfDay)% of a 50 g day, per 100 g")
                .font(.caption)
                .foregroundStyle(TL.fg3)
        }
        .card()
    }
}

// MARK: - Nutrition label (paper)

struct LabelCard: View {
    let product: Product

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TornEdge().fill(TL.paper).frame(height: 8)
            VStack(alignment: .leading, spacing: 0) {
                Text("Nutrition Facts")
                    .font(.system(.title2, weight: .black))
                    .foregroundStyle(TL.paperInk)
                Text("Per 100 g")
                    .font(.footnote)
                    .foregroundStyle(TL.paperMuted)
                    .padding(.bottom, 8)
                Rectangle().fill(TL.paperInk).frame(height: 6).padding(.bottom, 6)

                HStack(alignment: .firstTextBaseline) {
                    Text("Calories").font(.headline).foregroundStyle(TL.paperInk)
                    Spacer()
                    Text(product.calories.map { "\($0)" } ?? "—")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .numeric()
                        .foregroundStyle(TL.paperInk)
                }
                Rectangle().fill(TL.paperInk).frame(height: 3).padding(.vertical, 6)

                ForEach(Array(product.nutrition.labelRows.enumerated()), id: \.offset) { i, row in
                    if i > 0 { Divider().overlay(TL.paperInk.opacity(0.18)) }
                    HStack {
                        Text(row.name)
                            .font(.subheadline.weight(row.name.hasPrefix("Total") || row.name == "Protein" || row.name == "Sodium" ? .bold : .regular))
                        Spacer()
                        Text(row.value).font(.subheadline).numeric()
                    }
                    .foregroundStyle(TL.paperInk)
                    .padding(.leading, row.name.hasPrefix("Total") || row.name == "Protein" || row.name == "Sodium" || row.name == "Cholesterol" ? 0 : 14)
                    .padding(.vertical, 7)
                    .accessibilityElement(children: .combine)
                }
                Rectangle().fill(TL.paperInk).frame(height: 3).padding(.top, 6)
            }
            .padding(18)
        }
        .background(TL.paper)
        .clipShape(RoundedRectangle(cornerRadius: TL.R.sm, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 20, y: 10)
        .padding(.vertical, 6)
    }
}

private struct TornEdge: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let teeth = 22
        let step = rect.width / CGFloat(teeth)
        p.move(to: CGPoint(x: 0, y: rect.maxY))
        for i in 0...teeth {
            p.addLine(to: CGPoint(x: CGFloat(i) * step, y: i.isMultiple(of: 2) ? rect.minY : rect.midY))
        }
        p.addLine(to: CGPoint(x: rect.width, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Ingredients / additives / allergens

struct IngredientsCard: View {
    let text: String
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Ingredients")
            Text(text)
                .font(.subheadline)
                .foregroundStyle(TL.fg2)
                .lineLimit(expanded ? nil : 4)
                .fixedSize(horizontal: false, vertical: true)
            if text.count > 180 {
                Button(expanded ? "Show less" : "Show all") {
                    withAnimation(.tl(0.35)) { expanded.toggle() }
                }
                .font(.footnote.weight(.semibold))
            }
        }
        .card()
    }
}

struct AdditivesCard: View {
    let codes: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Additives", detail: "\(codes.count)")
            VStack(spacing: 0) {
                ForEach(Array(codes.enumerated()), id: \.offset) { i, code in
                    if i > 0 { Hairline() }
                    HStack {
                        Text(code)
                            .font(.subheadline.weight(.bold).monospaced())
                        Spacer()
                        Text(Additive.kind(of: code))
                            .font(.footnote)
                            .foregroundStyle(TL.fg2)
                    }
                    .padding(.vertical, 9)
                    .accessibilityElement(children: .combine)
                }
            }
            Text("Class by E-number range. Presence isn't a risk claim — check the pack if one matters to you.")
                .font(.caption2)
                .foregroundStyle(TL.fg3)
        }
        .card()
    }
}

struct AllergensCard: View {
    var allergens: [String]
    var traces: [String]

    /// Source slugs are `"tree-nuts"`, `"en"`-stripped upstream. This only
    /// makes them readable.
    private func label(_ slug: String) -> String {
        slug.replacingOccurrences(of: "-", with: " ").capitalized
    }

    private var declared: [String] { allergens.filter { $0 != "none" } }

    var body: some View {
        if !declared.isEmpty || !traces.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    SectionHeader(title: "Allergens")
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(TL.warn)
                }

                if !declared.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CONTAINS")
                            .font(.caption2.weight(.bold)).tracking(1).foregroundStyle(TL.danger)
                        FlowLayout(spacing: 8) {
                            ForEach(declared, id: \.self) { Pill(text: label($0), color: TL.danger) }
                        }
                    }
                }

                // Separate on purpose: for an allergy this is often the line
                // that decides it, and burying it with the ingredients hides it.
                if !traces.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MAY CONTAIN")
                            .font(.caption2.weight(.bold)).tracking(1).foregroundStyle(TL.warn)
                        FlowLayout(spacing: 8) {
                            ForEach(traces, id: \.self) { Pill(text: label($0), color: TL.warn) }
                        }
                    }
                }
            }
            .card(fill: Color(hex: 0x231A10))
        }
    }
}

// MARK: - Alternatives

/// Same-shelf swaps. Free: the top three on the nutrient you watch. Plus:
/// pick the nutrient and see the full ranked list.
struct AlternativesCard: View {
    let product: Product
    let prefs: Set<DietaryPreference>

    @State private var alternatives: [ProductCard] = []
    @State private var sortKey: String = "sugar"
    @State private var loaded = false
    private let plus = Plus.shared

    private static let sorts: [(key: String, label: String, unit: String)] = [
        ("sugar", "Sugar", "g sugar"), ("sodium", "Sodium", "g sodium"), ("fat", "Fat", "g fat"),
        ("saturated_fat", "Sat. fat", "g sat. fat"), ("energy_kcal", "Calories", "kcal"),
        ("protein", "Protein", "g protein"), ("score", "Overall grade", "")
    ]

    private var unit: String { Self.sorts.first { $0.key == sortKey }?.unit ?? "" }
    private var title: String {
        sortKey == "score" ? "Better graded, same shelf" : (sortKey == "protein" ? "More protein, same shelf" : "Lower \(Self.sorts.first { $0.key == sortKey }?.label.lowercased() ?? sortKey), same shelf")
    }

    var body: some View {
        if !alternatives.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionHeader(title: title, detail: product.category?.replacingOccurrences(of: "-", with: " ").capitalized)
                    if plus.isActive {
                        Menu {
                            Picker("Rank by", selection: $sortKey) {
                                ForEach(Self.sorts, id: \.key) { Text($0.label).tag($0.key) }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down.circle.fill")
                                .font(.title3)
                                .foregroundStyle(TL.accent)
                        }
                    }
                }
                VStack(spacing: 0) {
                    ForEach(Array(alternatives.enumerated()), id: \.element.id) { i, alt in
                        if i > 0 { Hairline() }
                        NavigationLink(value: alt.barcode) {
                            ProductCardRow(card: alt, trailing: alt.sortValue.map { "\($0.compact) \(unit)" })
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.pressable)
                    }
                }
                if !plus.isActive {
                    PlusGate(text: "Rank by any nutrient · see the full shelf")
                }
            }
            .card()
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
        // Rendered even when empty so the task still runs.
        Color.clear.frame(height: 0)
            .task(id: "\(product.barcode)|\(sortKey)|\(plus.isActive)") {
                if !loaded {
                    sortKey = prefs.contains(.lowSodium) && !prefs.contains(.lowSugar) ? "sodium"
                        : prefs.contains(.highProtein) && !prefs.contains(.lowSugar) ? "protein" : "sugar"
                    loaded = true
                }
                let found = (try? await API.alternatives(
                    barcode: product.barcode, sortBy: sortKey,
                    limit: plus.isActive ? 10 : Plus.freeAlternativesLimit
                )) ?? []
                withAnimation(.tl(0.4)) { alternatives = found }
            }
    }
}

// MARK: - Community verification

struct CommunityCard: View {
    @Binding var product: Product

    @AppStorage(Keys.verifiedCount) private var verifiedCount = 0
    @AppStorage(Keys.verifiedBarcodes) private var verifiedBarcodes = ""
    @State private var submitting = false
    @State private var error: String?
    @State private var celebrate = 0

    private var alreadyConfirmed: Bool { verifiedBarcodes.split(separator: ",").contains(Substring(product.barcode)) }
    private var remaining: Int { max(0, 3 - product.verificationCount) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: product.verified ? "checkmark.seal.fill" : "person.2.fill")
                    .font(.title3)
                    .foregroundStyle(product.verified ? TL.accent : TL.fg2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.verified ? "Community verified" : "Help verify this label")
                        .font(.subheadline.weight(.semibold))
                    Text(product.verified
                         ? "\(product.verificationCount) people confirmed it matches the pack."
                         : "\(product.verificationCount) of 3 confirmations so far — \(remaining) more to go.")
                        .font(.footnote)
                        .foregroundStyle(TL.fg2)
                        .contentTransition(.numericText())
                }
            }

            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule()
                        .fill(i < product.verificationCount ? TL.accent : Color.white.opacity(0.1))
                        .frame(height: 4)
                }
            }
            .animation(.tl(0.5), value: product.verificationCount)

            if alreadyConfirmed {
                Label("You confirmed this one. Thanks.", systemImage: "checkmark.circle.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(TL.accent)
            } else {
                Button {
                    Task { await confirm() }
                } label: {
                    HStack(spacing: 8) {
                        if submitting { ProgressView().tint(TL.ink) }
                        Text("It matches the label")
                    }
                }
                .buttonStyle(.primary)
                .disabled(submitting)
                Text("Only tap if the name and numbers match what's printed on the pack you're holding.")
                    .font(.caption2)
                    .foregroundStyle(TL.fg3)
            }

            if let error {
                Text(error).font(.caption).foregroundStyle(TL.danger)
            }
        }
        .card()
        .sensoryFeedback(.success, trigger: celebrate)
    }

    private func confirm() async {
        submitting = true
        error = nil
        do {
            let updated = try await API.verify(barcode: product.barcode)
            withAnimation(.tl(0.5)) {
                product.verified = updated.verified
                product.verificationCount = updated.verificationCount
            }
            verifiedCount += 1
            verifiedBarcodes = (verifiedBarcodes.split(separator: ",").map(String.init) + [product.barcode]).joined(separator: ",")
            celebrate += 1
        } catch {
            self.error = error.localizedDescription
        }
        submitting = false
    }
}
