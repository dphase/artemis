import SwiftUI
import SceneKit

struct ContentView: View {
    @StateObject private var sceneController = OrbitSceneController()
    @State private var isPlaying: Bool = true
    @State private var missionTime: Date = Date()
    @State private var showingPrivacyPolicy = false
    @State private var showSplash = true

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
                    missionTime: $missionTime,
                    onResetToNow: { sceneController.focusOn(.overview) },
                    onFocusEarth: { sceneController.focusOn(.earth) },
                    onFocusMoon: { sceneController.focusOn(.moon) },
                    onFocusSun: { sceneController.focusOn(.sun) }
                )
            }
            .opacity(showSplash ? 0 : 1)

            // Camera debug overlay (uncomment to enable)
            // VStack {
            //     Text(sceneController.cameraDebugString)
            //         .font(.system(size: 11, design: .monospaced))
            //         .foregroundStyle(.green)
            //         .padding(8)
            //         .background(.black.opacity(0.6))
            //         .cornerRadius(6)
            //         .padding(.leading, 12)
            //         .padding(.top, 4)
            //     Spacer()
            // }
            // .frame(maxWidth: .infinity, alignment: .leading)
            // .opacity(showSplash ? 0 : 1)

            // Splash screen overlay
            if showSplash {
                Color(red: 0.02, green: 0.05, blue: 0.12)
                    .ignoresSafeArea()
                    .overlay {
                        Image("SplashImage")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                    .transition(.opacity)
                    .onTapGesture { dismissSplash() }
            }
        }
        .onReceive(timer) { _ in
            guard isPlaying else { return }
            missionTime = missionTime.addingTimeInterval(1.0 / 30.0)
            missionTime = min(missionTime, MissionTimeline.splashdownDate)
            sceneController.update(for: missionTime)
        }
        .onChange(of: missionTime) { _, newValue in
            guard !isPlaying else { return }
            sceneController.update(for: newValue)
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .onAppear {
            // Always snap to now on first launch
            let now = Date()
            if now < MissionTimeline.launchDate {
                missionTime = MissionTimeline.launchDate
            } else if now > MissionTimeline.splashdownDate {
                missionTime = MissionTimeline.splashdownDate
            } else {
                missionTime = now
            }
            sceneController.update(for: missionTime)

            // Auto-dismiss splash after 2.5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                dismissSplash()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            snapToNowIfPlaying()
            sceneController.update(for: missionTime)
        }
        .onChange(of: showSplash) { _, visible in
            guard !visible else { return }
            // After splash dismisses, check for screenshot launch arguments
            let args = ProcessInfo.processInfo.arguments
            let target: OrbitSceneController.CameraTarget? =
                args.contains("--focus-earth") ? .earth :
                args.contains("--focus-moon") ? .moon :
                args.contains("--focus-sun") ? .sun : nil
            if let target {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    sceneController.focusOn(target)
                }
            }
        }
    }

    /// Snaps missionTime to the current real time (clamped to mission window) if playing.
    private func snapToNowIfPlaying() {
        guard isPlaying else { return }
        let now = Date()
        if now < MissionTimeline.launchDate {
            missionTime = MissionTimeline.launchDate
        } else if now > MissionTimeline.splashdownDate {
            missionTime = MissionTimeline.splashdownDate
        } else {
            missionTime = now
        }
    }

    private func dismissSplash() {
        guard showSplash else { return }
        withAnimation(.easeOut(duration: 0.6)) {
            showSplash = false
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
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = false
        scnView.isPlaying = true
        sceneController.scnView = scnView
        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}
}

#Preview {
    ContentView()
}
