import SceneKit

enum EarthBuilder {

    /// Earth's sidereal rotation period in seconds (~23h 56m 4s).
    static let siderealDay: TimeInterval = 86_164.1

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
        // Low self-illumination so the dark side isn't pure black but night lights dominate
        surfaceMaterial.selfIllumination.contents = UIColor(white: 0.05, alpha: 1.0)
        surfaceMaterial.specular.contents = UIColor(white: 0.4, alpha: 1.0)
        surfaceMaterial.shininess = 20
        surfaceMaterial.lightingModel = .phong

        // Night lights: emission shows on the dark side where diffuse contribution is low
        let earthNight = UIImage(contentsOfFile: Bundle.main.path(forResource: "earth_night", ofType: "jpg") ?? "")
        surfaceMaterial.emission.contents = earthNight
        surfaceMaterial.emission.intensity = 1.0

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

        // Rotation is driven by OrbitSceneController.update(for:) — no SCNAction here.

        return earth
    }

    /// Computes the Y-axis rotation angle (radians) for Earth's surface at the given date.
    /// Uses J2000 epoch as reference: at J2000 (2000-01-01T12:00:00 UTC) the prime meridian
    /// is at Greenwich Mean Sidereal Time ≈ 280.46°.
    static func rotationAngle(for date: Date) -> Float {
        let j2000 = Date(timeIntervalSince1970: 946_728_000) // 2000-01-01T12:00:00 UTC
        let elapsed = date.timeIntervalSince(j2000)
        let rotations = elapsed / siderealDay
        let gmst0 = 280.46 * .pi / 180.0 // GMST at J2000 in radians
        let angle = gmst0 + rotations * 2.0 * .pi
        return Float(angle)
    }
}
