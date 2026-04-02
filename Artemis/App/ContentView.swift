import SwiftUI
import SceneKit

struct ContentView: View {
    @StateObject private var sceneController = OrbitSceneController()
    @State private var isPlaying: Bool = true
    @State private var missionTime: Date = Date()
    @State private var showingPrivacyPolicy = false

    private let timer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            SceneViewContainer(sceneController: sceneController)
                .ignoresSafeArea()

            VStack(spacing: 4) {
                HStack {
                    Spacer()
                    Button {
                        showingPrivacyPolicy = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 28, height: 28)
                    }
                }
                .padding(.horizontal)
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
                    missionTime: $missionTime
                )
            }
        }
        .onReceive(timer) { _ in
            guard isPlaying else { return }
            missionTime = missionTime.addingTimeInterval(1.0 / 30.0)
            missionTime = min(missionTime, MissionTimeline.splashdownDate)
            sceneController.update(for: missionTime)
        }
        .onChange(of: missionTime) { _, newValue in
            sceneController.update(for: newValue)
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .onAppear {
            // Clamp to mission window
            let now = Date()
            if now < MissionTimeline.launchDate {
                missionTime = MissionTimeline.launchDate
            } else if now > MissionTimeline.splashdownDate {
                missionTime = MissionTimeline.splashdownDate
            } else {
                missionTime = now
            }
            sceneController.update(for: missionTime)
        }
    }
}

struct SceneViewContainer: UIViewRepresentable {
    let sceneController: OrbitSceneController

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = sceneController.scene
        scnView.pointOfView = sceneController.cameraNode
        scnView.backgroundColor = .black
        scnView.antialiasingMode = .multisampling4X
        scnView.allowsCameraControl = false
        scnView.autoenablesDefaultLighting = false
        scnView.isPlaying = true
        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}
}

#Preview {
    ContentView()
}
