@preconcurrency import SceneKit

@MainActor
final class OrbitSceneController: ObservableObject {

    @Published private(set) var spacecraftDistanceFromEarth: Double = 0
    @Published private(set) var spacecraftDistanceFromMoon: Double = 0
    @Published private(set) var spacecraftVelocity: Double = 0
    @Published private(set) var cameraDebugString: String = ""

    /// Smoothed velocity to avoid frame-to-frame jitter from spline derivatives
    private var rawVelocityAccumulator: Double = 0
    private var velocitySampleCount: Int = 0
    private static let velocitySmoothingSamples = 8

    let scene: SCNScene
    let cameraNode: SCNNode
    private let initialCameraTransform: SCNMatrix4
    weak var scnView: SCNView?

    private let earthNode: SCNNode
    private let moonNode: SCNNode
    private let spacecraftNode: SCNNode
    private let trajectoryPath: TrajectoryPathNode
    private let starfieldNode: SCNNode
    private let earthSurfaceNode: SCNNode

    /// Nominal Moon orbital radius for orbit path rendering
    private static let moonOrbitRadius: Float = 63.0
    /// Effective period near apogee (Kepler: T_eff = T_sid * (r_apo/r_mean)^2 ≈ 30.3 days).
    /// The Moon is near apogee (Apr 7) for the entire Artemis II window, so it moves ~10% slower.
    private static let lunarPeriod: TimeInterval = 29.78 * 86400

    /// JPL Horizons Earth-Moon distances (ER) during Artemis II mission, one per day from launch.
    /// Source: NASA/JPL Horizons API, target=301, center=500@399
    private static let moonDistancesER: [(daysSinceLaunch: Double, radiusER: Float)] = [
        (0, 61.21),   // Apr 1 — launch
        (1, 61.77),   // Apr 2
        (2, 62.27),   // Apr 3
        (3, 62.73),   // Apr 4
        (4, 63.11),   // Apr 5
        (5, 63.39),   // Apr 6 — flyby
        (6, 63.54),   // Apr 7 — apogee
        (7, 63.51),   // Apr 8
        (8, 63.31),   // Apr 9
        (9, 62.96),   // Apr 10 — splashdown
    ]

    /// Interpolates the Moon's distance from Earth (in ER) for a given date.
    private static func moonRadius(for date: Date) -> Float {
        let daysSinceLaunch = date.timeIntervalSince(MissionTimeline.launchDate) / 86400.0
        let table = moonDistancesER

        // Clamp to table range
        if daysSinceLaunch <= table.first!.daysSinceLaunch { return table.first!.radiusER }
        if daysSinceLaunch >= table.last!.daysSinceLaunch { return table.last!.radiusER }

        // Linear interpolation between entries
        for i in 0..<(table.count - 1) {
            if daysSinceLaunch >= table[i].daysSinceLaunch && daysSinceLaunch < table[i + 1].daysSinceLaunch {
                let t = Float((daysSinceLaunch - table[i].daysSinceLaunch) /
                              (table[i + 1].daysSinceLaunch - table[i].daysSinceLaunch))
                return table[i].radiusER + t * (table[i + 1].radiusER - table[i].radiusER)
            }
        }
        return table.last!.radiusER
    }

    /// Computes the Moon's scene position for a given date.
    /// The Moon orbits counter-clockwise and is at (0, -R, ~0) at flyby midpoint.
    /// Flyby occurs ~5.02 days after launch based on NASA OEM tracking data.
    private static func moonScenePosition(for date: Date) -> SCNVector3 {
        let flybyMidpoint = MissionTimeline.launchDate.addingTimeInterval(5.02 * 86400)
        let elapsed = date.timeIntervalSince(flybyMidpoint)
        let angle = Float(2 * .pi * elapsed / lunarPeriod)

        let R = moonRadius(for: date)
        let x = R * sin(angle)
        let y = -R * cos(angle)
        let z: Float = 1.5 * cos(angle)
        return SCNVector3(x, y, z)
    }

    init() {
        let s = SCNScene()
        s.background.contents = UIColor.black

        // --- Starfield on a large sphere (so we can rotate it) ---
        let starSphere = SCNSphere(radius: 400)
        starSphere.segmentCount = 48
        let starMaterial = SCNMaterial()
        starMaterial.diffuse.contents = StarfieldGenerator.generate()
        starMaterial.isDoubleSided = true
        starMaterial.lightingModel = .constant
        starSphere.materials = [starMaterial]
        let starNode = SCNNode(geometry: starSphere)
        starNode.name = "starfield"
        s.rootNode.addChildNode(starNode)

        // --- Camera (fixed, HDR with bloom for Sun glow) ---
        let cam = SCNCamera()
        cam.zFar = 1000
        cam.zNear = 0.1
        cam.fieldOfView = 60
        cam.wantsHDR = true
        cam.bloomIntensity = 1.0
        cam.bloomThreshold = 0.8
        cam.bloomBlurRadius = 50.0
        cam.wantsExposureAdaptation = false
        cam.exposureOffset = 0

        let camNode = SCNNode()
        camNode.camera = cam
        camNode.position = SCNVector3(-0.6, -74.0, 12.3)
        camNode.eulerAngles = SCNVector3(0.99, -0.05, 0.0)
        s.rootNode.addChildNode(camNode)

        // --- Lighting ---
        let sunLight = SCNLight()
        sunLight.type = .directional
        sunLight.color = UIColor(red: 1.0, green: 0.96, blue: 0.90, alpha: 1.0)
        sunLight.intensity = 2500
        let sunNode = SCNNode()
        sunNode.light = sunLight
        sunNode.position = SCNVector3(30, 20, 80)
        sunNode.look(at: SCNVector3Zero)
        s.rootNode.addChildNode(sunNode)

        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 200
        ambientLight.color = UIColor(white: 0.5, alpha: 1.0)
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        s.rootNode.addChildNode(ambientNode)

        // --- Visible Sun (HDR bloom + thin diffraction spikes) ---
        let sunVisual = SCNNode()
        sunVisual.position = SCNVector3(30, 20, 80)

        // White-hot core
        let sunSphere = SCNSphere(radius: 1.0)
        sunSphere.segmentCount = 24
        let sunMat = SCNMaterial()
        sunMat.diffuse.contents = UIColor.white
        sunMat.emission.contents = UIColor(red: 1.0, green: 0.65, blue: 0.25, alpha: 1.0)
        sunMat.emission.intensity = 10.0
        sunMat.lightingModel = .constant
        sunMat.writesToDepthBuffer = false
        sunSphere.materials = [sunMat]
        let sunCore = SCNNode(geometry: sunSphere)
        sunVisual.addChildNode(sunCore)

        // Soft glow billboard — single texture with natural, organic rays baked in
        let glowTexture = Self.generateSunGlow(size: 512)
        let glowPlane = SCNPlane(width: 30, height: 30)
        let glowMat = SCNMaterial()
        glowMat.diffuse.contents = glowTexture
        glowMat.emission.contents = glowTexture
        glowMat.emission.intensity = 1.2
        glowMat.lightingModel = .constant
        glowMat.blendMode = .add
        glowMat.writesToDepthBuffer = false
        glowMat.readsFromDepthBuffer = false
        glowMat.isDoubleSided = true
        glowPlane.materials = [glowMat]
        let glowNode = SCNNode(geometry: glowPlane)
        let bb = SCNBillboardConstraint()
        bb.freeAxes = []
        glowNode.constraints = [bb]
        sunVisual.addChildNode(glowNode)

        s.rootNode.addChildNode(sunVisual)

        // --- Earth at origin (upper center of screen) ---
        let earth = EarthBuilder.build()
        earth.position = SCNVector3Zero
        s.rootNode.addChildNode(earth)

        let earthSurface = earth.childNode(withName: "earthSurface", recursively: false)!

        // --- Moon (positioned dynamically in update) ---
        let moon = MoonBuilder.build()
        moon.position = SCNVector3(0, -63.5, 1.5)
        s.rootNode.addChildNode(moon)

        // --- Moon orbital path (thin dotted grey line) ---
        s.rootNode.addChildNode(Self.buildMoonOrbitPath())

        // --- Spacecraft ---
        let sc = SpacecraftBuilder.build()
        s.rootNode.addChildNode(sc)

        // --- Trajectory path (static figure-8) ---
        let tp = TrajectoryPathNode()
        s.rootNode.addChildNode(tp.node)

        // --- Debug axis indicator (uncomment to enable) ---
        // s.rootNode.addChildNode(Self.buildAxisIndicator())

        self.scene = s
        self.cameraNode = camNode
        self.initialCameraTransform = camNode.transform
        self.earthNode = earth
        self.earthSurfaceNode = earthSurface
        self.moonNode = moon
        self.spacecraftNode = sc
        self.trajectoryPath = tp
        self.starfieldNode = starNode
    }

    func resetCamera() {
        guard let view = scnView else { return }

        // allowsCameraControl uses its own pointOfView copy, so we must
        // animate that node back to our initial transform.
        guard let pov = view.pointOfView else { return }

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.8
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        pov.position = cameraNode.position
        pov.eulerAngles = cameraNode.eulerAngles
        pov.camera?.fieldOfView = cameraNode.camera?.fieldOfView ?? 60
        SCNTransaction.commit()
    }

    func update(for date: Date) {
        // Move spacecraft along the static trajectory
        let state = TrajectoryInterpolator.state(at: date)
        spacecraftNode.position = state.position

        // Update trajectory progress (past/future split)
        trajectoryPath.updateProgress(state.parameter)

        // Sync Earth rotation to the current date
        earthSurfaceNode.eulerAngles.y = EarthBuilder.rotationAngle(for: date)

        // Move Moon along its orbit
        let currentMoonPos = Self.moonScenePosition(for: date)
        moonNode.position = currentMoonPos

        // Telemetry (surface-to-surface, not center-to-center)
        let earthRadius: Double = 1.0       // 1 ER in scene units
        let moonRadius: Double = 0.273      // Moon radius in scene units (matches MoonBuilder)
        spacecraftDistanceFromEarth = max(0, Self.distance(from: state.position, to: SCNVector3Zero) - earthRadius)
        spacecraftDistanceFromMoon = max(0, Self.distance(from: state.position, to: currentMoonPos) - moonRadius)
        // Smooth velocity using rolling average to prevent jitter
        rawVelocityAccumulator += state.speed
        velocitySampleCount += 1
        if velocitySampleCount >= Self.velocitySmoothingSamples {
            spacecraftVelocity = rawVelocityAccumulator / Double(velocitySampleCount)
            rawVelocityAccumulator = 0
            velocitySampleCount = 0
        }

        // Slowly rotate starfield for visual effect
        let elapsed = date.timeIntervalSince(MissionTimeline.launchDate)
        let angle = Float(elapsed / 86400.0 * 0.15) // ~0.15 radians per day
        starfieldNode.eulerAngles = SCNVector3(0, angle, angle * 0.3)

        // Camera debug readout — read from the SCNView's actual pointOfView
        // (allowsCameraControl moves an internal copy, not our cameraNode)
        if let pov = scnView?.pointOfView?.presentation {
            let p = pov.worldPosition
            let e = pov.eulerAngles
            let front = pov.worldFront
            cameraDebugString = String(format: """
                CAM pos  X:%.1f Y:%.1f Z:%.1f
                CAM rot  X:%.2f Y:%.2f Z:%.2f
                lookAt   X:%.1f Y:%.1f Z:%.1f
                """,
                p.x, p.y, p.z,
                e.x, e.y, e.z,
                p.x + front.x * 33,
                p.y + front.y * 33,
                p.z + front.z * 33
            )
        }
    }

    // MARK: - Helpers

    /// Generates an organic sun glow texture with natural-looking irregular rays.
    private static func generateSunGlow(size: Int = 512) -> UIImage {
        let cgSize = CGSize(width: size, height: size)
        let renderer = UIGraphicsImageRenderer(size: cgSize)
        srand48(7)
        return renderer.image { context in
            let ctx = context.cgContext
            let center = CGFloat(size) / 2
            let maxR = center

            // Smooth radial glow
            let glowSteps = 100
            for i in (0..<glowSteps).reversed() {
                let frac = CGFloat(i) / CGFloat(glowSteps)
                let r = maxR * 0.45 * frac
                let a = pow(1.0 - frac, 3.0) * 0.3
                ctx.setFillColor(red: 1.0, green: 0.7 + 0.25 * (1.0 - frac),
                                 blue: 0.2 + 0.35 * (1.0 - frac), alpha: a)
                ctx.fillEllipse(in: CGRect(x: center - r, y: center - r,
                                           width: r * 2, height: r * 2))
            }

            ctx.saveGState()
            ctx.setBlendMode(.plusLighter)

            // Organic rays — many overlapping soft strokes at irregular angles
            let rayCount = 40
            for _ in 0..<rayCount {
                let angle = drand48() * 2.0 * .pi
                let length = maxR * CGFloat(0.25 + drand48() * 0.65)
                let width = CGFloat(1.5 + drand48() * 3.0)
                let brightness = CGFloat(0.08 + drand48() * 0.15)

                let cosA = CGFloat(cos(angle))
                let sinA = CGFloat(sin(angle))

                // Draw ray as series of fading dots
                let steps = 40
                for s in 0..<steps {
                    let t = CGFloat(s) / CGFloat(steps)
                    let dist = length * t
                    let falloff = pow(1.0 - t, 2.5)
                    let w = width * (1.0 + 1.5 * (1.0 - t))
                    let a = falloff * brightness

                    guard a > 0.003 else { continue }

                    let px = center + dist * cosA
                    let py = center + dist * sinA

                    ctx.setFillColor(red: 1.0, green: 0.72 + 0.2 * (1.0 - t),
                                     blue: 0.25 + 0.2 * (1.0 - t), alpha: a)
                    ctx.fillEllipse(in: CGRect(x: px - w, y: py - w,
                                               width: w * 2, height: w * 2))
                }
            }

            // Bright center
            for i in (0..<30).reversed() {
                let frac = CGFloat(i) / 30.0
                let r = maxR * 0.035 * frac
                let a = pow(1.0 - frac, 2.0) * 0.8
                ctx.setFillColor(red: 1.0, green: 0.9 + 0.1 * (1.0 - frac),
                                 blue: 0.6 + 0.4 * (1.0 - frac), alpha: a)
                ctx.fillEllipse(in: CGRect(x: center - r, y: center - r,
                                           width: r * 2, height: r * 2))
            }

            ctx.restoreGState()
        }
    }

    private static func distance(from a: SCNVector3, to b: SCNVector3) -> Double {
        let dx = Double(a.x - b.x)
        let dy = Double(a.y - b.y)
        let dz = Double(a.z - b.z)
        return (dx * dx + dy * dy + dz * dz).squareRoot()
    }

    /// Builds a solid light grey circle showing the Moon's orbital path.
    /// Uses a thin SCNTube for visible thickness.
    private static func buildMoonOrbitPath() -> SCNNode {
        let R = moonOrbitRadius
        let totalPoints = 360

        var points: [SCNVector3] = []
        points.reserveCapacity(totalPoints + 1)
        for i in 0...totalPoints {
            let angle = Float(i) / Float(totalPoints) * 2 * .pi
            let x = R * sin(angle)
            let y = -R * cos(angle)
            let z: Float = 1.5 * cos(angle)
            points.append(SCNVector3(x, y, z))
        }

        // Solid line — connect every consecutive point
        var indices: [UInt32] = []
        indices.reserveCapacity(totalPoints * 2)
        for i in 0..<totalPoints {
            indices.append(UInt32(i))
            indices.append(UInt32(i + 1))
        }

        let source = SCNGeometrySource(vertices: points)
        let element = SCNGeometryElement(indices: indices, primitiveType: .line)
        let geometry = SCNGeometry(sources: [source], elements: [element])

        let material = SCNMaterial()
        material.diffuse.contents = UIColor(white: 0.81, alpha: 0.52)
        material.lightingModel = .constant
        geometry.materials = [material]

        let node = SCNNode(geometry: geometry)
        node.name = "moonOrbit"
        return node
    }

    /// Builds RGB axis lines at the scene origin for debugging camera orientation.
    /// Red = +X, Green = +Y, Blue = +Z. Each line is 10 units long with a label.
    private static func buildAxisIndicator() -> SCNNode {
        let root = SCNNode()
        root.name = "axisIndicator"

        let length: Float = 10.0

        let axes: [(name: String, dir: SIMD3<Float>, color: UIColor)] = [
            ("X", SIMD3(length, 0, 0), .systemRed),
            ("Y", SIMD3(0, length, 0), .systemGreen),
            ("Z", SIMD3(0, 0, length), .systemBlue),
        ]

        for axis in axes {
            // Line geometry
            let vertices: [SCNVector3] = [
                SCNVector3(0, 0, 0),
                SCNVector3(axis.dir.x, axis.dir.y, axis.dir.z)
            ]
            let source = SCNGeometrySource(vertices: vertices)
            let indices: [UInt16] = [0, 1]
            let element = SCNGeometryElement(
                indices: indices, primitiveType: .line
            )
            let lineGeo = SCNGeometry(sources: [source], elements: [element])
            let mat = SCNMaterial()
            mat.diffuse.contents = axis.color
            mat.lightingModel = .constant
            lineGeo.materials = [mat]

            let lineNode = SCNNode(geometry: lineGeo)
            root.addChildNode(lineNode)

            // Label at the end of the axis
            let text = SCNText(string: axis.name, extrusionDepth: 0)
            text.font = .systemFont(ofSize: 1.0)
            let textMat = SCNMaterial()
            textMat.diffuse.contents = axis.color
            textMat.lightingModel = .constant
            text.materials = [textMat]

            let textNode = SCNNode(geometry: text)
            textNode.position = SCNVector3(axis.dir.x, axis.dir.y, axis.dir.z)
            textNode.scale = SCNVector3(0.5, 0.5, 0.5)
            // Billboard constraint so labels always face the camera
            textNode.constraints = [SCNBillboardConstraint()]
            root.addChildNode(textNode)
        }

        return root
    }
}
