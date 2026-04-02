import SwiftUI

struct TimeControlsView: View {
    @Binding var isPlaying: Bool
    @Binding var missionTime: Date
    var onResetToNow: (() -> Void)?

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
        HStack(spacing: 12) {
            Button {
                isPlaying.toggle()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
            }

            Slider(value: sliderValue, in: sliderRange)
                .tint(.white.opacity(0.7))

            Button {
                let now = Date()
                if now < MissionTimeline.launchDate {
                    missionTime = MissionTimeline.launchDate
                } else if now > MissionTimeline.splashdownDate {
                    missionTime = MissionTimeline.splashdownDate
                } else {
                    missionTime = now
                }
                isPlaying = true
                onResetToNow?()
            } label: {
                Image(systemName: "location.fill")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .modifier(GlassModifier(shape: .rect(cornerRadius: 12), interactive: true))
        .padding(.horizontal)
        .padding(.bottom, 4)
    }
}
