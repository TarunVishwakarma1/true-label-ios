//
//  ScaleButtonStyle.swift
//  truelable
//

import SwiftUI

/// Scales the button up slightly on press instead of the default dimmed look.
struct ScaleButtonStyle: ButtonStyle {
    var scale: CGFloat = 1.05

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
