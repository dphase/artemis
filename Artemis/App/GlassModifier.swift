import SwiftUI

/// Applies Liquid Glass on iOS 26+ when built with the iOS 26 SDK,
/// falls back to an ultra-thin material blur otherwise.
struct GlassModifier<S: Shape>: ViewModifier {
    let shape: S
    var interactive: Bool = false

    func body(content: Content) -> some View {
#if canImport(Observation, _version: 1.3)
        // Observation 1.3 ships with iOS 26 SDK (Xcode 26) — use as SDK gate
        if #available(iOS 26, *) {
            if interactive {
                content.glassEffect(.clear.interactive(), in: shape)
            } else {
                content.glassEffect(.clear, in: shape)
            }
        } else {
            fallback(content)
        }
#else
        fallback(content)
#endif
    }

    private func fallback(_ content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: shape)
    }
}
