import Testing
import SceneKit
@testable import Artemis

// MARK: - Helpers

private func magnitude(_ v: SCNVector3) -> Double {
    let dx = Double(v.x)
    let dy = Double(v.y)
    let dz = Double(v.z)
    return (dx * dx + dy * dy + dz * dz).squareRoot()
}

private func magnitude(_ v: SIMD3<Float>) -> Double {
    Double(simd_length(v))
}

// MARK: - Mission Timeline Tests

@Suite("Mission Timeline")
struct MissionTimelineTests {

    @Test("Launch date precedes splashdown")
    func launchBeforeSplashdown() {
        #expect(MissionTimeline.launchDate < MissionTimeline.splashdownDate)
    }

    @Test("Splashdown is approximately 10.5 days after launch")
    func splashdownDuration() {
        let interval = MissionTimeline.splashdownDate.timeIntervalSince(MissionTimeline.launchDate)
        let expectedInterval = 10.5 * 86400.0
        #expect(abs(interval - expectedInterval) < 1.0) // within 1 second
    }

    @Test("Waypoints array is not empty and has at least 20 entries")
    func waypointsNotEmpty() {
        #expect(!MissionTimeline.waypoints.isEmpty)
        #expect(MissionTimeline.waypoints.count >= 20)
    }

    @Test("Waypoints are ordered by time")
    func waypointsOrderedByTime() {
        let waypoints = MissionTimeline.waypoints
        for i in 1..<waypoints.count {
            #expect(
                waypoints[i].time >= waypoints[i - 1].time,
                "Waypoint \(i) time (\(waypoints[i].time)) should be >= waypoint \(i - 1) time (\(waypoints[i - 1].time))"
            )
        }
    }

    @Test("First waypoint starts near Earth")
    func firstWaypointNearEarth() {
        let first = MissionTimeline.waypoints.first!
        let mag = magnitude(first.position)
        #expect(abs(mag - 1.0) < 0.5, "First waypoint magnitude \(mag) should be close to 1.0")
    }

    @Test("Last waypoint ends near Earth")
    func lastWaypointNearEarth() {
        let last = MissionTimeline.waypoints.last!
        let mag = magnitude(last.position)
        #expect(abs(mag - 1.0) < 0.5, "Last waypoint magnitude \(mag) should be close to 1.0")
    }

    @Test("Phase before launch is prelaunch")
    func phaseBeforeLaunch() {
        let beforeLaunch = MissionTimeline.launchDate.addingTimeInterval(-3600)
        #expect(MissionTimeline.phase(at: beforeLaunch) == .prelaunch)
    }

    @Test("Phase near splashdown is reentry")
    func phaseNearSplashdown() {
        let nearSplashdown = MissionTimeline.splashdownDate.addingTimeInterval(-1800)
        #expect(MissionTimeline.phase(at: nearSplashdown) == .reentry)
    }

    @Test("Phase around day 4-5 is lunar flyby")
    func phaseLunarFlyby() {
        let day4_25 = MissionTimeline.launchDate.addingTimeInterval(4.25 * 86400)
        #expect(MissionTimeline.phase(at: day4_25) == .lunarFlyby)
    }
}

// MARK: - Trajectory Interpolator Tests

@Suite("Trajectory Interpolator")
struct TrajectoryInterpolatorTests {

    @Test("State at launch date returns position near Earth")
    func stateAtLaunchNearEarth() {
        let state = TrajectoryInterpolator.state(at: MissionTimeline.launchDate)
        let mag = magnitude(state.position)
        #expect(abs(mag - 1.0) < 0.5, "Position at launch should be near Earth, got magnitude \(mag)")
    }

    @Test("State at splashdown date returns position near Earth")
    func stateAtSplashdownNearEarth() {
        let state = TrajectoryInterpolator.state(at: MissionTimeline.splashdownDate)
        let mag = magnitude(state.position)
        #expect(abs(mag - 1.0) < 0.5, "Position at splashdown should be near Earth, got magnitude \(mag)")
    }

    @Test("Parameter at launch date is approximately 0.0")
    func parameterAtLaunch() {
        let param = TrajectoryInterpolator.parameterForDate(MissionTimeline.launchDate)
        #expect(abs(param - 0.0) < 0.01, "Parameter at launch should be ~0.0, got \(param)")
    }

    @Test("Parameter at splashdown date is approximately 1.0")
    func parameterAtSplashdown() {
        let param = TrajectoryInterpolator.parameterForDate(MissionTimeline.splashdownDate)
        #expect(abs(param - 1.0) < 0.01, "Parameter at splashdown should be ~1.0, got \(param)")
    }

    @Test("Parameter at midpoint is approximately 0.5")
    func parameterAtMidpoint() {
        let midpoint = MissionTimeline.launchDate.addingTimeInterval(5.25 * 86400)
        let param = TrajectoryInterpolator.parameterForDate(midpoint)
        #expect(abs(param - 0.5) < 0.05, "Parameter at midpoint should be ~0.5, got \(param)")
    }

    @Test("trajectoryPoints returns the requested number of points")
    func trajectoryPointsCount() {
        let count = 500
        let points = TrajectoryInterpolator.trajectoryPoints(count: count)
        #expect(points.count == count)
    }

    @Test("trajectoryPoints first point is near Earth")
    func trajectoryPointsFirstNearEarth() {
        let points = TrajectoryInterpolator.trajectoryPoints(count: 100)
        let mag = magnitude(points.first!)
        #expect(abs(mag - 1.0) < 0.5, "First trajectory point should be near Earth, got magnitude \(mag)")
    }

    @Test("trajectoryPoints last point is near Earth")
    func trajectoryPointsLastNearEarth() {
        let points = TrajectoryInterpolator.trajectoryPoints(count: 100)
        let mag = magnitude(points.last!)
        #expect(abs(mag - 1.0) < 0.5, "Last trajectory point should be near Earth, got magnitude \(mag)")
    }

    @Test("Trajectory reaches far from Earth (max distance exceeds 50 units)")
    func trajectoryReachesMoon() {
        let points = TrajectoryInterpolator.trajectoryPoints(count: 1000)
        let maxDistance = points.map { magnitude($0) }.max() ?? 0
        #expect(maxDistance > 50, "Trajectory should reach beyond 50 units from Earth, max was \(maxDistance)")
    }

    @Test("Velocity (speed) is non-negative")
    func velocityNonNegative() {
        let dates = [
            MissionTimeline.launchDate,
            MissionTimeline.launchDate.addingTimeInterval(2 * 86400),
            MissionTimeline.launchDate.addingTimeInterval(5 * 86400),
            MissionTimeline.launchDate.addingTimeInterval(8 * 86400),
            MissionTimeline.splashdownDate,
        ]
        for date in dates {
            let state = TrajectoryInterpolator.state(at: date)
            #expect(state.speed >= 0, "Speed should be non-negative at all times, got \(state.speed)")
        }
    }
}

// MARK: - Ephemeris Provider Tests

@Suite("Ephemeris Provider")
struct EphemerisProviderTests {

    @Test("Moon position magnitude is approximately 60.27 units")
    func moonPositionMagnitude() {
        let position = EphemerisProvider.moonPosition(at: MissionTimeline.launchDate)
        let mag = magnitude(position)
        #expect(abs(mag - 60.27) < 5.0, "Moon distance should be ~60.27 units, got \(mag)")
    }

    @Test("Moon position changes over 7 days")
    func moonPositionChangesOverTime() {
        let date1 = MissionTimeline.launchDate
        let date2 = date1.addingTimeInterval(7 * 86400)
        let pos1 = EphemerisProvider.moonPosition(at: date1)
        let pos2 = EphemerisProvider.moonPosition(at: date2)

        let dx = Double(pos2.x - pos1.x)
        let dy = Double(pos2.y - pos1.y)
        let dz = Double(pos2.z - pos1.z)
        let distance = (dx * dx + dy * dy + dz * dz).squareRoot()

        #expect(distance > 1.0, "Moon position should change significantly over 7 days, delta was \(distance)")
    }

    @Test("Moon position at dates one full orbit apart should be approximately the same")
    func moonPositionAfterFullOrbit() {
        let date1 = MissionTimeline.launchDate
        let date2 = date1.addingTimeInterval(27.321661 * 86400) // one sidereal month
        let pos1 = EphemerisProvider.moonPosition(at: date1)
        let pos2 = EphemerisProvider.moonPosition(at: date2)

        let dx = Double(pos2.x - pos1.x)
        let dy = Double(pos2.y - pos1.y)
        let dz = Double(pos2.z - pos1.z)
        let distance = (dx * dx + dy * dy + dz * dz).squareRoot()

        #expect(distance < 5.0, "Moon should return near the same position after one orbit, delta was \(distance)")
    }
}

// MARK: - Trajectory Node Tests

@Suite("Trajectory Node")
@MainActor
struct TrajectoryNodeTests {

    @Test("Creating a TrajectoryNode does not crash")
    func createTrajectoryNode() {
        let node = TrajectoryNode(pointCount: 100)
        #expect(node.name == "Trajectory")
    }

    @Test("updateProgress(0.0) produces valid state")
    func updateProgressZero() {
        let node = TrajectoryNode(pointCount: 100)
        node.updateProgress(0.0)
        // Node should still have child nodes after update
        #expect(node.childNodes.count >= 2, "TrajectoryNode should have past and future path child nodes")
    }

    @Test("updateProgress(0.5) produces valid state")
    func updateProgressHalf() {
        let node = TrajectoryNode(pointCount: 100)
        node.updateProgress(0.5)
        #expect(node.childNodes.count >= 2, "TrajectoryNode should have past and future path child nodes")
    }

    @Test("updateProgress(1.0) produces valid state")
    func updateProgressFull() {
        let node = TrajectoryNode(pointCount: 100)
        node.updateProgress(1.0)
        #expect(node.childNodes.count >= 2, "TrajectoryNode should have past and future path child nodes")
    }
}

// MARK: - Mission Phase Tests

@Suite("Mission Phase")
struct MissionPhaseTests {

    @Test("All mission phases have non-empty rawValue strings")
    func allPhasesHaveNonEmptyRawValues() {
        let allPhases: [MissionPhase] = [
            .prelaunch,
            .parkingOrbit,
            .translunarInjection,
            .outboundCoast,
            .lunarFlyby,
            .returnCoast,
            .reentry,
        ]
        for phase in allPhases {
            #expect(!phase.rawValue.isEmpty, "Phase \(phase) should have a non-empty rawValue")
        }
    }
}
