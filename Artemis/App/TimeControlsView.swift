import SwiftUI

struct TimeControlsView: View {
    @Binding var isPlaying: Bool
    @Binding var timeScale: Double
    @Binding var missionTime: Date

    private let speeds: [Double] = [1, 10, 100, 1000]

    private var sliderRange: ClosedRange<Double> {
        let start = MissionTimeline.launchDate.timeIntervalSinceReferenceDate
        let end = MissionTimeline.splashdownDate.timeIntervalSinceReferenceDate
        return start ... end
    }

    private var sliderValue: Binding<Double> {
        Binding<Double>(
            get: { missionTime.timeIntervalSinceReferenceDate },
            set: { missionTime = Date(timeIntervalSinceReferenceDate: $0) }
        )
    }

    var body: some View {
        VStack(spacing: 10) {
            // Timeline slider
            Slider(value: sliderValue, in: sliderRange)
                .tint(.white.opacity(0.7))

            // Controls row
            HStack(spacing: 16) {
                // Play / Pause
                Button {
                    isPlaying.toggle()
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                }

                // Speed buttons
                ForEach(speeds, id: \.self) { speed in
                    Button {
                        timeScale = speed
                    } label: {
                        Text("\(Int(speed))x")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(timeScale == speed ? .white.opacity(0.35) : .white.opacity(0.12))
                            )
                    }
                }

                Spacer()

                // Reset button
                Button {
                    missionTime = MissionTimeline.launchDate
                } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.body)
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal)
        .padding(.bottom)
    }
}
