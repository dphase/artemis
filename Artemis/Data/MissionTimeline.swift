import Foundation
import SceneKit

// MARK: - Mission Phase

enum MissionPhase: String {
    case prelaunch = "Pre-Launch"
    case parkingOrbit = "Parking Orbit"
    case translunarInjection = "Trans-Lunar Injection"
    case outboundCoast = "Outbound Coast"
    case lunarFlyby = "Lunar Flyby"
    case returnCoast = "Return Coast"
    case reentry = "Re-Entry"
}

// MARK: - Trajectory Waypoint

struct TrajectoryWaypoint {
    let time: TimeInterval // seconds from launch
    let position: SIMD3<Float>
    let velocity: SIMD3<Float>
}

// MARK: - Mission Timeline

struct MissionTimeline {

    // MARK: Key Dates

    /// Artemis II launched April 1, 2026 at 6:36 PM EDT (22:36 UTC) after brief technical delay.
    static let launchDate: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 4
        components.day = 1
        components.hour = 22
        components.minute = 36
        components.second = 0
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: components)!
    }()

    /// Splashdown ~10.5 days after launch.
    static let splashdownDate: Date = launchDate.addingTimeInterval(10.5 * 86400)

    // MARK: Scene-Scale Constants

    /// 1 scene unit = 1 Earth radius = 6,371 km
    static let earthRadiusKm: Double = 6371.0
    /// Moon distance in scene units (~384,400 km / 6,371 km)
    static let moonDistance: Float = 60.27

    /// Total mission duration in seconds.
    static let missionDuration: TimeInterval = 10.5 * 86400

    // MARK: Phase Boundaries (seconds from launch)

    private static let parkingOrbitEnd: TimeInterval = 2 * 3600          // ~2 hours
    private static let tliEnd: TimeInterval = 2.5 * 3600                // ~2.5 hours (short TLI burn)
    private static let outboundCoastEnd: TimeInterval = 4.0 * 86400     // ~4 days
    private static let lunarFlybyEnd: TimeInterval = 4.5 * 86400        // ~4.5 days
    private static let returnCoastEnd: TimeInterval = 10.0 * 86400      // ~10 days
    // Remainder until splashdown is re-entry

    // MARK: Phase Determination

    static func phase(at date: Date) -> MissionPhase {
        let elapsed = date.timeIntervalSince(launchDate)

        if elapsed < 0 {
            return .prelaunch
        } else if elapsed < parkingOrbitEnd {
            return .parkingOrbit
        } else if elapsed < tliEnd {
            return .translunarInjection
        } else if elapsed < outboundCoastEnd {
            return .outboundCoast
        } else if elapsed < lunarFlybyEnd {
            return .lunarFlyby
        } else if elapsed < returnCoastEnd {
            return .returnCoast
        } else {
            return .reentry
        }
    }

    // MARK: - Waypoints

    /// Full Artemis II free-return trajectory waypoints.
    /// The path traces a figure-8 in the rotating frame:
    ///   Earth (origin) -> LEO -> TLI -> outbound coast -> lunar flyby -> return coast -> Earth
    static let waypoints: [TrajectoryWaypoint] = {
        // Convenience
        let hr: TimeInterval = 3600
        let day: TimeInterval = 86400

        // Moon target position for trajectory shaping (slight Z for inclination)
        let moonX: Float = 58.5
        let moonY: Float = 0.0
        let moonZ: Float = 3.0

        // Closest approach distance from Moon center (~8,900 km => 1.40 units)
        let flybyRadius: Float = 1.40

        var wp: [TrajectoryWaypoint] = []

        // -----------------------------------------------------------
        // 1. Parking orbit: ~2 LEO revolutions at radius 1.05
        //    LEO period ~90 min; place waypoints every ~30 min
        // -----------------------------------------------------------
        let leoR: Float = 1.05
        let leoAngularRate: Float = 2 * .pi / (90 * 60) // rad/s
        let parkingCount = 5
        for i in 0..<parkingCount {
            let t = TimeInterval(i) * 30 * 60 // every 30 minutes
            let angle = leoAngularRate * Float(t)
            let x = leoR * cos(angle)
            let y = leoR * sin(angle)
            let vx = -leoR * leoAngularRate * sin(angle) * 1000 // scale for visual
            let vy = leoR * leoAngularRate * cos(angle) * 1000
            wp.append(TrajectoryWaypoint(
                time: t,
                position: SIMD3<Float>(x, y, 0.02),
                velocity: SIMD3<Float>(vx, vy, 0)
            ))
        }

        // -----------------------------------------------------------
        // 2. TLI burn point (~2 hours) - kick velocity outward
        // -----------------------------------------------------------
        let tliTime = 2.0 * hr
        let tliAngle = leoAngularRate * Float(tliTime)
        wp.append(TrajectoryWaypoint(
            time: tliTime,
            position: SIMD3<Float>(leoR * cos(tliAngle), leoR * sin(tliAngle), 0.03),
            velocity: SIMD3<Float>(2.0, 0.5, 0.1)
        ))

        // -----------------------------------------------------------
        // 3. Outbound coast: smooth arc from near-Earth to Moon (~4 days)
        //    Use a parametric curve that arcs in Y and Z.
        // -----------------------------------------------------------
        let outboundStart = 2.5 * hr
        let outboundEnd = 4.0 * day
        let outboundCount = 12
        for i in 0..<outboundCount {
            let frac = Double(i) / Double(outboundCount - 1)
            let t = outboundStart + frac * (outboundEnd - outboundStart)

            // Parametric position: cubic ease from Earth vicinity to Moon vicinity
            let f = Float(frac)
            let easeF = f * f * (3 - 2 * f) // smoothstep

            // Start near TLI exit point
            let startX: Float = 1.5
            let startY: Float = 0.8
            let startZ: Float = 0.1

            let endX: Float = moonX + flybyRadius * 0.5
            let endY: Float = moonY + 2.0
            let endZ: Float = moonZ + 0.5

            // Arc: add a Y bulge for the curved trajectory
            let arcY: Float = 8.0 * f * (1 - f) // peaks at midpoint
            let arcZ: Float = 2.0 * f * (1 - f)

            let x = startX + (endX - startX) * easeF
            let y = startY + (endY - startY) * easeF + arcY
            let z = startZ + (endZ - startZ) * easeF + arcZ

            // Approximate velocity as direction of travel (will be refined by interpolator)
            let vx = (endX - startX) * 0.01
            let vy = (endY - startY) * 0.01 + 8.0 * (1 - 2 * f) * 0.01
            let vz = (endZ - startZ) * 0.01

            wp.append(TrajectoryWaypoint(
                time: t,
                position: SIMD3<Float>(x, y, z),
                velocity: SIMD3<Float>(vx, vy, vz)
            ))
        }

        // -----------------------------------------------------------
        // 4. Lunar flyby: 6 tightly-spaced waypoints curving behind the Moon
        //    Closest approach on the far side (away from Earth).
        // -----------------------------------------------------------
        let flybyStartTime = 4.0 * day
        let flybyDuration = 0.5 * day // ~12 hours around Moon
        let flybyCount = 6

        for i in 0..<flybyCount {
            let frac = Double(i) / Double(flybyCount - 1)
            let t = flybyStartTime + frac * flybyDuration

            // Sweep angle: come from Earth-side, curve behind, exit back toward Earth
            // Angle goes from roughly -100 degrees to +100 degrees around Moon
            let sweepAngle = Float(-100 + 200 * Float(frac)) * (.pi / 180)

            // Orbit in the XY plane relative to Moon, with slight Z wobble
            let localX = flybyRadius * cos(sweepAngle)
            let localY = flybyRadius * sin(sweepAngle)
            let localZ: Float = 0.3 * sin(sweepAngle * 2)

            let x = moonX + localX
            let y = moonY + localY
            let z = moonZ + localZ

            // Velocity: tangent to the flyby arc
            let vx = -flybyRadius * sin(sweepAngle) * 0.05
            let vy = flybyRadius * cos(sweepAngle) * 0.05
            let vz: Float = 0.3 * cos(sweepAngle * 2) * 0.1

            wp.append(TrajectoryWaypoint(
                time: t,
                position: SIMD3<Float>(x, y, z),
                velocity: SIMD3<Float>(vx, vy, vz)
            ))
        }

        // -----------------------------------------------------------
        // 5. Return coast: arc back to Earth on a DIFFERENT path (~5.5 days)
        //    The free-return trajectory curves below the outbound path (negative Y).
        // -----------------------------------------------------------
        let returnStart = 4.5 * day
        let returnEnd = 10.0 * day
        let returnCount = 12
        for i in 0..<returnCount {
            let frac = Double(i) / Double(returnCount - 1)
            let t = returnStart + frac * (returnEnd - returnStart)

            let f = Float(frac)
            let easeF = f * f * (3 - 2 * f)

            // Start near Moon flyby exit
            let startX: Float = moonX + flybyRadius * 0.5
            let startY: Float = moonY - 2.0
            let startZ: Float = moonZ - 0.3

            // End near Earth
            let endX: Float = 1.3
            let endY: Float = -0.6
            let endZ: Float = -0.1

            // Arc on the opposite side (negative Y bulge for figure-8 shape)
            let arcY: Float = -10.0 * f * (1 - f)
            let arcZ: Float = -3.0 * f * (1 - f)

            let x = startX + (endX - startX) * easeF
            let y = startY + (endY - startY) * easeF + arcY
            let z = startZ + (endZ - startZ) * easeF + arcZ

            let vx = (endX - startX) * 0.01
            let vy = (endY - startY) * 0.01 - 10.0 * (1 - 2 * f) * 0.01
            let vz = (endZ - startZ) * 0.01

            wp.append(TrajectoryWaypoint(
                time: t,
                position: SIMD3<Float>(x, y, z),
                velocity: SIMD3<Float>(vx, vy, vz)
            ))
        }

        // -----------------------------------------------------------
        // 6. Re-entry: final approach to Earth surface
        // -----------------------------------------------------------
        let reentryStart = 10.0 * day
        let reentryEnd = 10.5 * day
        let reentryCount = 3
        for i in 0..<reentryCount {
            let frac = Double(i) / Double(reentryCount - 1)
            let t = reentryStart + frac * (reentryEnd - reentryStart)

            let f = Float(frac)
            let startX: Float = 1.3
            let startY: Float = -0.6
            let endX: Float = 1.01
            let endY: Float = -0.2

            let x = startX + (endX - startX) * f
            let y = startY + (endY - startY) * f
            let z: Float = -0.1 * (1 - f)

            wp.append(TrajectoryWaypoint(
                time: t,
                position: SIMD3<Float>(x, y, z),
                velocity: SIMD3<Float>(-0.5, 0.3, 0.05)
            ))
        }

        return rotateWaypointsToMoon(wp)
    }()

    /// Rotates waypoints -90° so the trajectory's Moon target (originally on +X)
    /// appears at -Y, placing it below Earth on a portrait screen.
    private static func rotateWaypointsToMoon(_ wp: [TrajectoryWaypoint]) -> [TrajectoryWaypoint] {
        // -90° rotation: cos=-0, sin=-1 → new_x = y, new_y = -x
        return wp.map { w in
            let px = w.position.y
            let py = -w.position.x
            let vx = w.velocity.y
            let vy = -w.velocity.x
            return TrajectoryWaypoint(
                time: w.time,
                position: SIMD3<Float>(px, py, w.position.z),
                velocity: SIMD3<Float>(vx, vy, w.velocity.z)
            )
        }
    }
}
