import SceneKit

final class MoonNode: SCNNode {

    // MARK: - Convenience Init

    convenience init(radius: CGFloat = 0.273) {
        self.init()
        name = "Moon"

        // --- Surface sphere ---
        let sphere = SCNSphere(radius: radius)
        sphere.segmentCount = 48

        let surfaceMaterial = SCNMaterial()
        surfaceMaterial.name = "moonSurface"
        surfaceMaterial.diffuse.contents = UIColor(white: 0.6, alpha: 1.0)
        // Reserve material property names so textures can be swapped in later:
        // surfaceMaterial.diffuse.contents = UIImage(named: "moon_diffuse")
        // surfaceMaterial.normal.contents  = UIImage(named: "moon_normal")
        sphere.materials = [surfaceMaterial]

        let surfaceNode = SCNNode(geometry: sphere)
        surfaceNode.name = "moonSurface"
        addChildNode(surfaceNode)

        // Tidally locked: no self-rotation action.
        // The parent scene controller manages orbital position so that
        // the same face always points toward Earth.
    }
}
