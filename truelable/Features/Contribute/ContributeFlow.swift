import SwiftUI

struct ContributeFlow: View {
    let barcode: String
    var onFinished: (Bool) -> Void

    private enum Take: Int, CaseIterable {
        case front, ingredients, nutrition
        var title: String {
            switch self {
            case .front: "Front of the pack"
            case .ingredients: "Ingredient list"
            case .nutrition: "Nutrition table"
            }
        }
        var hint: String {
            switch self {
            case .front: "So we get the name and brand exactly as printed."
            case .ingredients: "Hold steady until the lines lock. This one's required."
            case .nutrition: "Per-100 g column if there are two."
            }
        }
        var optional: Bool { self != .ingredients }
    }

    private enum Step: Equatable {
        case take(Take), review, submitting, done, failed(String)
    }

    @State private var step: Step = .take(.front)
    @State private var takes: [Take: TextTake] = [:]
    @State private var tally = TextTally()
    @State private var draft: LabelOCR.Draft?
    @State private var finished = 0
    @State private var captured = 0

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .take(let take):
                    takeScreen(take)
                case .review:
                    if let draft {
                        ReviewStep(draft: draft, onSubmit: submit, onRetake: { restart() })
                    }
                case .submitting:
                    waiting("Sending it in…")
                case .done:
                    done
                case .failed(let message):
                    failed(message)
                }
            }
            .screenBackground()
            .toolbar {
                ToolbarItem(placement: .principal) { progress }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") { onFinished(false) }
                }
            }
        }
        .sensoryFeedback(.success, trigger: finished)
        .sensoryFeedback(.impact(weight: .medium), trigger: captured)
    }

    private var stepIndex: Int {
        switch step {
        case .take(let t): t.rawValue
        case .review: 3
        default: 4
        }
    }

    private var progress: some View {
        HStack(spacing: 4) {
            ForEach(0..<5, id: \.self) { i in
                Capsule()
                    .fill(i <= stepIndex ? TL.accent : TL.track)
                    .frame(width: i == stepIndex ? 22 : 8, height: 4)
            }
        }
        .animation(.tl(0.35), value: stepIndex)
    }

    @ViewBuilder
    private func takeScreen(_ take: Take) -> some View {
        if LiveTextReader<EmptyView>.isUsable {
            LiveTextReader(tally: tally) { takeChrome(take) }
                .ignoresSafeArea()
                .id(take)
        } else {
            VStack(spacing: 16) {
                Image(systemName: "camera.fill").font(.largeTitle).foregroundStyle(TL.fg3)
                Text("Live text capture needs a camera").font(.title3.weight(.semibold))
                Text("Try on a device with a camera to add products.").font(.subheadline).foregroundStyle(TL.fg2)
            }
            .padding(40)
        }
    }

    private func takeChrome(_ take: Take) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text(take.title)
                    .font(.displayM)
                    .foregroundStyle(.white)
                Text(take.hint)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)
            .padding(.top, 12)

            Spacer()

            HStack(spacing: 8) {
                Circle()
                    .fill(tally.lockedCount > 0 ? TL.accent : TL.fg3)
                    .frame(width: 8, height: 8)
                Text(tally.lockedCount == 0 ? "Looking for text" : "\(tally.lockedCount) lines locked")
                    .font(.caption.weight(.semibold))
                    .numeric()
                    .contentTransition(.numericText())
            }
            .foregroundStyle(TL.fg)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .plate(TL.surface, lifted: true)
            .animation(.tl(0.3), value: tally.lockedCount)
            .padding(.bottom, 18)

            HStack(spacing: 12) {
                if take.optional {
                    Button("Skip") { advance(from: take, with: nil) }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(TL.fg)
                        .frame(height: 56)
                        .padding(.horizontal, 22)
                        .plate(TL.surface, lifted: true)
                        .buttonStyle(.pressable)
                }
                Button {
                    let take0 = tally.capture()
                    guard !take0.isEmpty else { return }
                    captured += 1
                    advance(from: take, with: take0)
                } label: {
                    Label("Capture", systemImage: "text.viewfinder")
                }
                .buttonStyle(.primary)
                .disabled(tally.lockedCount == 0)
                .opacity(tally.lockedCount == 0 ? 0.5 : 1)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
    }

    private func advance(from take: Take, with result: TextTake?) {
        if let result { takes[take] = result }
        tally.reset()
        if let next = Take(rawValue: take.rawValue + 1) {
            withAnimation(.tl()) { step = .take(next) }
        } else {
            guard let ingredients = takes[.ingredients] else {
                withAnimation(.tl()) { step = .take(.ingredients) }
                return
            }
            draft = LabelOCR.draft(front: takes[.front], ingredients: ingredients, nutrition: takes[.nutrition])
            withAnimation(.tl()) { step = .review }
        }
    }

    private func restart() {
        takes = [:]
        tally.reset()
        withAnimation(.tl()) { step = .take(.front) }
    }

    private func waiting(_ text: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Skeleton(lines: 5).card().padding(.horizontal, 24)
            Text(text).font(.subheadline.weight(.medium)).foregroundStyle(TL.fg2)
            Spacer()
        }
    }

    private var done: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(TL.accent)
                .symbolEffect(.bounce, value: finished)
            Text("Thanks — it's in")
                .font(.displayM)
            Text("Searchable right away, marked unverified until three people confirm it against the pack.")
                .font(.subheadline)
                .foregroundStyle(TL.fg2)
                .multilineTextAlignment(.center)
            Spacer()
            Button("See the product") { onFinished(true) }
                .buttonStyle(.primary)
        }
        .padding(28)
        .onAppear { finished += 1 }
    }

    private func failed(_ message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(TL.warn)
            Text("That didn't go through")
                .font(.displayM)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(TL.fg2)
                .multilineTextAlignment(.center)
            Spacer()
            Button("Back to review") { withAnimation(.tl()) { step = .review } }
                .buttonStyle(.primary)
        }
        .padding(28)
    }

    private func submit(_ d: LabelOCR.Draft) {
        step = .submitting
        Task {
            do {
                try await API.submitLabel(API.LabelSubmission(
                    barcode: barcode,
                    country: API.country,
                    extractedText: d.rawText,
                    reviewedIngredients: d.ingredients,
                    reviewedAllergens: d.allergens,
                    productName: d.name.nilIfBlank,
                    brand: d.brand.nilIfBlank,
                    nutrition: d.nutrition.isEmpty ? nil : d.nutrition
                ))
                withAnimation(.tl()) { step = .done }
            } catch {
                withAnimation(.tl()) { step = .failed(error.localizedDescription) }
            }
        }
    }
}

private struct ReviewStep: View {
    var onSubmit: (LabelOCR.Draft) -> Void
    var onRetake: () -> Void

    @State private var draft: LabelOCR.Draft
    @State private var allergens: String
    @State private var kcal: String
    @State private var fat: String
    @State private var carbs: String
    @State private var sugar: String
    @State private var protein: String
    @State private var sodiumMg: String

    init(draft: LabelOCR.Draft, onSubmit: @escaping (LabelOCR.Draft) -> Void, onRetake: @escaping () -> Void) {
        self.onSubmit = onSubmit
        self.onRetake = onRetake
        _draft = State(initialValue: draft)
        _allergens = State(initialValue: draft.allergens.joined(separator: ", "))
        let n = draft.nutrition
        _kcal = State(initialValue: n.energyKcal.map(\.compact) ?? "")
        _fat = State(initialValue: n.fat.map(\.compact) ?? "")
        _carbs = State(initialValue: n.carbs.map(\.compact) ?? "")
        _sugar = State(initialValue: n.sugar.map(\.compact) ?? "")
        _protein = State(initialValue: n.protein.map(\.compact) ?? "")
        _sodiumMg = State(initialValue: n.sodiumMg.map { Int($0.rounded()) }.map(String.init) ?? "")
    }

    private var canSubmit: Bool { !draft.ingredients.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Does this look right?")
                        .font(.displayM)
                    Text("Fix anything the camera misread. You're the one holding the pack.")
                        .font(.subheadline)
                        .foregroundStyle(TL.fg2)
                }

                VStack(alignment: .leading, spacing: 16) {
                    field("Brand", text: $draft.brand)
                    field("Product name", text: $draft.name)
                    if !draft.nameCandidates.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("READ FROM THE FRONT · TAP TO USE")
                                .font(.caption2.weight(.bold)).tracking(1).foregroundStyle(TL.paperMuted)
                            FlowLayout(spacing: 8) {
                                ForEach(draft.nameCandidates, id: \.self) { c in
                                    Menu {
                                        Button("Use as brand") { draft.brand = c }
                                        Button("Use as product name") { draft.name = c }
                                    } label: {
                                        Text(c)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(TL.paperInk)
                                            .padding(.horizontal, 10).padding(.vertical, 6)
                                            .background(TL.paperInk.opacity(0.08), in: Capsule())
                                    }
                                }
                            }
                        }
                    }
                    field("Ingredients", text: $draft.ingredients, multiline: true)
                    field("Allergens (comma-separated)", text: $allergens)
                }
                .padding(18)
                .background(TL.paper, in: RoundedRectangle(cornerRadius: TL.R.sm, style: .continuous))
                .blockShadow()

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Nutrition per 100 g", detail: "optional")
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        numberField("Energy", unit: "kcal", text: $kcal)
                        numberField("Fat", unit: "g", text: $fat)
                        numberField("Carbs", unit: "g", text: $carbs)
                        numberField("Sugars", unit: "g", text: $sugar)
                        numberField("Protein", unit: "g", text: $protein)
                        numberField("Sodium", unit: "mg", text: $sodiumMg)
                    }
                }
                .card()

                Button("Submit") { onSubmit(assembled) }
                    .buttonStyle(.primary)
                    .disabled(!canSubmit)
                    .opacity(canSubmit ? 1 : 0.5)

                Button("Start over", action: onRetake)
                    .buttonStyle(.secondary)
            }
            .padding(24)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollBounceBehavior(.basedOnSize)
    }

    private var assembled: LabelOCR.Draft {
        var d = draft
        d.allergens = allergens.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        var n = Nutrition()
        n.energyKcal = Double(kcal)
        n.fat = Double(fat)
        n.carbs = Double(carbs)
        n.sugar = Double(sugar)
        n.protein = Double(protein)
        n.sodium = Double(sodiumMg).map { $0 / 1000 }
        n.saturatedFat = draft.nutrition.saturatedFat
        n.fiber = draft.nutrition.fiber
        d.nutrition = n
        return d
    }

    private func field(_ title: String, text: Binding<String>, multiline: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(1)
                .foregroundStyle(TL.paperMuted)
            if multiline {
                TextEditor(text: text)
                    .font(.subheadline)
                    .foregroundStyle(TL.paperInk)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 110)
            } else {
                TextField("", text: text)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(TL.paperInk)
            }
        }
    }

    private func numberField(_ title: String, unit: String, text: Binding<String>) -> some View {
        HStack {
            Text(title).font(.footnote).foregroundStyle(TL.fg2)
            Spacer()
            TextField("—", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.subheadline.weight(.semibold))
                .numeric()
                .frame(width: 64)
            Text(unit).font(.caption).foregroundStyle(TL.fg3).frame(width: 28, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .plate(TL.surface)
    }
}
