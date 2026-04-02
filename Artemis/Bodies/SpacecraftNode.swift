import SceneKit

final class SpacecraftNode: SCNNode {

    // MARK: - Convenience Init

    convenience init(radius: CGFloat = 0.15) {
        self.init()
        name = "Spacecraft"

        // --- Core dot ---
        let coreSphere = SCNSphere(radius: radius)
        coreSphere.segmentCount = 24

        let coreMaterial = SCNMaterial()
        coreMaterial.name = "spacecraftCore"
        coreMaterial.diffuse.contents = UIColor(red: 1.0, green: 0.85, blue: 0.5, alpha: 1.0)
        coreMaterial.emission.contents = UIColor.white
        coreSphere.materials = [coreMaterial]

        let coreNode = SCNNode(geometry: coreSphere)
        coreNode.name = "spacecraftCore"
        addChildNode(coreNode)

        // --- Outer glow ---
        let glowSphere = SCNSphere(radius: 0.5)
        glowSphere.segmentCount = 24

        let glowMaterial = SCNMaterial()
        glowMaterial.name = "spacecraftGlow"
        glowMaterial.diffuse.contents = UIColor(red: 1.0, green: 0.7, blue: 0.3, alpha: 0.25)
        glowMaterial.blendMode = .add
        glowMaterial.isDoubleSided = true
        glowMaterial.writesToDepthBuffer = false
        glowSphere.materials = [glowMaterial]

        let glowNode = SCNNode(geometry: glowSphere)
        glowNode.name = "spacecraftGlow"
        addChildNode(glowNode)

        // --- Pulsing animation ---
        let scaleUp = SCNAction.scale(to: 1.2, duration: 0.75)
        scaleUp.timingMode = .easeInEaseOut

        let scaleDown = SCNAction.scale(to: 0.8, duration: 0.75)
        scaleDown.timingMode = .easeInEaseOut

        let pulse = SCNAction.repeatForever(SCNAction.sequence([scaleUp, scaleDown]))
        glowNode.runAction(pulse, forKey: "glowPulse")
    }

    // MARK: - Public API

    func updatePosition(_ position: SCNVector3) {
        self.position = position
    }
}
