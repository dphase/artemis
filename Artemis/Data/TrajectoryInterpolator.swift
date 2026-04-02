import Foundation
import SceneKit
import simd

// MARK: - Trajectory State

struct TrajectoryState {
    let position: SCNVector3
    let velocity: SCNVector3
    let speed: Double   // km/s in real units
    let parameter: Double // 0.0 to 1.0 along the path
}

// MARK: - Trajectory Interpolator

struct TrajectoryInterpolator {

    // MARK: - Public Interface

    /// Returns the interpolated trajectory state at the given date.
    static func state(at date: Date) -> TrajectoryState {
        let param = parameterForDate(date)
        let waypoints = MissionTimeline.waypoints

        guard waypoints.count >= 2 else {
            let zero = SCNVector3Zero
            return TrajectoryState(position: zero, velocity: zero, speed: 0, parameter: 0)
        }

        let elapsed = date.timeIntervalSince(MissionTimeline.launchDate)
        let (index, localT) = segmentAndLocalT(forElapsed: elapsed, in: waypoints)

        let pos = catmullRomPosition(at: index, t: Float(localT), in: waypoints)
        let vel = finiteDifferenceVelocity(at: index, t: Float(localT), in: waypoints)

        // Convert velocity from scene-units/s to km/s
        let speedSceneUnitsPerSec = Double(simd_length(vel))
        let speedKmPerSec = speedSceneUnitsPerSec * MissionTimeline.earthRadiusKm

        return TrajectoryState(
            position: SCNVector3(pos.x, pos.y, pos.z),
            velocity: SCNVector3(vel.x, vel.y, vel.z),
            speed: speedKmPerSec,
            parameter: param
        )
    }

    /// Returns evenly-spaced points along the full trajectory for rendering the path.
    static func trajectoryPoints(count: Int) -> [SCNVector3] {
        let waypoints = MissionTimeline.waypoints
        guard waypoints.count >= 2, count >= 2 else { return [] }

        let totalDuration = waypoints.last!.time - waypoints.first!.time
        var points: [SCNVector3] = []
        points.reserveCapacity(count)

        for i in 0..<count {
            let frac = Double(i) / Double(count - 1)
            let elapsed = waypoints.first!.time + frac * totalDuration
            let (index, localT) = segmentAndLocalT(forElapsed: elapsed, in: waypoints)
            let pos = catmullRomPosition(at: index, t: Float(localT), in: waypoints)
            points.append(SCNVector3(pos.x, pos.y, pos.z))
        }

        return points
    }

    /// Returns a 0.0-1.0 parameter for the given date within the mission timeline.
    static func parameterForDate(_ date: Date) -> Double {
        let elapsed = date.timeIntervalSince(MissionTimeline.launchDate)
        let waypoints = MissionTimeline.waypoints
        guard let first = waypoints.first, let last = waypoints.last else { return 0 }

        let totalDuration = last.time - first.time
        guard totalDuration > 0 else { return 0 }

        let clamped = max(first.time, min(elapsed, last.time))
        return (clamped - first.time) / totalDuration
    }

    // MARK: - Private Helpers

    /// Finds the segment index and local t for a given elapsed time.
    private static func segmentAndLocalT(
        forElapsed elapsed: TimeInterval,
        in waypoints: [TrajectoryWaypoint]
    ) -> (index: Int, localT: Double) {
        // Clamp elapsed time
        let clamped = max(waypoints.first!.time, min(elapsed, waypoints.last!.time))

        // Find the segment: waypoints[index] ... waypoints[index+1]
        var index = 0
        for i in 0..<(waypoints.count - 1) {
            if clamped >= waypoints[i].time {
                index = i
            }
        }

        // Ensure we don't go past the last segment
        if index >= waypoints.count - 1 {
            index = waypoints.count - 2
        }

        let segStart = waypoints[index].time
        let segEnd = waypoints[index + 1].time
        let segDuration = segEnd - segStart

        let localT: Double
        if segDuration > 0 {
            localT = (clamped - segStart) / segDuration
        } else {
            localT = 0
        }

        return (index, min(max(localT, 0), 1))
    }

    /// Catmull-Rom spline interpolation for position.
    ///
    /// Given control points P0, P1, P2, P3 and parameter t in [0,1]:
    /// `0.5 * ((2*P1) + (-P0+P2)*t + (2*P0-5*P1+4*P2-P3)*t^2 + (-P0+3*P1-3*P2+P3)*t^3)`
    private static func catmullRomPosition(
        at segmentIndex: Int,
        t: Float,
        in waypoints: [TrajectoryWaypoint]
    ) -> SIMD3<Float> {
        let n = waypoints.count

        // Get 4 control points, duplicating at endpoints
        let i0 = max(segmentIndex - 1, 0)
        let i1 = segmentIndex
        let i2 = min(segmentIndex + 1, n - 1)
        let i3 = min(segmentIndex + 2, n - 1)

        let p0 = waypoints[i0].position
        let p1 = waypoints[i1].position
        let p2 = waypoints[i2].position
        let p3 = waypoints[i3].position

        let t2 = t * t
        let t3 = t2 * t

        let two: Float = 2
        let a = two * p1
        let b = (p2 - p0) * t
        let c = (two * p0 - Float(5) * p1 + Float(4) * p2 - p3) * t2
        let d = (Float(3) * p1 - p0 - Float(3) * p2 + p3) * t3
        return Float(0.5) * (a + b + c + d)
    }

    /// Velocity via finite differences on the Catmull-Rom spline.
    private static func finiteDifferenceVelocity(
        at segmentIndex: Int,
        t: Float,
        in waypoints: [TrajectoryWaypoint]
    ) -> SIMD3<Float> {
        let dt: Float = 0.001
        let segDuration = Float(waypoints[min(segmentIndex + 1, waypoints.count - 1)].time
                                - waypoints[segmentIndex].time)

        // Evaluate position at t - dt and t + dt, staying within [0, 1]
        let tBack = max(t - dt, Float(0))
        let tForward = min(t + dt, Float(1))

        let posBack = catmullRomPosition(at: segmentIndex, t: tBack, in: waypoints)
        let posForward = catmullRomPosition(at: segmentIndex, t: tForward, in: waypoints)

        let delta = tForward - tBack
        guard delta > 0, segDuration > 0 else { return .zero }

        // dp/dt_local, then convert to scene-units per second
        let dpdt = (posForward - posBack) / delta
        return dpdt / segDuration
    }
}
