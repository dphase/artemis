import SceneKit
import Combine

/// Central scene controller that owns the SCNScene and coordinates all 3D nodes
/// for the Artemis mission visualization.
///
/// Scene scale: 1 unit = 1 Earth radius (6,371 km).
/// Earth sits at the origin; all other bodies are positioned relative to it.
@MainActor
final class OrbitSceneController: ObservableObject {

    // MARK: - Published State

    @Published private(set) var spacecraftDistanceFromEarth: Double = 0
    @Published private(set) var spacecraftDistanceFromMoon: Double = 0
    @Published private(set) var spacecraftVelocity: Double = 0

    // MARK: - Scene Graph

    let scene: SCNScene
    let cameraNode: SCNNode

    private let earthNode: EarthNode
    private let moonNode: MoonNode
    private let spacecraftNode: SpacecraftNode
    private let trajectoryNode: TrajectoryNode

    // MARK: - Dependencies

    // TrajectoryInterpolator uses static methods — no instance needed

    // MARK: - Initialization

    init() {
        // --- Scene ---
        scene = SCNScene()
        scene.background.contents = UIColor.black

        // --- Camera ---
        let camera = SCNCamera()
        camera.zFar = 5000
        camera.wantsHDR = true

        cameraNode = SCNNode()
        cameraNode.name = "camera"
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 30, 80)
        cameraNode.look(at: SCNVector3Zero)
        scene.rootNode.addChildNode(cameraNode)

        // --- Lighting ---
        let sunLight = SCNLight()
        sunLight.type = .directional
        sunLight.color = UIColor(red: 1.0, green: 0.96, blue: 0.90, alpha: 1.0)
        sunLight.intensity = 1000

        let sunLightNode = SCNNode()
        sunLightNode.name = "sunLight"
        sunLightNode.light = sunLight
        sunLightNode.look(at: SCNVector3(1, 0.3, -0.5))
        scene.rootNode.addChildNode(sunLightNode)

        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 100 // 0.1 on the normalized scale
        ambientLight.color = UIColor.white

        let ambientLightNode = SCNNode()
        ambientLightNode.name = "ambientLight"
        ambientLightNode.light = ambientLight
        scene.rootNode.addChildNode(ambientLightNode)

        // --- Bodies ---
        earthNode = EarthNode()
        earthNode.position = SCNVector3Zero
        scene.rootNode.addChildNode(earthNode)

        moonNode = MoonNode()
        scene.rootNode.addChildNode(moonNode)

        spacecraftNode = SpacecraftNode()
        scene.rootNode.addChildNode(spacecraftNode)

        trajectoryNode = TrajectoryNode()
        scene.rootNode.addChildNode(trajectoryNode)
    }

    // MARK: - Update

    /// Advances the scene to the given mission date, updating all body positions
    /// and published telemetry values.
    func update(for date: Date) {
        // Spacecraft
        let state = TrajectoryInterpolator.state(at: date)
        spacecraftNode.position = state.position

        // Moon
        let moonPosition = EphemerisProvider.moonPosition(at: date)
        moonNode.position = moonPosition

        // Trajectory visualization (past / future split)
        trajectoryNode.updateProgress(state.parameter)

        // Telemetry
        spacecraftDistanceFromEarth = Self.distance(from: state.position, to: SCNVector3Zero)
        spacecraftDistanceFromMoon = Self.distance(from: state.position, to: moonPosition)
        spacecraftVelocity = state.speed
    }

    // MARK: - Helpers

    private static func distance(from a: SCNVector3, to b: SCNVector3) -> Double {
        let dx = Double(a.x - b.x)
        let dy = Double(a.y - b.y)
        let dz = Double(a.z - b.z)
        return (dx * dx + dy * dy + dz * dz).squareRoot()
    }
}
