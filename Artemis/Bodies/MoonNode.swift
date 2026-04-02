import SceneKit

enum MoonBuilder {

    static func build() -> SCNNode {
        let moon = SCNNode()
        moon.name = "Moon"

        let sphere = SCNSphere(radius: 0.273)
        sphere.segmentCount = 48

        let surfaceMaterial = SCNMaterial()
        surfaceMaterial.diffuse.contents = UIImage(contentsOfFile: Bundle.main.path(forResource: "moon_diffuse", ofType: "jpg") ?? "")
        surfaceMaterial.emission.contents = UIColor(white: 0.15, alpha: 1.0)
        surfaceMaterial.specular.contents = UIColor(white: 0.3, alpha: 1.0)
        surfaceMaterial.shininess = 10
        surfaceMaterial.lightingModel = .blinn
        sphere.materials = [surfaceMaterial]

        let surfaceNode = SCNNode(geometry: sphere)
        surfaceNode.name = "moonSurface"
        moon.addChildNode(surfaceNode)

        return moon
    }
}
