import SceneKit

final class EarthNode: SCNNode {

    // MARK: - Convenience Init

    convenience init(radius: CGFloat = 1.0) {
        self.init()
        name = "Earth"

        // --- Surface sphere ---
        let sphere = SCNSphere(radius: radius)
        sphere.segmentCount = 64

        let surfaceMaterial = SCNMaterial()
        surfaceMaterial.name = "earthSurface"
        surfaceMaterial.diffuse.contents = UIColor(red: 0.1, green: 0.3, blue: 0.6, alpha: 1.0)
        surfaceMaterial.specular.contents = UIColor.white
        surfaceMaterial.shininess = 25
        // Reserve material property names so textures can be swapped in later:
        // surfaceMaterial.diffuse.contents  = UIImage(named: "earth_diffuse")
        // surfaceMaterial.normal.contents   = UIImage(named: "earth_normal")
        // surfaceMaterial.specular.contents  = UIImage(named: "earth_specular")
        // surfaceMaterial.emission.contents  = UIImage(named: "earth_emission")
        sphere.materials = [surfaceMaterial]

        let surfaceNode = SCNNode(geometry: sphere)
        surfaceNode.name = "earthSurface"
        addChildNode(surfaceNode)

        // --- Atmosphere glow ---
        let atmosphereSphere = SCNSphere(radius: radius * 1.02)
        atmosphereSphere.segmentCount = 64

        let atmosphereMaterial = SCNMaterial()
        atmosphereMaterial.name = "earthAtmosphere"
        atmosphereMaterial.diffuse.contents = UIColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 0.15)
        atmosphereMaterial.emission.contents = UIColor.cyan
        atmosphereMaterial.isDoubleSided = true
        atmosphereMaterial.blendMode = .add
        atmosphereMaterial.writesToDepthBuffer = false
        atmosphereSphere.materials = [atmosphereMaterial]

        let atmosphereNode = SCNNode(geometry: atmosphereSphere)
        atmosphereNode.name = "earthAtmosphere"
        addChildNode(atmosphereNode)

        // --- Axial tilt: 23.44 degrees around the Z axis ---
        eulerAngles.z = Float(23.44 * .pi / 180.0)

        // --- Continuous rotation (sped up 500x for visibility) ---
        let rotationAction = SCNAction.repeatForever(
            SCNAction.rotateBy(x: 0, y: 2 * .pi, z: 0, duration: 86400 / 500)
        )
        surfaceNode.runAction(rotationAction, forKey: "earthRotation")
    }
}
