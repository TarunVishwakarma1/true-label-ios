//
//  NutritionLabelView.swift
//  truelable
//

import SwiftUI

/// Wraps content in the "physical label" surface — cream paper, torn top
/// edge — matching the website's `LabelCard` (`#f4efe2`) so the truth
/// printed on a real product label reads the same on both platforms. This
/// is chrome only; callers own their own content and its (dark-ink)
/// colors, the same way `ProductDetailView`'s existing `cardBackground`
/// only owns the dark-card chrome, not what's drawn on it.
///
/// `namespace`/`geometryID` are optional — pass both to make this specific
/// card participate in the scan→verify→detail `matchedGeometryEffect`
/// continuity; omit them for a label rendered on its own.
struct NutritionLabelView<Content: View>: View {
    var namespace: Namespace.ID?
    var geometryID: String = "scannedLabel"
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TornEdge()
                .fill(TLColor.paper)
                .frame(height: 8)
            content
                .padding(20)
        }
        .background(TLColor.paper)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.black.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 20, y: 10)
        .modifier(OptionalMatchedGeometry(namespace: namespace, id: geometryID))
    }
}

/// A jagged perforation line, like tearing along a real label's edge — a
/// static `Shape`, drawn once, no animation cost.
private struct TornEdge: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let teeth = 20
        let step = rect.width / CGFloat(teeth)
        path.move(to: CGPoint(x: 0, y: rect.maxY))
        for i in 0...teeth {
            let x = CGFloat(i) * step
            let y = i.isMultiple(of: 2) ? rect.minY : rect.minY + rect.height * 0.5
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.addLine(to: CGPoint(x: rect.width, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// `.matchedGeometryEffect` doesn't have a built-in "skip if nil" form —
/// this lets call sites pass an optional namespace without an `if/else`
/// branch at every use site.
private struct OptionalMatchedGeometry: ViewModifier {
    var namespace: Namespace.ID?
    var id: String

    func body(content: Content) -> some View {
        if let namespace {
            content.matchedGeometryEffect(id: id, in: namespace)
        } else {
            content
        }
    }
}
