//
//  InsightsView.swift
//  truelable
//

import SwiftUI

/// Real analytics computed from `ScanHistoryEntry` — the design mockup
/// this is built from shows specific example numbers ("Sugar ceiling
/// 71%"), which are placeholder demo content, not a real formula to copy.
/// This computes the same *shape* of insight (weekly scan volume, average
/// sugar/sodium against WHO/ICMR daily guidelines) from whatever the
/// device has actually scanned — empty and low-sample-size states are
/// handled honestly rather than padded out.
struct InsightsView: View {
    var entries: [ScanHistoryEntry]

    private let calendar = Calendar.current

    var body: some View {
        if entries.isEmpty {
            emptyState
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    weekChart
                    targetsCard
                }
                .padding(20)
            }
        }
    }

    // MARK: - Weekly volume

    private var weekDays: [(label: String, count: Int)] {
        let today = calendar.startOfDay(for: .now)
        return (0..<7).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!
            let count = entries.filter { calendar.isDate($0.scannedAt, inSameDayAs: day) }.count
            let label = day.formatted(.dateTime.weekday(.abbreviated))
            return (label, count)
        }
    }

    private var weekChart: some View {
        let maxCount = max(weekDays.map(\.count).max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: 14) {
            Text("THIS WEEK")
                .font(.system(.caption2, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.4))

            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(weekDays.enumerated()), id: \.offset) { _, day in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(day.count > 0 ? TLColor.accent : Color.white.opacity(0.1))
                            .frame(height: max(6, CGFloat(day.count) / CGFloat(maxCount) * 90))
                        Text(day.label.prefix(1))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 110, alignment: .bottom)

            Text("\(entries.count) scans total on this device")
                .font(.system(size: 12.5))
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding(20)
        .liquidGlassCard(cornerRadius: 24)
    }

    // MARK: - Targets

    private var averageSugar: Double? {
        let values = entries.compactMap(\.sugarGrams)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private var averageSodium: Double? {
        let values = entries.compactMap(\.sodiumMg)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private var targetsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AVERAGE PER SCAN, AGAINST DAILY GUIDELINES")
                .font(.system(.caption2, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(.white.opacity(0.4))

            if averageSugar == nil && averageSodium == nil {
                Text("Not enough nutrition data yet on what you've scanned to show this.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(.white.opacity(0.5))
            }

            if let sugar = averageSugar {
                gauge(label: "Sugar", value: sugar, guideline: 50, unit: "g", color: TLColor.warn)
            }
            if let sodium = averageSodium {
                gauge(label: "Sodium", value: sodium, guideline: 2000, unit: "mg", color: TLColor.danger)
            }

            Text("Guidelines: WHO free-sugar limit (50g/day), ICMR sodium ceiling (2,000mg/day). Per-scan average shown as a share of the daily figure, not a real daily total.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.35))
        }
        .padding(20)
        .liquidGlassCard(cornerRadius: 24)
    }

    private func gauge(label: String, value: Double, guideline: Double, unit: String, color: Color) -> some View {
        let pct = min(value / guideline, 1)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(.system(size: 13.5, weight: .medium))
                Spacer()
                Text("\(Int(pct * 100))% of \(Int(guideline))\(unit)/day")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.08))
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(color).frame(width: geo.size.width * pct)
                    }
            }
            .frame(height: 6)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(0.25))
            Text("Nothing scanned yet")
                .font(.system(size: 15, weight: .semibold))
            Text("Once you've scanned a few things, patterns show up here.")
                .font(.system(size: 13.5))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
