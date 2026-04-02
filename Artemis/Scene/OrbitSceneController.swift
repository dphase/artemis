import SceneKit

final class OrbitSceneController: ObservableObject {

    @Published private(set) var spacecraftDistanceFromEarth: Double = 0
    @Published private(set) var spacecraftDistanceFromMoon: Double = 0
    @Published private(set) var spacecraftVelocity: Double = 0

    let scene: SCNScene
    let cameraNode: SCNNode

    private let earthNode: SCNNode
    private let moonNode: SCNNode
    private let spacecraftNode: SCNNode
    private let trajectoryPath: TrajectoryPathNode
    private let starfieldNode: SCNNode

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
        camNode.position = SCNVector3(0, 0, 75)
        camNode.look(at: SCNVector3(0, -33, 0))
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
        ambientLight.intensity = 1000
        ambientLight.color = UIColor(white: 0.7, alpha: 1.0)
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        s.rootNode.addChildNode(ambientNode)

        // --- Earth at origin (upper center of screen) ---
        let earth = EarthBuilder.build()
        earth.position = SCNVector3Zero
        s.rootNode.addChildNode(earth)

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

        self.scene = s
        self.cameraNode = camNode
        self.earthNode = earth
        self.moonNode = moon
        self.spacecraftNode = sc
        self.trajectoryPath = tp
        self.starfieldNode = starNode
    }

    func update(for date: Date) {
        // Move spacecraft along the static trajectory
        let state = TrajectoryInterpolator.state(at: date)
        spacecraftNode.position = state.position

        // Update trajectory progress (past/future split)
        trajectoryPath.updateProgress(state.parameter)

        // Telemetry
        spacecraftDistanceFromEarth = Self.distance(from: state.position, to: SCNVector3Zero)
        spacecraftDistanceFromMoon = Self.distance(from: state.position, to: fixedMoonPosition)
        spacecraftVelocity = state.speed

        // Slowly rotate starfield for visual effect
        let elapsed = date.timeIntervalSince(MissionTimeline.launchDate)
        let angle = Float(elapsed / 86400.0 * 0.15) // ~0.15 radians per day
        starfieldNode.eulerAngles = SCNVector3(0, angle, angle * 0.3)
    }

    private static func distance(from a: SCNVector3, to b: SCNVector3) -> Double {
        let dx = Double(a.x - b.x)
        let dy = Double(a.y - b.y)
        let dz = Double(a.z - b.z)
        return (dx * dx + dy * dy + dz * dz).squareRoot()
    }
}
