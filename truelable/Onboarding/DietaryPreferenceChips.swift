//
//  DietaryPreferenceChips.swift
//  truelable
//

import SwiftUI

/// The wrapping chip grid shown in both onboarding's preferences step and
/// the Health screen — same options, same persisted state either way.
struct DietaryPreferenceChips: View {
    @State private var enabled: Set<DietaryPreference> = DietaryPreference.loadEnabled()

    var body: some View {
        FlowLayout(spacing: 9) {
            ForEach(DietaryPreference.allCases) { pref in
                chip(pref)
            }
        }
        .sensoryFeedback(.selection, trigger: enabled)
    }

    private func chip(_ pref: DietaryPreference) -> some View {
        let isOn = enabled.contains(pref)
        return Button {
            withAnimation(.easeOutExpo(duration: 0.25)) {
                if isOn { enabled.remove(pref) } else { enabled.insert(pref) }
                DietaryPreference.save(enabled)
            }
        } label: {
            Text(pref.rawValue)
                .font(.system(size: 14.5, weight: isOn ? .semibold : .regular))
                .foregroundStyle(isOn ? TLColor.accent : .white.opacity(0.78))
                .padding(.horizontal, 15)
                .padding(.vertical, 11)
                .background(
                    isOn
                        ? LinearGradient(colors: [TLColor.accent.opacity(0.3), TLColor.accent.opacity(0.1)], startPoint: .top, endPoint: .bottom)
                        : LinearGradient(colors: [Color.white.opacity(0.11), Color.white.opacity(0.035)], startPoint: .top, endPoint: .bottom)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(isOn ? TLColor.accent.opacity(0.5) : .white.opacity(0.15))
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        TLColor.bg.ignoresSafeArea()
        DietaryPreferenceChips().padding(24)
    }
}
