//
//  Components.swift
//  truelable
//
//  The small shared vocabulary every screen is built from.
//

import SwiftUI

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(TL.ink)
            .engraved(0.6)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(TL.accentGradient, in: RoundedRectangle(cornerRadius: TL.R.md, style: .continuous))
            .shadow(color: .black.opacity(configuration.isPressed ? 0.2 : 0.45), radius: 16, y: 8)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.tl(0.25), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(TL.fg)
            .engraved()
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: TL.R.md, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.tl(0.25), value: configuration.isPressed)
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.tl(0.25), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { .init() }
}
extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { .init() }
}
extension ButtonStyle where Self == PressableStyle {
    static var pressable: PressableStyle { .init() }
}

/// Round glass icon button for chrome over camera/hero content.
struct IconButton: View {
    var systemImage: String
    var label: String
    var active: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(active ? TL.ink : TL.fg)
                .frame(width: 44, height: 44)
                .glassEffect(active ? .regular.tint(TL.accent).interactive() : .regular.interactive(), in: .circle)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(label)
    }
}

/// The one divider in the app. `Divider()` insets and tints itself
/// differently depending on what it sits inside.
struct Hairline: View {
    var body: some View {
        Rectangle().fill(TL.line).frame(height: 1)
    }
}

// MARK: - Text bits

struct SectionHeader: View {
    var title: String
    var detail: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.sectionTitle)
                .foregroundStyle(TL.fg)
            Spacer()
            if let detail {
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(TL.fg3)
            }
        }
    }
}

struct Eyebrow: View {
    var text: String
    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .tracking(1.4)
            .foregroundStyle(TL.fg3)
    }
}

struct Pill: View {
    var text: String
    var color: Color = TL.fg2
    var icon: String? = nil
    var filled: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            if let icon { Image(systemName: icon).font(.caption2.weight(.bold)) }
            Text(text).font(.caption.weight(.semibold))
        }
        .foregroundStyle(filled ? TL.ink : color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(filled ? color : color.opacity(0.18), in: Capsule())
    }
}

// MARK: - Data visuals

struct ScoreRing: View {
    var score: Int
    var color: Color
    var size: CGFloat = 88
    var lineWidth: CGFloat = 9

    @State private var shown = false

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.08), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: shown ? CGFloat(score) / 100 : 0)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.tl(0.9), value: shown)
            VStack(spacing: 0) {
                Text("\(score)")
                    .font(.display(size * 0.34))
                    .numeric()
                    .contentTransition(.numericText())
                Text("/100")
                    .font(.system(size: size * 0.11, weight: .semibold))
                    .foregroundStyle(TL.fg3)
            }
        }
        .frame(width: size, height: size)
        .onAppear { shown = true }
        .accessibilityElement()
        .accessibilityLabel("Score \(score) out of 100")
    }
}

/// A–E strip with the product's grade lit up. Letter + colour, never
/// colour alone.
struct GradeStrip: View {
    var grade: String?

    var body: some View {
        HStack(spacing: 4) {
            ForEach(["a", "b", "c", "d", "e"], id: \.self) { letter in
                let on = grade?.lowercased() == letter
                Text(letter.uppercased())
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(on ? TL.ink : TL.fg3)
                    .frame(width: on ? 34 : 26, height: 26)
                    .background(on ? TL.grade(letter) : Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: TL.R.sm, style: .continuous))
            }
        }
        .accessibilityElement()
        .accessibilityLabel(grade.map { "Nutri-Score \($0.uppercased())" } ?? "No Nutri-Score")
    }
}

struct BarMeter: View {
    var fraction: Double
    var color: Color
    var height: CGFloat = 6

    @State private var shown = false

    var body: some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: height / 2)
                .fill(Color.white.opacity(0.08))
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(color)
                        .frame(width: geo.size.width * (shown ? min(max(fraction, 0), 1) : 0))
                        .animation(.tl(0.8), value: shown)
                }
        }
        .frame(height: height)
        .onAppear { shown = true }
    }
}

struct StatTile: View {
    var value: String
    var label: String
    var icon: String
    var tint: Color = TL.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.displayM)
                .numeric()
                .contentTransition(.numericText())
            Text(label)
                .font(.caption)
                .foregroundStyle(TL.fg3)
        }
        .card(.flat)
    }
}

// MARK: - Product image

struct ProductThumb: View {
    var url: URL?
    var size: CGFloat = 64
    var radius: CGFloat = 16

    var body: some View {
        AsyncImage(url: url, transaction: Transaction(animation: .tl(0.4))) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
                    .transition(.opacity)
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .background(.white.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(.white.opacity(0.18)))
    }

    private var placeholder: some View {
        ZStack {
            TL.elevated
            Image(systemName: "barcode")
                .font(.system(size: size * 0.36, weight: .medium))
                .foregroundStyle(TL.fg3)
        }
    }
}

// MARK: - Loading

/// Pulsing placeholder rows — cheap (opacity only), no blur, no timeline.
struct Skeleton: View {
    var lines: Int = 3
    var height: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(0..<lines, id: \.self) { i in
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: i == lines - 1 ? 120 : nil, height: height)
            }
        }
        .phaseAnimator([0.5, 1.0]) { content, phase in
            content.opacity(phase)
        } animation: { _ in .easeInOut(duration: 0.8) }
    }
}

// MARK: - Product card row (search, trending, alternatives)

/// Horizontal row for lists.
struct ProductCardRow: View {
    let card: ProductCard
    var trailing: String? = nil

    var body: some View {
        HStack(spacing: 16) {
            ProductThumb(url: card.imageURL, size: 56, radius: 16)
            VStack(alignment: .leading, spacing: 4) {
                Text(card.productName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 8) {
                    if let brand = card.brand { Text(brand).lineLimit(1) }
                    if card.verified {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(TL.accent)
                    }
                }
                .font(.caption)
                .foregroundStyle(TL.fg3)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 8) {
                GradeBadge(grade: card.nutriscoreGrade)
                if let trailing {
                    Text(trailing).font(.caption.weight(.semibold)).numeric().foregroundStyle(TL.good)
                }
            }
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(TL.fg3)
        }
        .contentShape(Rectangle())
    }
}

struct GradeBadge: View {
    var grade: String?
    var size: CGFloat = 26

    var body: some View {
        if let letter = Nutriscore.letter(grade) {
            Text(letter.uppercased())
                .font(.system(size: size * 0.5, weight: .heavy))
                .foregroundStyle(TL.ink)
                .frame(width: size, height: size)
                .background(TL.grade(letter), in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
                .accessibilityLabel("Nutri-Score \(letter.uppercased())")
        }
    }
}

/// Small "Plus" tag for gated affordances.
struct PlusTag: View {
    var body: some View {
        Text("PLUS")
            .font(.system(size: 9, weight: .heavy))
            .tracking(1)
            .foregroundStyle(TL.ink)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(TL.plusGradient, in: Capsule())
    }
}

// MARK: - Brand

/// Static brand mark — a barcode with two accent bars.
struct BarcodeGlyph: View {
    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            ForEach(Array([4.0, 8, 3, 10, 3, 6, 3, 8].enumerated()), id: \.offset) { i, w in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i == 1 || i == 5 ? TL.accentDim : TL.fg)
                    .frame(width: w)
            }
        }
    }
}

/// Static mesh — free at runtime because nothing animates, and the only
/// thing the glass surfaces have to refract. Flat black behind glass just
/// looks like flat black.
struct Backdrop: View {
    var intensity: Double = 1

    var body: some View {
        MeshGradient(
            width: 3, height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.55, 0.45], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1]
            ],
            colors: [
                Color(hex: 0x0C0B0A), Color(hex: 0x191310), Color(hex: 0x2A1E12),
                Color(hex: 0x0C0B0A), Color(hex: 0x1C1611), Color(hex: 0x14101A),
                Color(hex: 0x1E1524), Color(hex: 0x0C0B0A), Color(hex: 0x0C0B0A)
            ]
        )
        .opacity(intensity)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}


/// A highlight that slides back and forth along a shape's border. Ported
/// from v1, where it marked the scan button as live. Rate-capped at 30fps —
/// a slow breathing highlight reads no better at native refresh, and this
/// one is on screen the whole time the app is.
struct AnimatedGradientBorder<S: InsettableShape>: View {
    var shape: S
    var lineWidth: CGFloat = 1.5
    var duration: Double = 2.5
    var isPaused: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: isPaused || reduceMotion)) { timeline in
            let raw = timeline.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: duration) / duration
            let progress = (1 - cos(.pi * 2 * raw)) / 2 // eased, seamless loop

            shape.strokeBorder(
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.06), location: 0),
                        .init(color: .white.opacity(0.7), location: progress),
                        .init(color: .white.opacity(0.06), location: 1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                lineWidth: lineWidth
            )
        }
        .allowsHitTesting(false)
    }
}
