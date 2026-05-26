import SwiftUI

extension View {
    /// Liquid Glass on iOS 26+, `.thickMaterial` fallback below.
    /// Use for floating controls (bar pills, rail buttons) where the system
    /// should treat the surface as a Glass material, not a background fill.
    @ViewBuilder
    func liquidGlass<S: Shape>(
        in shape: S,
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(makeGlass(tint: tint, interactive: interactive), in: shape)
        } else {
            self.background(.thickMaterial, in: shape)
        }
    }
}

@available(iOS 26.0, *)
private func makeGlass(tint: Color?, interactive: Bool) -> Glass {
    var glass: Glass = .regular
    if let tint { glass = glass.tint(tint) }
    if interactive { glass = glass.interactive() }
    return glass
}

/// Groups adjacent Liquid Glass surfaces so they morph together (iOS 26+).
/// Pre-iOS 26 this is a passthrough — the underlying material fallbacks
/// already render fine independently.
struct GlassCluster<Content: View>: View {
    var spacing: CGFloat
    @ViewBuilder var content: () -> Content

    init(spacing: CGFloat = 20, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content() }
        } else {
            content()
        }
    }
}
