import SwiftUI

struct HUDView: View {
    let missionTime: Date
    let phase: MissionPhase
    let distanceFromEarth: Double
    let distanceFromMoon: Double
    let velocity: Double

    private let milesPerUnit: Double = 6_371 * 0.621371
    private let goldColor = Color(red: 249/255, green: 214/255, blue: 105/255)

    private var metString: String {
        let launch = MissionTimeline.launchDate
        let interval = missionTime.timeIntervalSince(launch)
        let prefix = interval >= 0 ? "T+" : "T-"
        let abs = abs(interval)
        let days = Int(abs) / 86400
        let hours = (Int(abs) % 86400) / 3600
        let minutes = (Int(abs) % 3600) / 60
        let seconds = Int(abs) % 60
        return String(format: "%@%02d:%02d:%02d:%02d", prefix, days, hours, minutes, seconds)
    }

    private var dateTimeString: String {
        let formatter = DateFormatter()
        let uses24Hour = DateFormatter.dateFormat(
            fromTemplate: "j",
            options: 0,
            locale: Locale.current
        )?.contains("a") == false
        formatter.dateFormat = uses24Hour ? "MMM d, HH:mm" : "MMM d, h:mm a"
        return formatter.string(from: missionTime)
    }

    private var earthDistanceMi: String {
        formatNumber(distanceFromEarth * milesPerUnit)
    }

    private var moonDistanceMi: String {
        formatNumber(distanceFromMoon * milesPerUnit)
    }

    private var velocityMph: String {
        formatNumber(velocity * 2236.936)
    }

    private func formatNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 0) {
                Text(metString)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(goldColor)

                Text(" / ")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))

                Text(dateTimeString)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.white)

                Spacer()

                Text(phase.rawValue)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .glassEffect(.clear, in: .capsule)
            }

            HStack {
                Label(earthDistanceMi + " mi", systemImage: "globe.americas.fill")
                Spacer()
                Label(moonDistanceMi + " mi", systemImage: "moon.fill")
                Spacer()
                Label(velocityMph + " mph", systemImage: "gauge.with.dots.needle.33percent")
            }
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .glassEffect(.clear.interactive(), in: .rect(cornerRadius: 12))
        .padding(.horizontal)
    }
}
