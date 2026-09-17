//
//  HomeView.swift
//  truelable
//
//  A landing page, not a feed: it fits on one screen, so there is nothing
//  to drag. Trends live under You, popular products live in Search — both
//  were duplicated here and both are what made this page overflow.
//
//  What changed in the redesign: the page used to arrive all at once, with
//  only the header and headline animating and everything below simply being
//  there. Now it assembles, the rail snaps, tapping a product grows it out
//  of the card that was tapped, and the counts roll when they change. None
//  of that is decoration — each one answers "what just happened?".
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(AppRouter.self) private var router
    @Query(sort: \ScanRecord.scannedAt, order: .reverse) private var records: [ScanRecord]
    @AppStorage(Keys.verifiedCount) private var verifiedCount = 0
    @AppStorage(Keys.dietary) private var dietaryRaw = ""
    @State private var queueCount = 0
    @State private var trending: [ProductCard] = []
    @State private var loadingTrending = true
    @Namespace private var hero
    private let plus = Plus.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header.appear(0)
                    headline.appear(1)
                    searchBar.appear(2)
                    stats.appear(3)
                    if !records.isEmpty { recents.appear(4).settleOnScroll() }
                    popular.appear(5).settleOnScroll()
                    if !plus.isActive { PlusBanner().appear(6).settleOnScroll() }
                    nudge.settleOnScroll()
                }
                .padding(.horizontal, TL.gutter)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: String.self) { barcode in
                ProductLoaderScreen(barcode: barcode, initial: records.first { $0.barcode == barcode }?.product)
                    .zoomDestination(barcode, in: hero)
            }
            .task {
                async let queue = API.needsVerification(limit: 12)
                async let popular = API.trending(limit: 6)
                queueCount = (try? await queue.count) ?? 0
                let found = (try? await popular) ?? []
                withAnimation(.tlSettle) {
                    trending = found
                    loadingTrending = false
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("TrueLabel")
                .font(.headline)
            Spacer()
            Pill(text: API.country, color: TL.fg2, icon: "globe")
        }
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: greeting)
            Text("What's really\nin it?")
                .font(.displayL)
                .tracking(-0.8)
                .lineSpacing(-3)
            Text("Point at a barcode. Sugar in teaspoons, additives by name, and whether it fits how you eat.")
                .font(.subheadline)
                .foregroundStyle(TL.fg2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        case 17..<22: "Good evening"
        default: "Late night snack?"
        }
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Button {
                router.sheet = .search
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(TL.fg2)
                    Text("Search a product or brand")
                        .font(.subheadline)
                        .foregroundStyle(TL.fg3)
                    Spacer(minLength: 0)
                }
                .engraved()
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .glassEffect(.regular.interactive(), in: .capsule)
                .contentShape(Capsule())
            }
            .buttonStyle(.pressable)

            Button {
                router.sheet = .manualEntry
            } label: {
                Image(systemName: "keyboard")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(TL.fg2)
                    .engraved()
                    .frame(width: 54, height: 54)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .contentShape(Circle())
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Type a barcode")
        }
        .sensoryFeedback(.selection, trigger: router.sheet)
    }

    /// Was three separate tiles, which read as three unrelated widgets
    /// competing for the same row. One surface divided by hairlines reads as
    /// one fact about the user, which is what it is.
    private var stats: some View {
        HStack(spacing: 0) {
            stat("\(records.count)", "Products")
            statDivider
            stat("\(thisWeek)", "This week")
            statDivider
            stat("\(verifiedCount)", "Confirmed")
        }
        .card(.flat)
        .animation(.tlSettle, value: records.count)
        .animation(.tlSettle, value: verifiedCount)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.displayS)
                .numeric()
                // The count rolling is the only signal that a scan landed
                // while this screen was already open.
                .contentTransition(.numericText())
            Text(label)
                .font(.caption)
                .foregroundStyle(TL.fg3)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }

    private var statDivider: some View {
        Rectangle()
            .fill(TL.line)
            .frame(width: 1, height: 28)
    }

    private var thisWeek: Int {
        let start = Calendar.current.date(byAdding: .day, value: -6, to: Calendar.current.startOfDay(for: .now))!
        return records.filter { $0.scannedAt >= start }.count
    }

    private var recents: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "Recent")
                Button("See all") { router.tab = .history }
                    .font(.footnote.weight(.semibold))
            }
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(records.prefix(10)) { record in
                        NavigationLink(value: record.barcode) { RecentCard(record: record) }
                            .buttonStyle(.pressable)
                            .zoomSource(record.barcode, in: hero)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            // Cards line up under the finger instead of drifting to a stop
            // mid-card, which is the difference between a rail and a row
            // that happens to scroll.
            .scrollTargetBehavior(.viewAligned)
        }
    }

    @ViewBuilder
    private var popular: some View {
        if loadingTrending {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Popular in \(API.country)")
                VStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { index in
                        if index > 0 { Hairline() }
                        placeholderRow
                    }
                }
                .card()
                .loadingPulse()
            }
        } else if !trending.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionHeader(title: "Popular in \(API.country)")
                    Button("Search") { router.sheet = .search }
                        .font(.footnote.weight(.semibold))
                }
                VStack(spacing: 0) {
                    ForEach(Array(trending.prefix(4).enumerated()), id: \.element.id) { index, card in
                        if index > 0 { Hairline() }
                        NavigationLink(value: card.barcode) {
                            ProductCardRow(card: card)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.pressable)
                        .zoomSource(card.barcode, in: hero)
                    }
                }
                .card()
            }
        }
    }

    /// Shaped like the row it stands in for — a thumbnail, two lines of
    /// text, a grade — so the wait reads as this list arriving rather than
    /// as some other screen.
    private var placeholderRow: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(TL.line)
                .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 6) {
                Capsule().fill(TL.line).frame(width: 150, height: 11)
                Capsule().fill(TL.line).frame(width: 84, height: 9)
            }
            Spacer(minLength: 0)
            Circle().fill(TL.line).frame(width: 28, height: 28)
        }
        .padding(.vertical, 10)
        .accessibilityHidden(true)
    }

    /// One slot, first match wins — a stack of nudges is what pushed this
    /// page past a screen in the first place.
    @ViewBuilder
    private var nudge: some View {
        if DietaryPreference.decode(dietaryRaw).isEmpty {
            nudgeCard(icon: "slider.horizontal.3", tint: TL.info,
                      title: "Tell us what to watch for",
                      body: "Allergies, sugar, palm oil — flagged on every scan.") { router.tab = .you }
        } else if queueCount > 0 {
            nudgeCard(icon: "checkmark.seal.fill", tint: TL.accent,
                      title: "\(queueCount) labels need a second look",
                      body: "Takes seconds. Keeps the data honest.") { router.tab = .verify }
        }
    }

    private func nudgeCard(icon: String, tint: Color, title: String, body: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(tint)
                    .frame(width: 44, height: 44)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: TL.R.sm, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.weight(.semibold))
                    Text(body).font(.footnote).foregroundStyle(TL.fg2)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(TL.fg3)
            }
            .card(.flat)
        }
        .buttonStyle(.pressable)
    }
}

struct RecentCard: View {
    let record: ScanRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                ProductThumb(url: record.imageURL, size: 52, radius: 14)
                Spacer()
                GradeBadge(grade: record.nutriscoreGrade)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(record.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(minHeight: 36, alignment: .top)
                Text(record.brand.isEmpty ? record.scannedAt.formatted(.relative(presentation: .named)) : record.brand)
                    .font(.caption)
                    .foregroundStyle(TL.fg3)
                    .lineLimit(1)
            }
        }
        .frame(width: 144, alignment: .leading)
        .card(.flat)
    }
}

#Preview {
    HomeView()
        .environment(AppRouter())
        .modelContainer(for: ScanRecord.self, inMemory: true)
        .preferredColorScheme(.dark)
}
