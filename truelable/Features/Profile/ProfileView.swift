//
//  ProfileView.swift
//  truelable
//
//  No account, so "You" is your preferences and your activity — all of it
//  real and all of it on this phone.
//

import SwiftUI
import SwiftData
import Charts

struct ProfileView: View {
    @Query private var records: [ScanRecord]
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @AppStorage(Keys.verifiedCount) private var verifiedCount = 0
    @AppStorage(Keys.dietary) private var dietaryRaw = ""
    @State private var confirmClear = false
    @State private var showingPlus = false
    @State private var trendWindow = 7
    @State private var stats: ContributionStats?
    private let plus = Plus.shared

    private var prefs: Set<DietaryPreference> { DietaryPreference.decode(dietaryRaw) }

    var body: some View {
        NavigationStack {
            ScrollView {
                GlassEffectContainer(spacing: 24) {
                    VStack(spacing: 24) {
                        // Above the fold gets the staged entrance; below it,
                        // settling on scroll takes over. Doing both to the
                        // same card just fights itself.
                        AccountCard().appear(0)
                        impact.appear(1)
                        if records.isEmpty {
                            scanPrompt.appear(2)
                        } else {
                            whatYouScan.settleOnScroll()
                            trends.settleOnScroll()
                        }
                        plusCard.settleOnScroll()
                        watchFor.settleOnScroll()
                        about.settleOnScroll()
                        data.settleOnScroll()
                    }
                }
                .padding(.horizontal, TL.gutter)
                .padding(.bottom, 32)
            }
            .screenBackground()
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .navigationTitle("You")
        }
        .task {
            await Account.shared.refresh()
            await Plus.shared.refresh()
            stats = try? await API.stats()
        }
        .confirmationDialog("Clear scan history?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear \(records.count) products", role: .destructive) {
                records.forEach(context.delete)
            }
        } message: {
            Text("This only removes the list on this phone. Community verifications you made stay counted.")
        }
    }

    // MARK: Trends

    private var windowDays: [(date: Date, count: Int)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        return (0..<trendWindow).reversed().map { offset in
            let day = cal.date(byAdding: .day, value: -offset, to: today)!
            return (day, records.filter { cal.isDate($0.scannedAt, inSameDayAs: day) }.count)
        }
    }

    private var windowRecords: [ScanRecord] {
        let start = Calendar.current.date(byAdding: .day, value: -(trendWindow - 1), to: Calendar.current.startOfDay(for: .now))!
        return records.filter { $0.scannedAt >= start }
    }

    private var trends: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                SectionHeader(title: "Your trends")
                Picker("Window", selection: $trendWindow) {
                    Text("7d").tag(7)
                    Text("30d").tag(30)
                    Text("90d").tag(90)
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
                .disabled(!plus.isActive)
            }
            if !plus.isActive {
                PlusGate(text: "30 and 90-day trends need Plus")
            }
            Chart(windowDays, id: \.date) { day in
                BarMark(x: .value("Day", day.date, unit: .day), y: .value("Products", day.count))
                    .foregroundStyle(day.count > 0 ? TL.accent : Color.white.opacity(0.1))
                    .cornerRadius(3)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: trendWindow == 7 ? 1 : trendWindow / 6)) { _ in
                    AxisValueLabel(format: trendWindow == 7 ? .dateTime.weekday(.narrow) : .dateTime.day(), centered: trendWindow == 7)
                        .foregroundStyle(TL.fg3)
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 96)
            .animation(.tlSettle, value: trendWindow)

            if let sugar = average(\.sugarGrams) {
                gauge("Avg. sugar per product", sugar, of: 50, unit: "g", color: TL.warn)
            }
            if let sodium = average(\.sodiumMg) {
                gauge("Avg. sodium per product", sodium, of: 2000, unit: "mg", color: TL.danger)
            }
            Text("Per-100 g averages of the last \(trendWindow) days against WHO free-sugar (50 g/day) and ICMR sodium (2,000 mg/day) guidelines.")
                .font(.caption2)
                .foregroundStyle(TL.fg3)
        }
        .card()
    }

    private func average(_ key: KeyPath<ScanRecord, Double?>) -> Double? {
        let values = windowRecords.compactMap { $0[keyPath: key] }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func gauge(_ label: String, _ value: Double, of guideline: Double, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label).font(.footnote.weight(.medium))
                Spacer()
                Text("\(value.compact) \(unit) · \(Int((value / guideline * 100).rounded()))% of daily")
                    .font(.caption)
                    .numeric()
                    .foregroundStyle(TL.fg3)
            }
            BarMeter(fraction: value / guideline, color: color)
        }
    }

    private var plusCard: some View {
        Group {
            if plus.isActive {
                Button { showingPlus = true } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.title3)
                            .foregroundStyle(TL.ink)
                            .frame(width: 44, height: 44)
                            .background(TL.plusGradient, in: RoundedRectangle(cornerRadius: TL.R.sm, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("TrueLabel Plus is on").font(.subheadline.weight(.semibold))
                            Text("Trends, four-way compare, ranked swaps. Tap to manage.").font(.footnote).foregroundStyle(TL.fg2)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(TL.fg3)
                    }
                    .card(.flat, fill: TL.elevated)
                }
                .buttonStyle(.pressable)
                .sheet(isPresented: $showingPlus) { PlusView() }
            } else {
                PlusBanner()
            }
        }
    }

    private var impact: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Your part in it")
            HStack(spacing: 12) {
                StatTile(value: "\(records.count)", label: "Looked up", icon: "barcode")
                StatTile(value: "\(stats?.confirmations ?? verifiedCount)",
                         label: "Confirmed", icon: "checkmark.seal.fill", tint: TL.info)
                StatTile(value: "\(stats?.contributions ?? 0)", label: "Added", icon: "plus.viewfinder", tint: TL.warn)
            }
            if let stats, stats.helpedVerify > 0 {
                Text("\(stats.helpedVerify) of the products you confirmed are now verified for everyone.")
                    .font(.footnote)
                    .foregroundStyle(TL.good)
            } else {
                Text("Looking things up is private and stays on this phone. Confirming and adding are the parts that help everyone else.")
                    .font(.footnote)
                    .foregroundStyle(TL.fg2)
            }
        }
    }

    /// With no history there is no distribution and no trend, which used to
    /// leave a gap between "your part in it" and the Plus card. Say what
    /// would be here instead of showing nothing.
    private var scanPrompt: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Your trends")
            Text("Once you've scanned a few products this fills in — what you buy by grade, and how your sugar and sodium track against the daily guidelines.")
                .font(.footnote)
                .foregroundStyle(TL.fg2)
            Button("Scan something") { router.scannerPresented = true }
                .buttonStyle(.secondary)
                .padding(.top, 2)
        }
        .card()
    }

    // MARK: What you scan

    private var graded: [(letter: String, count: Int)] {
        Nutriscore.letters.map { letter in
            (letter, records.filter { $0.nutriscoreGrade == letter }.count)
        }
    }

    private var gradedTotal: Int { graded.reduce(0) { $0 + $1.count } }

    /// The shape of what someone actually buys, which is more use than an
    /// average, and needs nothing from the server.
    @ViewBuilder
    private var whatYouScan: some View {
        if gradedTotal > 0 {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "What you scan", detail: "\(gradedTotal) graded")

                // Proportional, so the bar is the distribution rather than a
                // row of equal blocks. layoutPriority orders who gets space,
                // it does not divide it.
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        ForEach(graded, id: \.letter) { entry in
                            if entry.count > 0 {
                                Rectangle()
                                    .fill(TL.grade(entry.letter))
                                    .frame(width: geo.size.width * CGFloat(entry.count) / CGFloat(gradedTotal))
                            }
                        }
                    }
                }
                .frame(height: 10)
                .clipShape(Capsule())
                .accessibilityElement()
                .accessibilityLabel(gradeSummary)

                HStack(spacing: 0) {
                    ForEach(graded, id: \.letter) { entry in
                        VStack(spacing: 4) {
                            Text(entry.letter.uppercased())
                                .font(.caption2.weight(.heavy))
                                .foregroundStyle(entry.count > 0 ? TL.grade(entry.letter) : TL.fg3)
                            Text("\(entry.count)")
                                .font(.footnote.weight(.semibold))
                                .numeric()
                                .foregroundStyle(entry.count > 0 ? TL.fg : TL.fg3)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                Text(gradeSummary)
                    .font(.footnote)
                    .foregroundStyle(TL.fg2)
            }
            .card()
        }
    }

    private var gradeSummary: String {
        guard let top = graded.max(by: { $0.count < $1.count }), top.count > 0 else { return "" }
        let poor = graded.filter { ["d", "e"].contains($0.letter) }.reduce(0) { $0 + $1.count }
        let lead = "Mostly \(top.letter.uppercased())."
        guard poor > 0 else { return lead + " Nothing you scan scores D or E." }
        return lead + " \(poor) of \(gradedTotal) scored D or E."
    }

    private var watchFor: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Watch for", detail: prefs.isEmpty ? "Nothing yet" : "\(prefs.count) on")
            Text("Every scan checks these first and tells you plainly — including when the data can't say.")
                .font(.footnote)
                .foregroundStyle(TL.fg2)
            DietaryChips(raw: $dietaryRaw)
        }
        .card()
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "About")
                .padding(.bottom, 10)
            row("Region", value: API.country, icon: "globe")
            Hairline()
            row("Data", value: "Open Food Facts + community", icon: "tray.full")
            Hairline()
            Link(destination: URL(string: "https://github.com/TarunVishwakarma1/true-lable")!) {
                HStack {
                    Label("Source code · Apache-2.0", systemImage: "chevron.left.forwardslash.chevron.right")
                        .font(.subheadline)
                        .foregroundStyle(TL.fg)
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.caption.weight(.bold)).foregroundStyle(TL.fg3)
                }
                .padding(.vertical, 12)
            }
            Hairline()
            row("Version", value: version, icon: "app.badge")
        }
        .card()
    }

    private var data: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Your data")
            Text("Nothing here needs an account. History and preferences live on this phone only.")
                .font(.footnote)
                .foregroundStyle(TL.fg2)
            Button(role: .destructive) { confirmClear = true } label: {
                Label("Clear scan history", systemImage: "trash")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TL.danger)
            }
            .disabled(records.isEmpty)
            .opacity(records.isEmpty ? 0.5 : 1)
            .padding(.top, 4)
        }
        .card()
    }

    private func row(_ label: String, value: String, icon: String) -> some View {
        HStack {
            Label(label, systemImage: icon).font(.subheadline)
            Spacer()
            Text(value).font(.footnote).foregroundStyle(TL.fg3)
        }
        .padding(.vertical, 12)
    }

    private var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}

#Preview {
    ProfileView()
        .environment(AppRouter())
        .modelContainer(for: ScanRecord.self, inMemory: true)
        .preferredColorScheme(.dark)
}
