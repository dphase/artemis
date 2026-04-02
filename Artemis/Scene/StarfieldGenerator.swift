import UIKit

enum StarfieldGenerator {

    /// Creates a dense, subtle starfield image.
    static func generate(size: Int = 2048, starCount: Int = 80000) -> UIImage {
        let cgSize = CGSize(width: size, height: size)
        let renderer = UIGraphicsImageRenderer(size: cgSize)

        return renderer.image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: cgSize))

            srand48(42)

            for _ in 0..<starCount {
                let x = CGFloat(drand48()) * cgSize.width
                let y = CGFloat(drand48()) * cgSize.height
                let brightness = CGFloat(0.5 + drand48() * 0.5)
                let alpha = CGFloat(0.4 + drand48() * 0.5)
                let radius = CGFloat(0.2 + drand48() * 0.4)

                let color = UIColor(white: brightness, alpha: alpha)
                color.setFill()

                let starRect = CGRect(
                    x: x - radius,
                    y: y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                context.cgContext.fillEllipse(in: starRect)
            }
        }
    }
}
