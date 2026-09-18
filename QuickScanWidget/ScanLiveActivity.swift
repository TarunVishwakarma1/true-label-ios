import ActivityKit
import SwiftUI
import WidgetKit

private enum ActivityTL {
    static let bg = Color(red: 0x0C / 255, green: 0x0B / 255, blue: 0x0A / 255)
    static let fg = Color(red: 0xF3 / 255, green: 0xEF / 255, blue: 0xE7 / 255)
    static let fg2 = Color(red: 0xB8 / 255, green: 0xB1 / 255, blue: 0xA6 / 255)
    static let fg3 = Color(red: 0x8A / 255, green: 0x83 / 255, blue: 0x7A / 255)
    static let accent = Color(red: 0xEF / 255, green: 0xE6 / 255, blue: 0xD4 / 255)

    static let good = Color(red: 0x4F / 255, green: 0xBF / 255, blue: 0x73 / 255)
    static let fair = Color(red: 0xA3 / 255, green: 0xC6 / 255, blue: 0x3F / 255)
    static let warn = Color(red: 0xE9 / 255, green: 0xB2 / 255, blue: 0x3C / 255)
    static let poor = Color(red: 0xE6 / 255, green: 0x8A / 255, blue: 0x3C / 255)
    static let danger = Color(red: 0xE0 / 255, green: 0x5B / 255, blue: 0x47 / 255)

    static func grade(_ letter: String?) -> Color {
        switch letter?.lowercased() {
        case "a": good
        case "b": fair
        case "c": warn
        case "d": poor
        case "e": danger
        default: fg3
        }
    }
}

private struct GradeMark: View {
    var grade: String?
    var size: CGFloat = 22

    var body: some View {
        let tint = ActivityTL.grade(grade)
        Text(grade?.uppercased() ?? "?")
            .font(.system(size: size * 0.6, weight: .bold, design: .serif))
            .foregroundStyle(ActivityTL.bg)
            .frame(width: size, height: size)
            .background(tint, in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
            .accessibilityLabel(grade.map { "Nutri-Score \($0.uppercased())" } ?? "No grade")
    }
}

private struct ConcernMark: View {
    var concerns: Int
    var compact = false

    var body: some View {
        let clear = concerns == 0
        HStack(spacing: 3) {
            Image(systemName: clear ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: compact ? 12 : 13, weight: .semibold))
            if !clear {
                Text("\(concerns)")
                    .font(.system(size: compact ? 12 : 13, weight: .semibold))
                    .monospacedDigit()
            }
        }
        .foregroundStyle(clear ? ActivityTL.good : ActivityTL.warn)
        .accessibilityLabel(clear ? "No concerns" : "\(concerns) concerns")
    }
}

struct ScanLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ScanActivityAttributes.self) { context in
            lockScreen(context.state)
                .activityBackgroundTint(ActivityTL.bg)
                .activitySystemActionForegroundColor(ActivityTL.accent)
        } dynamicIsland: { context in
            let state = context.state

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    GradeMark(grade: state.grade, size: 34)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ConcernMark(concerns: state.concerns)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(state.productName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(ActivityTL.fg)
                            .lineLimit(1)
                        if let brand = state.brand, !brand.isEmpty {
                            Text(brand)
                                .font(.system(size: 12))
                                .foregroundStyle(ActivityTL.fg3)
                                .lineLimit(1)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(state.headline)
                        .font(.system(size: 13))
                        .foregroundStyle(ActivityTL.fg2)
                        .lineLimit(1)
                        .padding(.top, 2)
                }
            } compactLeading: {
                GradeMark(grade: state.grade, size: 18)
            } compactTrailing: {
                ConcernMark(concerns: state.concerns, compact: true)
            } minimal: {
                GradeMark(grade: state.grade, size: 18)
            }

            .keylineTint(ActivityTL.grade(state.grade))
        }
    }

    private func lockScreen(_ state: ScanActivityAttributes.ContentState) -> some View {
        HStack(spacing: 14) {
            GradeMark(grade: state.grade, size: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(state.productName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ActivityTL.fg)
                    .lineLimit(1)
                if let brand = state.brand, !brand.isEmpty {
                    Text(brand)
                        .font(.system(size: 12))
                        .foregroundStyle(ActivityTL.fg3)
                        .lineLimit(1)
                }
                Text(state.headline)
                    .font(.system(size: 13))
                    .foregroundStyle(ActivityTL.fg2)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
            ConcernMark(concerns: state.concerns)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
