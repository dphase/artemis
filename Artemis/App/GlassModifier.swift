import SwiftUI

/// Applies Liquid Glass on iOS 26+ when built with the iOS 26 SDK,
/// falls back to an ultra-thin material blur otherwise.
struct GlassModifier<S: Shape>: ViewModifier {
    let shape: S
    var interactive: Bool = false

    func body(content: Content) -> some View {
        // FoundationModels is iOS 26+ only — this guarantees the glassEffect
        // API exists in the SDK. Xcode 16 (iOS 18.x SDK) skips this block.
#if canImport(FoundationModels)
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
