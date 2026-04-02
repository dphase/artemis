import SwiftUI
import SceneKit

struct ContentView: View {
    @StateObject private var sceneController = OrbitSceneController()
    @State private var timeScale: Double = 100.0
    @State private var isPlaying: Bool = true
    @State private var missionTime: Date = MissionTimeline.launchDate

    private let timer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            SceneViewContainer(scene: sceneController.scene, pointOfView: sceneController.cameraNode)
                .ignoresSafeArea()

            VStack {
                Spacer()
                HUDView(
                    missionTime: missionTime,
                    phase: MissionTimeline.phase(at: missionTime),
                    distanceFromEarth: sceneController.spacecraftDistanceFromEarth,
                    distanceFromMoon: sceneController.spacecraftDistanceFromMoon,
                    velocity: sceneController.spacecraftVelocity
                )
                TimeControlsView(
                    isPlaying: $isPlaying,
                    timeScale: $timeScale,
                    missionTime: $missionTime
                )
            }
        }
        .onReceive(timer) { _ in
            guard isPlaying else { return }
            missionTime = missionTime.addingTimeInterval(timeScale / 30.0)
            missionTime = min(missionTime, MissionTimeline.splashdownDate)
            sceneController.update(for: missionTime)
        }
        .onChange(of: missionTime) { _, newValue in
            sceneController.update(for: newValue)
        }
        .onAppear {
            sceneController.update(for: missionTime)
        }
    }
}

struct SceneViewContainer: UIViewRepresentable {
    let scene: SCNScene
    let pointOfView: SCNNode

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = scene
        scnView.pointOfView = pointOfView
        scnView.backgroundColor = .black
        scnView.antialiasingMode = .multisampling4X
        scnView.allowsCameraControl = true
        scnView.defaultCameraController.interactionMode = .orbitTurntable
        scnView.defaultCameraController.minimumVerticalAngle = -89
        scnView.defaultCameraController.maximumVerticalAngle = 89
        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}
}

#Preview {
    ContentView()
}
