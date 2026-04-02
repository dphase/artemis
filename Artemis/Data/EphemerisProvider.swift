import Foundation
import SceneKit

// MARK: - Ephemeris Provider

/// Simplified lunar ephemeris using basic Keplerian orbital elements.
/// Provides the Moon's position in scene coordinates (1 unit = 1 Earth radius).
struct EphemerisProvider {

    // MARK: - Constants

    /// Mean sidereal orbital period of the Moon in seconds.
    private static let lunarPeriod: TimeInterval = 27.321661 * 86400

    /// Semi-major axis in scene units (384,400 km / 6,371 km).
    private static let semiMajorAxis: Double = 60.27

    /// Orbital eccentricity of the Moon.
    private static let eccentricity: Double = 0.0549

    /// Inclination of the lunar orbit to the ecliptic in radians (~5.14 degrees).
    private static let inclination: Double = 5.14 * .pi / 180

    /// Longitude of ascending node precession period (~18.6 years).
    private static let nodePrecessionPeriod: TimeInterval = 18.6 * 365.25 * 86400

    /// J2000 epoch: 2000-01-01T12:00:00 UTC
    private static let j2000: Date = {
        var components = DateComponents()
        components.year = 2000
        components.month = 1
        components.day = 1
        components.hour = 12
        components.minute = 0
        components.second = 0
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: components)!
    }()

    /// Mean longitude of the Moon at J2000 epoch (radians).
    /// ~218.32 degrees
    private static let meanLongitudeAtEpoch: Double = 218.32 * .pi / 180

    /// Longitude of ascending node at J2000 (radians).
    /// ~125.04 degrees
    private static let nodeAtEpoch: Double = 125.04 * .pi / 180

    // MARK: - Public

    /// Computes the Moon's position in scene coordinates at the given date.
    ///
    /// Uses simplified Keplerian elements:
    /// - Circular orbit approximation with eccentricity correction (equation of center)
    /// - Inclined orbital plane with precessing ascending node
    ///
    /// - Parameter date: The date for which to compute the Moon's position.
    /// - Returns: Position in scene coordinates (1 unit = 1 Earth radius, Earth at origin).
    static func moonPosition(at date: Date) -> SCNVector3 {
        let elapsed = date.timeIntervalSince(j2000)

        // Mean anomaly (radians)
        let meanAnomaly = fmod(2 * .pi * elapsed / lunarPeriod, 2 * .pi)

        // Equation of center (first-order eccentricity correction)
        let trueAnomaly = meanAnomaly
            + 2 * eccentricity * sin(meanAnomaly)
            + 1.25 * eccentricity * eccentricity * sin(2 * meanAnomaly)

        // Radial distance with eccentricity
        let radius = semiMajorAxis * (1 - eccentricity * eccentricity)
            / (1 + eccentricity * cos(trueAnomaly))

        // Mean longitude gives the angular position in the orbital plane
        let meanLongitude = meanLongitudeAtEpoch + 2 * .pi * elapsed / lunarPeriod
        let longitude = meanLongitude
            + 2 * eccentricity * sin(meanAnomaly)

        // Ascending node (precesses retrograde over ~18.6 years)
        let node = nodeAtEpoch - 2 * .pi * elapsed / nodePrecessionPeriod

        // Argument of latitude (angle from ascending node in the orbital plane)
        let argLat = longitude - node

        // Position in 3D: rotate from orbital plane to scene coordinates
        // The orbital plane is tilted by `inclination` relative to the reference (ecliptic) plane.
        let xOrbital = radius * cos(argLat)
        let yOrbital = radius * sin(argLat)

        // Rotate by ascending node and inclination
        let x = xOrbital * cos(node) - yOrbital * sin(node) * cos(inclination)
        let y = xOrbital * sin(node) + yOrbital * cos(node) * cos(inclination)
        let z = yOrbital * sin(inclination)

        return SCNVector3(Float(x), Float(y), Float(z))
    }

    /// Returns the Moon's angular position (mean longitude) in radians at the given date.
    /// Useful for determining where along its orbit the Moon is.
    static func moonMeanLongitude(at date: Date) -> Double {
        let elapsed = date.timeIntervalSince(j2000)
        return fmod(meanLongitudeAtEpoch + 2 * .pi * elapsed / lunarPeriod, 2 * .pi)
    }

    /// Returns the approximate distance from Earth to Moon in scene units at the given date.
    static func moonDistance(at date: Date) -> Double {
        let elapsed = date.timeIntervalSince(j2000)
        let meanAnomaly = fmod(2 * .pi * elapsed / lunarPeriod, 2 * .pi)
        let trueAnomaly = meanAnomaly
            + 2 * eccentricity * sin(meanAnomaly)
            + 1.25 * eccentricity * eccentricity * sin(2 * meanAnomaly)
        return semiMajorAxis * (1 - eccentricity * eccentricity)
            / (1 + eccentricity * cos(trueAnomaly))
    }
}
