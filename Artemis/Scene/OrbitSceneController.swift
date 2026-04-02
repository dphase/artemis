import SceneKit

@MainActor
final class OrbitSceneController: ObservableObject {

    @Published private(set) var spacecraftDistanceFromEarth: Double = 0
    @Published private(set) var spacecraftDistanceFromMoon: Double = 0
    @Published private(set) var spacecraftVelocity: Double = 0
    @Published private(set) var cameraDebugString: String = ""

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

    /// Fixed Moon position in scene coordinates (matches trajectory target after rotation)
    private let fixedMoonPosition = SCNVector3(0, -58.5, 3)

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

        // --- Camera (fixed) ---
        let cam = SCNCamera()
        cam.zFar = 1000
        cam.zNear = 0.1
        cam.fieldOfView = 60

        let camNode = SCNNode()
        camNode.camera = cam
        camNode.position = SCNVector3(-0.7, -71.0, 24.1)
        camNode.eulerAngles = SCNVector3(0.83, -0.03, 0.0)
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

        // --- Earth at origin (upper center of screen) ---
        let earth = EarthBuilder.build()
        earth.position = SCNVector3Zero
        s.rootNode.addChildNode(earth)

        let earthSurface = earth.childNode(withName: "earthSurface", recursively: false)!

        // --- Moon at fixed position (lower center) ---
        let moon = MoonBuilder.build()
        moon.position = SCNVector3(0, -58.5, 3)
        s.rootNode.addChildNode(moon)

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

        // Telemetry
        spacecraftDistanceFromEarth = Self.distance(from: state.position, to: SCNVector3Zero)
        spacecraftDistanceFromMoon = Self.distance(from: state.position, to: fixedMoonPosition)
        spacecraftVelocity = state.speed

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

    private static func distance(from a: SCNVector3, to b: SCNVector3) -> Double {
        let dx = Double(a.x - b.x)
        let dy = Double(a.y - b.y)
        let dz = Double(a.z - b.z)
        return (dx * dx + dy * dy + dz * dz).squareRoot()
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
