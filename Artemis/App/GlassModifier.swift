import SwiftUI

/// Applies Liquid Glass on iOS 26+, falls back to an ultra-thin material blur on older versions.
struct GlassModifier<S: Shape>: ViewModifier {
    let shape: S
    var interactive: Bool = false

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            if interactive {
                content.glassEffect(.clear.interactive(), in: shape)
            } else {
                content.glassEffect(.clear, in: shape)
            }
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
        }
    }
}
