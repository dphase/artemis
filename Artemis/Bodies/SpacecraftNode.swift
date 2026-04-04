import SceneKit

enum SpacecraftBuilder {

    static func build() -> SCNNode {
        let spacecraft = SCNNode()
        spacecraft.name = "Spacecraft"

        let teal = UIColor(red: 0.0, green: 0.9, blue: 0.85, alpha: 1.0)

        // --- Core dot (3D shaded sphere) ---
        let coreSphere = SCNSphere(radius: 0.12)
        coreSphere.segmentCount = 24

        let purple = UIColor(red: 0.9, green: 0.2, blue: 0.6, alpha: 1.0)
        let coreMaterial = SCNMaterial()
        coreMaterial.diffuse.contents = purple
        coreMaterial.emission.contents = UIColor(red: 0.45, green: 0.1, blue: 0.3, alpha: 1.0)
        coreMaterial.specular.contents = UIColor(white: 0.8, alpha: 1.0)
        coreMaterial.shininess = 30
        coreMaterial.lightingModel = .blinn
        coreSphere.materials = [coreMaterial]

        let coreNode = SCNNode(geometry: coreSphere)
        coreNode.name = "spacecraftCore"
        spacecraft.addChildNode(coreNode)

        // --- Concentric ring pulses ---
        for i in 0..<4 {
            let ringNode = makeRing(index: i, color: teal)
            spacecraft.addChildNode(ringNode)
        }

        return spacecraft
    }

    private static func makeRing(index: Int, color: UIColor) -> SCNNode {
        let torus = SCNTorus(ringRadius: 0.4, pipeRadius: 0.015)
        torus.ringSegmentCount = 48
        torus.pipeSegmentCount = 8

        let material = SCNMaterial()
        material.diffuse.contents = color.withAlphaComponent(0.85)
        material.emission.contents = color.withAlphaComponent(0.85)
        material.lightingModel = .constant
        material.blendMode = .add
        material.writesToDepthBuffer = false
        torus.materials = [material]

        let node = SCNNode(geometry: torus)
        node.name = "ring\(index)"
        // Rotate torus to face camera (lay flat in XY plane)
        node.eulerAngles.x = .pi / 2

        // Staggered pulse animation (slow, gentle ripple)
        let delay = Double(index) * 1.8
        let expandAndFade = SCNAction.group([
            SCNAction.scale(to: 4.0, duration: 5.5),
            SCNAction.fadeOut(duration: 5.5)
        ])
        let reset = SCNAction.group([
            SCNAction.scale(to: 0.8, duration: 0),
            SCNAction.fadeIn(duration: 0)
        ])
        let pulse = SCNAction.sequence([
            SCNAction.wait(duration: delay),
            SCNAction.repeatForever(SCNAction.sequence([expandAndFade, reset]))
        ])
        node.runAction(pulse, forKey: "ringPulse\(index)")

        return node
    }
}
