import SwiftUI
import UIKit

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let down = configuration.isPressed
        return configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(TL.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(TL.accent, in: Capsule())
            .shadow(color: TL.shadow, radius: down ? 8 : 22, y: down ? 4 : 11)
            .scaleEffect(down ? 0.975 : 1)
            .animation(.tlSnap, value: down)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let down = configuration.isPressed
        return configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(TL.fg)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(TL.surface, in: Capsule())
            .overlay { Capsule().strokeBorder(TL.line, lineWidth: TL.border) }
            .scaleEffect(down ? 0.975 : 1)
            .animation(.tlSnap, value: down)
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let down = configuration.isPressed
        return configuration.label
            .scaleEffect(down ? 0.97 : 1)
            .opacity(down ? 0.88 : 1)
            .animation(.tlSnap, value: down)
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

struct IconButton: View {
    var systemImage: String
    var label: String
    var active: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.bold))
                .foregroundStyle(active ? TL.ink : TL.fg)
                .frame(width: 44, height: 44)
                .background(active ? TL.accent : TL.surface, in: Circle())
                .overlay { Circle().strokeBorder(TL.line, lineWidth: TL.border) }
                .shadow(color: TL.shadow, radius: 14, y: 6)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(label)
    }
}

struct Hairline: View {
    var body: some View {
        Rectangle().fill(TL.line).frame(height: 1)
    }
}

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
        .foregroundStyle(filled ? TL.ink : TL.fg2)
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(filled ? color : TL.elevated, in: Capsule())
        .overlay { if !filled { Capsule().strokeBorder(TL.line, lineWidth: TL.border) } }
    }
}

struct ScoreRing: View {
    var score: Int
    var color: Color
    var size: CGFloat = 88
    var lineWidth: CGFloat = 9

    @State private var shown = false

    var body: some View {
        ZStack {
            Circle().stroke(TL.track, lineWidth: lineWidth)
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
                    .background(on ? TL.grade(letter) : TL.track, in: RoundedRectangle(cornerRadius: TL.R.sm, style: .continuous))
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
            Capsule()
                .fill(TL.track)
                .overlay(alignment: .leading) {
                    Capsule()
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

struct ProductThumb: View {
    var url: URL?
    var size: CGFloat = 64
    var radius: CGFloat = TL.R.sm

    var body: some View {
        CachedAsyncImage(url: url) { image in
            if let image {
                image.resizable().scaledToFill()
                    .transition(.opacity)
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .background(TL.paper)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(TL.line, lineWidth: TL.border)
                .allowsHitTesting(false)
        }
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

struct CachedAsyncImage<Content: View>: View {
    let url: URL?
    @ViewBuilder var content: (Image?) -> Content
    @State private var image: Image?

    var body: some View {
        content(image)
            .animation(.tl(0.4), value: image)
            .task(id: url) {
                guard let url else { image = nil; return }
                if let uiImage = await ImageCache.shared.image(for: url) {
                    image = Image(uiImage: uiImage)
                } else {
                    image = nil
                }
            }
    }
}

actor ImageCache {
    static let shared = ImageCache()

    private let memory = NSCache<NSURL, UIImage>()
    private var inFlight: [URL: Task<UIImage?, Never>] = [:]
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache.shared

        config.timeoutIntervalForRequest = 8
        return URLSession(configuration: config)
    }()

    func image(for url: URL) async -> UIImage? {
        if let cached = memory.object(forKey: url as NSURL) { return cached }
        if let task = inFlight[url] { return await task.value }

        let request = URLRequest(url: url)
        let task = Task<UIImage?, Never> { [session] in
            if let cachedResponse = URLCache.shared.cachedResponse(for: request),
               let image = UIImage(data: cachedResponse.data) {
                return image
            }
            guard let (data, response) = try? await session.data(for: request),
                  let image = UIImage(data: data) else { return nil }
            URLCache.shared.storeCachedResponse(
                CachedURLResponse(response: response, data: data, storagePolicy: .allowed),
                for: request
            )
            return image
        }
        inFlight[url] = task
        let image = await task.value
        inFlight[url] = nil
        if let image { memory.setObject(image, forKey: url as NSURL) }
        return image
    }
}

struct Skeleton: View {
    var lines: Int = 3
    var height: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(0..<lines, id: \.self) { i in
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(TL.track)
                    .frame(width: i == lines - 1 ? 120 : nil, height: height)
            }
        }
        .phaseAnimator([0.5, 1.0]) { content, phase in
            content.opacity(phase)
        } animation: { _ in .easeInOut(duration: 0.8) }
    }
}

struct ProductCardRow: View {
    let card: ProductCard
    var trailing: String? = nil

    var body: some View {
        HStack(spacing: 14) {

            ProductThumb(url: card.imageURL, size: 64)
            VStack(alignment: .leading, spacing: 5) {
                Text(card.productName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 5) {
                    if let brand = card.brand {
                        Text(brand).lineLimit(1)
                    }
                    if card.verified {
                        if card.brand != nil { Text("·") }
                        Image(systemName: "checkmark.seal.fill")
                        Text("Verified")
                    }
                }
                .font(.caption)
                .foregroundStyle(card.verified ? TL.good : TL.fg3)
                .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 6) {
                GradeBadge(grade: card.nutriscoreGrade)
                if let trailing {
                    Text(trailing).font(.caption.weight(.semibold)).numeric().foregroundStyle(TL.good)
                }
            }
        }

        .padding(.vertical, 4)
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

struct Backdrop: View {
    var intensity: Double = 1

    var body: some View {

        RadialGradient(
            colors: [TL.fg.opacity(0.055 * intensity), .clear],
            center: UnitPoint(x: 0.5, y: -0.08),
            startRadius: 0,
            endRadius: 560
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
