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

    /// Splashdown ~9.1 days after launch (based on NASA OEM data end).
    static let splashdownDate: Date = launchDate.addingTimeInterval(9.1 * 86400)

    // MARK: Scene-Scale Constants

    /// 1 scene unit = 1 Earth radius = 6,371 km
    static let earthRadiusKm: Double = 6371.0
    /// Moon distance in scene units at flyby (~64.85 ER from NASA tracking data)
    static let moonDistance: Float = 64.85

    /// Total mission duration in seconds (~9.05 days from NASA OEM data).
    static let missionDuration: TimeInterval = 782237

    // MARK: Phase Boundaries (seconds from launch, derived from NASA OEM tracking data)

    private static let parkingOrbitEnd: TimeInterval = 3 * 3600          // ~3 hours (2 LEO orbits)
    private static let tliEnd: TimeInterval = 3.5 * 3600                // ~3.5 hours (short TLI burn)
    private static let outboundCoastEnd: TimeInterval = 3.72 * 86400    // ~3.72 days (>55 ER from Earth)
    private static let lunarFlybyEnd: TimeInterval = 6.37 * 86400       // ~6.37 days (<55 ER returning)
    private static let returnCoastEnd: TimeInterval = 9.03 * 86400      // ~9.03 days (<2 ER from Earth)
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

    /// Full Artemis II free-return trajectory from NASA OEM ephemeris data.
    /// Parking orbit is synthetic (pre-TLI); all post-TLI waypoints are derived from
    /// real NASA/JSC tracking coordinates (EME2000 frame, rotated to scene coordinates
    /// with Moon at flyby along -Y axis for portrait display).
    static let waypoints: [TrajectoryWaypoint] = {
        let hr: TimeInterval = 3600

        // Shorthand for creating waypoints (velocity computed by interpolator via finite differences)
        func W(_ t: TimeInterval, _ x: Float, _ y: Float, _ z: Float) -> TrajectoryWaypoint {
            TrajectoryWaypoint(time: t, position: SIMD3<Float>(x, y, z), velocity: .zero)
        }

        var wp: [TrajectoryWaypoint] = []

        // -----------------------------------------------------------
        // 1. Parking orbit: 2 full LEO revolutions at radius 1.05
        //    LEO period ~90 min; oriented to depart toward first OEM point.
        //    First OEM point direction from Earth: (-0.65, -0.76, +0.06)
        // -----------------------------------------------------------
        let leoR: Float = 1.05
        let leoPeriod: Float = 90 * 60
        let leoAngularRate: Float = 2 * .pi / leoPeriod
        let incl: Float = 28.5 * .pi / 180.0

        // Starting angle chosen so after 2 full orbits the spacecraft departs
        // toward the first OEM tracking point (in -X, -Y scene direction).
        let startAngle: Float = 229.0 * .pi / 180.0

        let parkingDuration: TimeInterval = 3.0 * hr
        let parkingStep: TimeInterval = 5 * 60
        let parkingCount = Int(parkingDuration / parkingStep) + 1
        for i in 0..<parkingCount {
            let t = TimeInterval(i) * parkingStep
            let angle = startAngle + leoAngularRate * Float(t)

            let x = leoR * cos(angle)
            let y = leoR * sin(angle) * cos(incl)
            let z = leoR * sin(angle) * sin(incl)

            wp.append(W(t, x, y, z))
        }

        // TLI burn point at end of parking orbit
        let tliAngle = startAngle + leoAngularRate * Float(parkingDuration)
        wp.append(W(parkingDuration,
                     leoR * cos(tliAngle),
                     leoR * sin(tliAngle) * cos(incl),
                     leoR * sin(tliAngle) * sin(incl)))

        // -----------------------------------------------------------
        // 2. Transition: TLI burn to first OEM tracking point
        //    Smooth interpolation from LEO radius to first OEM position.
        // -----------------------------------------------------------
        let tliEndTime = 3.0 * hr
        let firstOemTime: TimeInterval = 12097.1
        let firstOemPos = SIMD3<Float>(-2.9056, -3.3728, 0.2539)

        let tliPos = SIMD3<Float>(
            leoR * cos(tliAngle),
            leoR * sin(tliAngle) * cos(incl),
            leoR * sin(tliAngle) * sin(incl)
        )

        // 3 transition waypoints between TLI and first OEM point
        for i in 1...3 {
            let f = Float(i) / 4.0
            let t = tliEndTime + Double(f) * (firstOemTime - tliEndTime)
            let easeF = f * f * (3 - 2 * f) // smoothstep
            let pos = tliPos + (firstOemPos - tliPos) * easeF
            wp.append(W(t, pos.x, pos.y, pos.z))
        }

        // -----------------------------------------------------------
        // 3. NASA OEM trajectory data (post-TLI through reentry)
        //    Derived from NASA/JSC OEM ephemeris: EME2000 frame positions
        //    converted to Earth radii and rotated so Moon at flyby is at -Y.
        //    Covers: high elliptical orbit, outbound coast, lunar flyby,
        //    return coast, and reentry approach.
        // -----------------------------------------------------------
        let oemWaypoints: [TrajectoryWaypoint] = [
            W(12097.1, -2.9056, -3.3728, 0.2539),
            W(12162.8, -2.9107, -3.4167, 0.2546),
            W(12459.3, -2.9308, -3.6118, 0.2575),
            W(12699.3, -2.9442, -3.7661, 0.2596),
            W(12939.3, -2.9553, -3.9173, 0.2615),
            W(13179.3, -2.9641, -4.0656, 0.2632),
            W(13419.3, -2.9709, -4.2111, 0.2647),
            W(13659.3, -2.9757, -4.3539, 0.2660),
            W(13899.3, -2.9787, -4.4940, 0.2672),
            W(14139.3, -2.9801, -4.6316, 0.2682),
            W(14379.3, -2.9799, -4.7668, 0.2691),
            W(14619.3, -2.9782, -4.8996, 0.2699),
            W(14859.3, -2.9751, -5.0301, 0.2705),
            W(15099.3, -2.9707, -5.1583, 0.2710),
            W(16939.6, -2.8997, -6.0739, 0.2715),
            W(18896.7, -2.7655, -6.9327, 0.2661),
            W(21536.7, -2.5225, -7.9368, 0.2531),
            W(24176.7, -2.2318, -8.7927, 0.2354),
            W(26816.7, -1.9087, -9.5216, 0.2142),
            W(29456.7, -1.5630, -10.1386, 0.1905),
            W(31958.0, -1.2209, -10.6298, 0.1663),
            W(34598.0, -0.8494, -11.0575, 0.1393),
            W(37238.0, -0.4711, -11.3979, 0.1112),
            W(39878.0, -0.0894, -11.6558, 0.0823),
            W(40118.0, -0.0547, -11.6753, 0.0797),
            W(42089.8, 0.2321, -11.8091, 0.0582),
            W(44009.8, 0.5094, -11.8996, 0.0366),
            W(45929.8, 0.7850, -11.9500, 0.0148),
            W(47849.8, 1.0581, -11.9609, -0.0069),
            W(49640.4, 1.3103, -11.9354, -0.0268),
            W(51206.9, 1.5286, -11.8848, -0.0438),
            W(52152.1, 1.6587, -11.8416, -0.0540),
            W(54072.1, 1.9187, -11.7245, -0.0745),
            W(54792.1, 2.0146, -11.6704, -0.0822),
            W(55032.1, 2.0463, -11.6511, -0.0847),
            W(56952.1, 2.2962, -11.4742, -0.1049),
            W(58872.1, 2.5379, -11.2565, -0.1246),
            W(60792.1, 2.7702, -10.9972, -0.1440),
            W(62712.1, 2.9917, -10.6951, -0.1627),
            W(64632.1, 3.2008, -10.3486, -0.1808),
            W(66552.1, 3.3955, -9.9558, -0.1981),
            W(68472.1, 3.5736, -9.5143, -0.2143),
            W(70392.1, 3.7323, -9.0214, -0.2295),
            W(72176.7, 3.8593, -8.5139, -0.2419),
            W(73939.6, 3.9621, -7.9623, -0.2532),
            W(75859.6, 4.0430, -7.2996, -0.2634),
            W(77779.6, 4.0842, -6.5655, -0.2711),
            W(79699.6, 4.0749, -5.7506, -0.2754),
            W(81614.9, 3.9991, -4.8444, -0.2752),
            W(83534.9, 3.8302, -3.8248, -0.2686),
            W(85470.9, 3.5173, -2.6571, -0.2519),
            W(87390.9, 2.9620, -1.3223, -0.2178),
            W(89310.9, 1.8575, 0.2112, -0.1429),
            W(90890.1, -0.1991, 1.0130, 0.0087),
            W(91480.0, -1.0868, 0.6612, 0.0694),
            W(93288.8, -2.5405, -1.0363, 0.1667),
            W(94968.8, -3.2047, -2.4536, 0.2122),
            W(95208.8, -3.2772, -2.6414, 0.2173),
            W(100248.8, -4.2413, -6.0412, 0.2856),
            W(105288.8, -4.7288, -8.8143, 0.3220),
            W(110379.0, -5.0231, -11.2556, 0.3452),
            W(115419.0, -5.2056, -13.4325, 0.3608),
            W(120459.0, -5.3188, -15.4318, 0.3715),
            W(125499.0, -5.3836, -17.2914, 0.3789),
            W(130539.0, -5.4127, -19.0365, 0.3837),
            W(135579.0, -5.4144, -20.6852, 0.3866),
            W(140619.0, -5.3945, -22.2509, 0.3880),
            W(145659.0, -5.3570, -23.7439, 0.3881),
            W(150648.8, -5.3056, -25.1585, 0.3873),
            W(155623.9, -5.2426, -26.5123, 0.3855),
            W(160504.1, -5.1712, -27.7905, 0.3831),
            W(165544.1, -5.0888, -29.0633, 0.3799),
            W(170584.1, -4.9990, -30.2917, 0.3762),
            W(175624.1, -4.9025, -31.4792, 0.3720),
            W(180664.1, -4.8005, -32.6287, 0.3673),
            W(185704.1, -4.6934, -33.7426, 0.3623),
            W(190744.1, -4.5820, -34.8232, 0.3569),
            W(195784.1, -4.4668, -35.8724, 0.3512),
            W(199864.1, -4.3711, -36.7000, 0.3464),
            W(200104.1, -4.3654, -36.7481, 0.3461),
            W(209464.1, -4.1383, -38.5753, 0.3344),
            W(218824.1, -3.9031, -40.3135, 0.3221),
            W(228184.1, -3.6614, -41.9702, 0.3091),
            W(237544.1, -3.4148, -43.5515, 0.2957),
            W(246904.1, -3.1645, -45.0628, 0.2819),
            W(256264.1, -2.9117, -46.5087, 0.2678),
            W(265551.8, -2.6593, -47.8826, 0.2535),
            W(274911.8, -2.4042, -49.2092, 0.2389),
            W(284271.8, -2.1494, -50.4811, 0.2241),
            W(293631.8, -1.8956, -51.7011, 0.2092),
            W(302991.8, -1.6436, -52.8718, 0.1943),
            W(312351.8, -1.3944, -53.9955, 0.1794),
            W(321711.8, -1.1489, -55.0744, 0.1646),
            W(331071.8, -0.9082, -56.1105, 0.1498),
            W(340431.8, -0.6734, -57.1058, 0.1352),
            W(349791.8, -0.4462, -58.0619, 0.1207),
            W(359151.8, -0.2285, -58.9808, 0.1066),
            W(368511.8, -0.0228, -59.8641, 0.0928),
            W(369951.8, 0.0076, -59.9970, 0.0907),
            W(370191.8, 0.0126, -60.0190, 0.0904),
            W(373071.8, 0.0721, -60.2821, 0.0862),
            W(375951.8, 0.1299, -60.5421, 0.0821),
            W(378831.8, 0.1858, -60.7990, 0.0781),
            W(381711.8, 0.2397, -61.0530, 0.0741),
            W(384591.8, 0.2914, -61.3040, 0.0702),
            W(387471.8, 0.3405, -61.5521, 0.0663),
            W(390351.8, 0.3869, -61.7973, 0.0625),
            W(393231.8, 0.4302, -62.0398, 0.0588),
            W(396111.8, 0.4699, -62.2795, 0.0552),
            W(398991.8, 0.5056, -62.5166, 0.0516),
            W(401871.8, 0.5366, -62.7509, 0.0482),
            W(404751.8, 0.5621, -62.9825, 0.0448),
            W(407631.8, 0.5812, -63.2114, 0.0415),
            W(410511.8, 0.5925, -63.4373, 0.0384),
            W(413391.8, 0.5944, -63.6600, 0.0354),
            W(416271.8, 0.5844, -63.8788, 0.0324),
            W(419151.8, 0.5595, -64.0924, 0.0295),
            W(422031.8, 0.5150, -64.2986, 0.0265),
            W(424911.8, 0.4447, -64.4924, 0.0231),
            W(427791.8, 0.3402, -64.6637, 0.0188),
            W(430671.8, 0.1948, -64.7923, 0.0122),
            W(433551.8, 0.0156, -64.8478, 0.0012),
            W(436431.8, -0.1654, -64.8113, -0.0159),
            W(439311.8, -0.3148, -64.6998, -0.0383),
            W(442191.8, -0.4241, -64.5437, -0.0640),
            W(445071.8, -0.4993, -64.3638, -0.0915),
            W(447951.8, -0.5485, -64.1709, -0.1199),
            W(450831.8, -0.5781, -63.9699, -0.1489),
            W(453711.8, -0.5925, -63.7635, -0.1782),
            W(456591.8, -0.5952, -63.5530, -0.2076),
            W(459471.8, -0.5883, -63.3391, -0.2372),
            W(459951.8, -0.5864, -63.3031, -0.2421),
            W(460191.8, -0.5854, -63.2851, -0.2446),
            W(467871.8, -0.5285, -62.6982, -0.3237),
            W(475551.8, -0.4376, -62.0916, -0.4027),
            W(483231.8, -0.3230, -61.4651, -0.4815),
            W(490911.8, -0.1914, -60.8178, -0.5601),
            W(498591.8, -0.0467, -60.1488, -0.6384),
            W(506271.8, 0.1082, -59.4572, -0.7162),
            W(513951.8, 0.2713, -58.7421, -0.7937),
            W(521631.8, 0.4410, -58.0025, -0.8707),
            W(529311.8, 0.6161, -57.2375, -0.9472),
            W(536991.8, 0.7958, -56.4462, -1.0231),
            W(544671.8, 0.9791, -55.6277, -1.0985),
            W(552351.8, 1.1655, -54.7809, -1.1732),
            W(560031.8, 1.3543, -53.9048, -1.2472),
            W(567711.8, 1.5451, -52.9984, -1.3204),
            W(575391.8, 1.7374, -52.0605, -1.3927),
            W(583071.8, 1.9306, -51.0897, -1.4640),
            W(590751.8, 2.1245, -50.0849, -1.5343),
            W(598431.8, 2.3185, -49.0446, -1.6035),
            W(599871.8, 2.3549, -48.8455, -1.6163),
            W(600111.8, 2.3609, -48.8122, -1.6184),
            W(608271.8, 2.5667, -47.6572, -1.6901),
            W(616431.8, 2.7715, -46.4579, -1.7602),
            W(624591.8, 2.9749, -45.2118, -1.8284),
            W(632751.8, 3.1762, -43.9163, -1.8946),
            W(640911.8, 3.3748, -42.5686, -1.9584),
            W(649071.8, 3.5699, -41.1652, -2.0196),
            W(657231.8, 3.7607, -39.7024, -2.0778),
            W(665391.8, 3.9463, -38.1759, -2.1326),
            W(673551.8, 4.1254, -36.5806, -2.1835),
            W(681711.8, 4.2967, -34.9105, -2.2299),
            W(689871.8, 4.4585, -33.1587, -2.2710),
            W(698031.8, 4.6086, -31.3167, -2.3058),
            W(706191.8, 4.7443, -29.3742, -2.3332),
            W(714351.8, 4.8620, -27.3181, -2.3515),
            W(722511.8, 4.9567, -25.1319, -2.3585),
            W(730671.8, 5.0217, -22.7937, -2.3511),
            W(738831.8, 5.0464, -20.2733, -2.3248),
            W(746991.8, 5.0148, -17.5270, -2.2724),
            W(749871.8, 4.9854, -16.4923, -2.2456),
            W(750111.8, 4.9824, -16.4043, -2.2432),
            W(751311.8, 4.9663, -15.9601, -2.2302),
            W(752511.8, 4.9478, -15.5085, -2.2163),
            W(753711.8, 4.9269, -15.0491, -2.2012),
            W(754911.8, 4.9033, -14.5815, -2.1849),
            W(756111.8, 4.8768, -14.1054, -2.1673),
            W(757311.8, 4.8471, -13.6201, -2.1484),
            W(758511.8, 4.8140, -13.1251, -2.1279),
            W(759711.8, 4.7771, -12.6198, -2.1057),
            W(760911.8, 4.7361, -12.1035, -2.0817),
            W(762111.8, 4.6904, -11.5754, -2.0556),
            W(763311.8, 4.6396, -11.0346, -2.0273),
            W(764511.8, 4.5830, -10.4802, -1.9965),
            W(765711.8, 4.5199, -9.9108, -1.9629),
            W(766911.8, 4.4495, -9.3253, -1.9260),
            W(768111.8, 4.3704, -8.7218, -1.8854),
            W(769311.8, 4.2815, -8.0986, -1.8406),
            W(770511.8, 4.1809, -7.4533, -1.7907),
            W(771711.8, 4.0662, -6.7832, -1.7348),
            W(772911.8, 3.9345, -6.0845, -1.6717),
            W(774111.8, 3.7814, -5.3530, -1.5994),
            W(775311.8, 3.6007, -4.5825, -1.5155),
            W(776511.8, 3.3829, -3.7652, -1.4160),
            W(777711.8, 3.1124, -2.8900, -1.2944),
            W(778911.8, 2.7607, -1.9409, -1.1390),
            W(780111.8, 2.2665, -0.8966, -0.9249),
            W(781111.7, 1.6318, 0.0527, -0.6556),
            W(781997.2, 0.6772, 0.8364, -0.2600),
            W(782237.2, 0.3203, 0.9643, -0.1145),
        ]

        wp.append(contentsOf: oemWaypoints)
        return wp
    }()
}
