import SceneKit

enum EarthBuilder {

    static func build() -> SCNNode {
        let earth = SCNNode()
        earth.name = "Earth"

        // --- Surface sphere ---
        let sphere = SCNSphere(radius: 1.0)
        sphere.segmentCount = 96

        let surfaceMaterial = SCNMaterial()
        let earthDiffuse = UIImage(contentsOfFile: Bundle.main.path(forResource: "earth_diffuse", ofType: "jpg") ?? "")
        surfaceMaterial.diffuse.contents = earthDiffuse
        surfaceMaterial.diffuse.wrapS = .repeat
        surfaceMaterial.diffuse.wrapT = .repeat
        // Multiply tint to push ocean blues toward royal blue
        surfaceMaterial.multiply.contents = UIColor(red: 0.88, green: 0.88, blue: 1.0, alpha: 1.0)
        // Self-illumination keeps the whole globe bright; Phong adds subtle shading
        surfaceMaterial.selfIllumination.contents = earthDiffuse
        surfaceMaterial.selfIllumination.intensity = 0.85
        surfaceMaterial.specular.contents = UIColor(white: 0.4, alpha: 1.0)
        surfaceMaterial.shininess = 20
        surfaceMaterial.lightingModel = .phong
        sphere.materials = [surfaceMaterial]

        let surfaceNode = SCNNode(geometry: sphere)
        surfaceNode.name = "earthSurface"
        earth.addChildNode(surfaceNode)

        // --- Thin atmosphere rim ---
        let atmosphereSphere = SCNSphere(radius: 1.015)
        atmosphereSphere.segmentCount = 64

        let atmosphereMaterial = SCNMaterial()
        atmosphereMaterial.diffuse.contents = UIColor.clear
        atmosphereMaterial.emission.contents = UIColor(red: 0.3, green: 0.5, blue: 1.0, alpha: 1.0)
        atmosphereMaterial.emission.intensity = 0.15
        atmosphereMaterial.transparent.contents = UIColor(white: 1.0, alpha: 0.08)
        atmosphereMaterial.isDoubleSided = true
        atmosphereMaterial.blendMode = .add
        atmosphereMaterial.writesToDepthBuffer = false
        atmosphereSphere.materials = [atmosphereMaterial]

        let atmosphereNode = SCNNode(geometry: atmosphereSphere)
        atmosphereNode.name = "earthAtmosphere"
        earth.addChildNode(atmosphereNode)

        // --- Axial tilt ---
        earth.eulerAngles.z = Float(23.44 * .pi / 180.0)

        // --- Continuous rotation ---
        let rotationAction = SCNAction.repeatForever(
            SCNAction.rotateBy(x: 0, y: 2 * .pi, z: 0, duration: 86400 / 500)
        )
        surfaceNode.runAction(rotationAction, forKey: "earthRotation")

        return earth
    }
}
