import UIKit

enum StarfieldGenerator {

    /// Creates a starfield image, blending in a Milky Way panorama if available.
    static func generate(size: Int = 2048, starCount: Int = 80000) -> UIImage {
        let cgSize = CGSize(width: size, height: size)
        let renderer = UIGraphicsImageRenderer(size: cgSize)

        return renderer.image { context in
            let ctx = context.cgContext

            // Black background
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: cgSize))

            // --- Milky Way panorama overlay ---
            if let milkyWay = UIImage(named: "MilkyWay")?.cgImage {
                ctx.saveGState()
                // Flip vertically (CGContext draws upside down)
                ctx.translateBy(x: 0, y: cgSize.height)
                ctx.scaleBy(x: 1, y: -1)
                // Draw at reduced opacity via alpha layer for subtle blending
                ctx.setAlpha(0.7)
                ctx.setBlendMode(.plusLighter)
                ctx.draw(milkyWay, in: CGRect(origin: .zero, size: cgSize))
                ctx.restoreGState()
            }

            // --- Stars ---
            srand48(42)

            for _ in 0..<starCount {
                let x = CGFloat(drand48()) * cgSize.width
                let y = CGFloat(drand48()) * cgSize.height

                let brightness = CGFloat(0.5 + drand48() * 0.5)
                let alpha = CGFloat(0.4 + drand48() * 0.5)
                let radius = CGFloat(0.2 + drand48() * 0.4)

                UIColor(white: brightness, alpha: alpha).setFill()
                ctx.fillEllipse(in: CGRect(
                    x: x - radius,
                    y: y - radius,
                    width: radius * 2,
                    height: radius * 2
                ))
            }
        }
    }
}
