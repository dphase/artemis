import SwiftUI

/// Applies Liquid Glass on iOS 26+ (requires Swift 6.1 / Xcode 26 SDK to compile),
/// falls back to an ultra-thin material blur on older SDKs and OS versions.
struct GlassModifier<S: Shape>: ViewModifier {
    let shape: S
    var interactive: Bool = false

    func body(content: Content) -> some View {
#if compiler(>=6.1)
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
