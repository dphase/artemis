import SwiftUI

struct HUDView: View {
    let missionTime: Date
    let phase: MissionPhase
    let distanceFromEarth: Double
    let distanceFromMoon: Double
    let velocity: Double

    private let kmPerUnit: Double = 6_371

    private var metString: String {
        let launch = MissionTimeline.launchDate
        let interval = missionTime.timeIntervalSince(launch)
        let prefix = interval >= 0 ? "T+" : "T-"
        let abs = abs(interval)
        let days = Int(abs) / 86400
        let hours = (Int(abs) % 86400) / 3600
        let minutes = (Int(abs) % 3600) / 60
        let seconds = Int(abs) % 60
        return String(format: "%@ %02d:%02d:%02d:%02d", prefix, days, hours, minutes, seconds)
    }

    private var earthDistanceKm: String {
        let km = distanceFromEarth * kmPerUnit
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: km)) ?? "\(Int(km))"
    }

    private var moonDistanceKm: String {
        let km = distanceFromMoon * kmPerUnit
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: km)) ?? "\(Int(km))"
    }

    private var velocityString: String {
        String(format: "%.1f", velocity)
    }

    var body: some View {
        VStack(spacing: 6) {
            // Row 1: MET timer + phase badge
            HStack {
                Text(metString)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.white)

                Spacer()

                Text(phase.rawValue)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(.white.opacity(0.2))
                    )
            }

            // Row 2: Earth dist | Moon dist | Velocity
            HStack {
                Label(earthDistanceKm + " km", systemImage: "globe.americas.fill")
                Spacer()
                Label(moonDistanceKm + " km", systemImage: "moon.fill")
                Spacer()
                Label(velocityString + " km/s", systemImage: "gauge.with.dots.needle.33percent")
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal)
        .frame(maxWidth: .infinity)
    }
}
