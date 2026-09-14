//
//  ProductScreen.swift
//  truelable
//
//  The result. Ordered the way a shopper actually decides: verdict → what
//  it means for *you* → the numbers → the fine print → what else is on the
//  shelf → help keep it honest. Every section hides itself when the data
//  behind it doesn't exist.
//

import SwiftUI
import SwiftData

struct ProductScreen: View {
    @State private var product: Product
    let inSheet: Bool

    @AppStorage(Keys.dietary) private var dietaryRaw = ""
    @State private var comparePicker = false
    @State private var lightboxShown = false

    init(product: Product, inSheet: Bool = false) {
        _product = State(initialValue: product)
        self.inSheet = inSheet
    }

    private var checks: [PersonalCheck] {
        PersonalCheck.run(DietaryPreference.decode(dietaryRaw), on: product)
            .sorted { $0.status.rank < $1.status.rank }
    }

    var body: some View {
        ScrollView {
            GlassEffectContainer(spacing: 16) {
                VStack(spacing: 16) {
                    hero.appear(0)
                    VerdictCard(product: product).appear(1)
                    if !checks.isEmpty {
                        ForYouCard(checks: checks).appear(2)
                    }
                    MacroCard(product: product).appear(3)
                    if let sugar = product.nutrition.sugar {
                        SugarCard(sugarGrams: sugar).appear(4)
                    }
                    if !product.nutrition.isEmpty {
                        LabelCard(product: product).appear(5)
                    }
                    if let ingredients = product.ingredients {
                        IngredientsCard(text: ingredients).appear(6)
                    }
                    if !product.additives.isEmpty {
                        AdditivesCard(codes: product.additives).appear(6)
                    }
                    AllergensCard(allergens: product.allergens ?? [], traces: product.traces ?? [])
                        .appear(6)
                    AlternativesCard(product: product, prefs: DietaryPreference.decode(dietaryRaw))
                    CommunityCard(product: $product).appear(7)
                    compareCard.appear(7)
                    footer.appear(8)
                }
            }
            .padding(.horizontal, TL.gutter)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(alignment: .top) { imageBleed }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .screenBackground()
        .navigationTitle(inSheet ? "" : product.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Compare", systemImage: "arrow.left.arrow.right") { comparePicker = true }
                ShareLink(item: product.shareSummary) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share")
            }
            if inSheet { CloseButton() }
        }
        .sheet(isPresented: $comparePicker) {
            ComparePickerSheet(current: product)
        }
        .fullScreenCover(isPresented: $lightboxShown) {
            ImageLightboxView(urls: [product.imageURL].compactMap { $0 })
        }
    }

    /// The product's own photo, blown up and blurred, bleeding from the
    /// top — masked to nothing before the first card. Static, one image.
    @ViewBuilder
    private var imageBleed: some View {
        if let url = product.imageURL {
            CachedAsyncImage(url: url) { image in
                image?.resizable().scaledToFill()
            }
            .frame(height: 280)
            .frame(maxWidth: .infinity)
            .clipped()
            .blur(radius: 40)
            .opacity(0.45)
            .saturation(1.3)
            .drawingGroup()
            .mask(LinearGradient(colors: [.black, .black, .clear], startPoint: .top, endPoint: .bottom))
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                Button {
                    if product.imageURL != nil { lightboxShown = true }
                } label: {
                    ProductThumb(url: product.imageURL, size: 104, radius: 26)
                        .shadow(color: .black.opacity(0.4), radius: 18, y: 10)
                }
                .buttonStyle(.plain)
                .disabled(product.imageURL == nil)
                VStack(alignment: .leading, spacing: 8) {
                    if let brand = product.brand { Eyebrow(text: brand) }
                    Text(product.name)
                        .font(.displayM)
                        .tracking(-0.4)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                if product.verified {
                    Pill(text: "Verified", color: TL.accent, icon: "checkmark.seal.fill", filled: true)
                } else if product.isCommunitySourced {
                    Pill(text: "Community", color: TL.warn, icon: "person.2.fill")
                } else {
                    Pill(text: "Open Food Facts", color: TL.fg2, icon: "globe")
                }
                if let grade = product.nutriscoreGrade {
                    Pill(text: "Nutri-Score \(grade.uppercased())", color: TL.grade(grade))
                }
                if let nova = product.novaGroup {
                    Pill(text: "NOVA \(nova)", color: TL.nova(nova))
                }
            }
        }
        .engraved()
        .padding(.vertical, 8)
    }

    private var compareCard: some View {
        Button { comparePicker = true } label: {
            HStack(spacing: 16) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.title3)
                    .foregroundStyle(TL.info)
                    .frame(width: 44, height: 44)
                    .background(TL.info.opacity(0.14), in: RoundedRectangle(cornerRadius: TL.R.sm, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Line it up against something else")
                        .font(.subheadline.weight(.semibold))
                    Text("Side by side with anything you've already scanned.")
                        .font(.footnote)
                        .foregroundStyle(TL.fg2)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(TL.fg3)
            }
            .card(.flat)
        }
        .buttonStyle(.pressable)
    }

    private var footer: some View {
        VStack(spacing: 4) {
            Text(product.barcode)
                .font(.caption.monospaced())
                .foregroundStyle(TL.fg3)
            Text("Values per 100 g as published by the source. Always check the pack.")
                .font(.caption2)
                .foregroundStyle(TL.fg3)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 12)
    }
}

/// Pick what to line this product up against, from history. Free: one
/// other product. Plus: up to three.
struct ComparePickerSheet: View {
    let current: Product
    @Query(sort: \ScanRecord.scannedAt, order: .reverse) private var records: [ScanRecord]
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String> = []
    @State private var comparing: [ScanRecord] = []
    private let plus = Plus.shared

    private var others: [ScanRecord] { records.filter { $0.barcode != current.barcode } }
    private var limit: Int { (plus.isActive ? 4 : Plus.freeCompareLimit) - 1 }

    var body: some View {
        NavigationStack {
            Group {
                if others.isEmpty {
                    ContentUnavailableView("Nothing to compare yet", systemImage: "arrow.left.arrow.right",
                                           description: Text("Scan another product and it'll show up here."))
                } else {
                    List {
                        Section {
                            ForEach(others) { r in
                                Button {
                                    toggle(r.barcode)
                                } label: {
                                    HStack(spacing: 16) {
                                        Image(systemName: selected.contains(r.barcode) ? "checkmark.circle.fill" : "circle")
                                            .font(.title3)
                                            .foregroundStyle(selected.contains(r.barcode) ? TL.accent : TL.fg3)
                                        ProductThumb(url: r.imageURL, size: 48, radius: 14)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(r.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                                            Text(r.brand.isEmpty ? r.scannedAt.formatted(.relative(presentation: .named)) : r.brand)
                                                .font(.caption).foregroundStyle(TL.fg3).lineLimit(1)
                                        }
                                        Spacer()
                                        GradeBadge(grade: r.nutriscoreGrade)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(Color.clear)
                                .listRowSeparatorTint(TL.line)
                            }
                        } header: {
                            Text(plus.isActive ? "Pick up to three" : "Pick one · Plus compares four")
                        }
                        if !plus.isActive {
                            PlusGate(text: "Compare up to four at once").listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .screenBackground()
            .navigationTitle("Compare with")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) {
                Button("Compare \(selected.count + 1) products") {
                    let me = records.first { $0.barcode == current.barcode } ?? ScanRecord(product: current)
                    comparing = [me] + others.filter { selected.contains($0.barcode) }
                }
                .buttonStyle(.primary)
                .disabled(selected.isEmpty)
                .opacity(selected.isEmpty ? 0.5 : 1)
                .padding(.horizontal, TL.gutter)
                .padding(.vertical, 12)
            }
            .sheet(isPresented: Binding(get: { !comparing.isEmpty }, set: { if !$0 { comparing = [] } })) {
                CompareView(records: comparing)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(TL.bg)
        .presentationCornerRadius(32)
    }

    private func toggle(_ barcode: String) {
        withAnimation(.tl(0.25)) {
            if selected.contains(barcode) {
                selected.remove(barcode)
            } else if selected.count < limit {
                selected.insert(barcode)
            } else if limit == 1 {
                selected = [barcode]
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProductScreen(product: Product(
            barcode: "8901030895564", name: "Aloo Bhujia", brand: "Haldiram's",
            nutrition: {
                var n = Nutrition()
                n.energyKcal = 546; n.protein = 9.2; n.carbs = 43.8; n.fat = 36.4
                n.saturatedFat = 12; n.sugar = 2.4; n.sodium = 1.18; n.fiber = 3
                return n
            }(),
            ingredients: "Gram flour, edible vegetable oil (palm), potato, salt, spices, red chilli, acidity regulator (E330)",
            allergens: ["peanuts"], traces: ["tree-nuts"], labels: ["vegetarian"],
            additives: ["E330", "E500II"], servingSize: "30 g", servingQuantity: 30,
            nutrientLevels: ["sugar": "low", "sodium": "high", "fat": "high"],
            novaGroup: 4, nutriscoreGrade: "d",
            isVegan: true, isVegetarian: true, isPalmOilFree: false
        ))
    }
    .modelContainer(for: ScanRecord.self, inMemory: true)
    .preferredColorScheme(.dark)
}
