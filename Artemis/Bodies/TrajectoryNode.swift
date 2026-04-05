import SceneKit

final class TrajectoryPathNode {

    let node: SCNNode
    private let trajectoryPoints: [SCNVector3]

    // Traveled path (grey line showing where spacecraft has been)
    private let traveledPathNode = SCNNode()
    private let traveledPathNode2 = SCNNode()

    // Core trail layers near spacecraft
    private let trailNode = SCNNode()
    private let trailNode2 = SCNNode()
    private let trailNode3 = SCNNode()
    private let trailNode4 = SCNNode()
    private let trailNode5 = SCNNode()

    // Glow/blur layers (multiple at varying offsets for soft bloom)
    private let glowNodes: [SCNNode] = (0..<14).map { _ in SCNNode() }

    // Future path (grey line showing where spacecraft will go)
    private let futurePathNode = SCNNode()
    private let futurePathNode2 = SCNNode()

    /// How many points of trail to show behind the spacecraft.
    private let trailLength = 115

    init(pointCount: Int = 1200) {
        node = SCNNode()
        node.name = "Trajectory"

        trajectoryPoints = TrajectoryInterpolator.trajectoryPoints(count: pointCount)

        let lo = SCNVector3(0.015, 0.015, 0.015)

        // Traveled path
        traveledPathNode.name = "traveledPath"
        traveledPathNode2.name = "traveledPath2"
        traveledPathNode2.position = lo
        node.addChildNode(traveledPathNode)
        node.addChildNode(traveledPathNode2)

        // Core trail layers (5 offsets for solid thickness)
        let coreOffsets: [SCNVector3] = [
            SCNVector3(0, 0, 0),
            SCNVector3(0.02, 0.02, 0.02),
            SCNVector3(-0.02, -0.02, -0.02),
            SCNVector3(0.03, -0.01, 0.02),
            SCNVector3(-0.01, 0.03, -0.02),
        ]
        let coreNodes = [trailNode, trailNode2, trailNode3, trailNode4, trailNode5]
        for (i, cn) in coreNodes.enumerated() {
            cn.name = "trail\(i)"
            cn.position = coreOffsets[i]
            node.addChildNode(cn)
        }

        // Glow layers — very tight offsets to avoid visible parallel lines when zoomed in
        let glowOffsets: [SCNVector3] = [
            // Inner ring (6 directions)
            SCNVector3( 0.025,  0.025,  0.025),
            SCNVector3(-0.025, -0.025, -0.025),
            SCNVector3( 0.025, -0.025,  0.0),
            SCNVector3(-0.025,  0.025,  0.0),
            SCNVector3( 0.0,    0.025, -0.025),
            SCNVector3( 0.0,   -0.025,  0.025),
            // Outer ring (8 directions)
            SCNVector3( 0.045,  0.045,  0.0),
            SCNVector3(-0.045, -0.045,  0.0),
            SCNVector3( 0.0,    0.045,  0.045),
            SCNVector3( 0.0,   -0.045, -0.045),
            SCNVector3( 0.045,  0.0,   -0.045),
            SCNVector3(-0.045,  0.0,    0.045),
            SCNVector3( 0.035,  0.035,  0.035),
            SCNVector3(-0.035, -0.035, -0.035),
        ]
        for (i, gn) in glowNodes.enumerated() {
            gn.name = "glow\(i)"
            gn.position = glowOffsets[i]
            node.addChildNode(gn)
        }

        // Future path
        futurePathNode.name = "futurePath"
        futurePathNode2.name = "futurePath2"
        futurePathNode2.position = lo
        node.addChildNode(futurePathNode)
        node.addChildNode(futurePathNode2)

        updateProgress(0)
    }

    func updateProgress(_ parameter: Double) {
        guard !trajectoryPoints.isEmpty else { return }

        let clampedParameter = min(max(parameter, 0), 1)
        let splitIndex = Int(Double(trajectoryPoints.count - 1) * clampedParameter)

        // --- Traveled path: full route from origin to current position ---
        if splitIndex > 0 {
            let traveledPoints = Array(trajectoryPoints[0...splitIndex])
            let traveledColor = UIColor(red: 0.72, green: 0.69, blue: 0.52, alpha: 0.46)

            for tn in [traveledPathNode, traveledPathNode2] {
                let mat = SCNMaterial()
                mat.diffuse.contents = traveledColor
                mat.lightingModel = .constant
                tn.geometry = createLineGeometry(from: traveledPoints)
                tn.geometry?.materials = [mat]
            }
        } else {
            traveledPathNode.geometry = nil
            traveledPathNode2.geometry = nil
        }

        // --- Hot trail: partial gradient near spacecraft ---
        if splitIndex > 0 {
            let trailStart = max(0, splitIndex - trailLength)
            let trailPoints = Array(trajectoryPoints[trailStart...splitIndex])

            for cn in [trailNode, trailNode2, trailNode3, trailNode4, trailNode5] {
                let geo = createTrailGeometry(from: trailPoints, isGlow: false)
                let mat = SCNMaterial()
                mat.lightingModel = .constant
                cn.geometry = geo
                cn.geometry?.materials = [mat]
            }

            for gn in glowNodes {
                let geo = createTrailGeometry(from: trailPoints, isGlow: true)
                let mat = SCNMaterial()
                mat.lightingModel = .constant
                gn.geometry = geo
                gn.geometry?.materials = [mat]
            }
        } else {
            for cn in [trailNode, trailNode2, trailNode3, trailNode4, trailNode5] {
                cn.geometry = nil
            }
            for gn in glowNodes {
                gn.geometry = nil
            }
        }

        // --- Future path: grey from current to end ---
        if splitIndex < trajectoryPoints.count - 1 {
            let futurePoints = Array(trajectoryPoints[splitIndex...])
            let futureColor = UIColor(red: 0.72, green: 0.69, blue: 0.52, alpha: 0.46)

            for fn in [futurePathNode, futurePathNode2] {
                let mat = SCNMaterial()
                mat.diffuse.contents = futureColor
                mat.lightingModel = .constant
                fn.geometry = createLineGeometry(from: futurePoints)
                fn.geometry?.materials = [mat]
            }
        } else {
            futurePathNode.geometry = nil
            futurePathNode2.geometry = nil
        }
    }

    /// Trail gradient: bright magenta at spacecraft -> purple -> orange -> yellow -> black at tail.
    private func createTrailGeometry(from points: [SCNVector3], isGlow: Bool) -> SCNGeometry? {
        guard points.count >= 2 else { return nil }

        let source = SCNGeometrySource(vertices: points)

        var colors: [SIMD4<Float>] = []
        colors.reserveCapacity(points.count)
        for i in 0..<points.count {
            // t=0 at tail, t=1 at head (spacecraft)
            let t = Float(i) / Float(points.count - 1)
            let alpha = t * t * (isGlow ? 0.25 : 1.0)

            let r: Float
            let g: Float
            let b: Float

            if t < 0.15 {
                // Black → Yellow
                let s = t / 0.15
                r = 1.0 * s
                g = 0.85 * s
                b = 0.2 * s
            } else if t < 0.35 {
                // Yellow → Orange
                let s = (t - 0.15) / 0.2
                r = 1.0
                g = 0.85 - 0.35 * s   // 0.85 → 0.5
                b = 0.2 - 0.1 * s     // 0.2 → 0.1
            } else if t < 0.65 {
                // Orange → Purple
                let s = (t - 0.35) / 0.3
                r = 1.0 - 0.4 * s     // 1.0 → 0.6
                g = 0.5 - 0.35 * s    // 0.5 → 0.15
                b = 0.1 + 0.7 * s     // 0.1 → 0.8
            } else {
                // Purple → Bright Magenta
                let s = (t - 0.65) / 0.35
                r = 0.6 + 0.4 * s     // 0.6 → 1.0
                g = 0.15 + 0.05 * s   // 0.15 → 0.2
                b = 0.8 - 0.2 * s     // 0.8 → 0.6
            }

            colors.append(SIMD4<Float>(r * alpha, g * alpha, b * alpha, alpha))
        }

        let colorData = Data(bytes: colors, count: colors.count * MemoryLayout<SIMD4<Float>>.stride)
        let colorSource = SCNGeometrySource(
            data: colorData,
            semantic: .color,
            vectorCount: colors.count,
            usesFloatComponents: true,
            componentsPerVector: 4,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<SIMD4<Float>>.stride
        )

        var indices: [UInt32] = []
        indices.reserveCapacity((points.count - 1) * 2)
        for i in 0..<(points.count - 1) {
            indices.append(UInt32(i))
            indices.append(UInt32(i + 1))
        }

        let element = SCNGeometryElement(indices: indices, primitiveType: .line)
        return SCNGeometry(sources: [source, colorSource], elements: [element])
    }

    private func createLineGeometry(from points: [SCNVector3]) -> SCNGeometry? {
        guard points.count >= 2 else { return nil }

        let source = SCNGeometrySource(vertices: points)

        var indices: [UInt32] = []
        indices.reserveCapacity((points.count - 1) * 2)
        for i in 0..<(points.count - 1) {
            indices.append(UInt32(i))
            indices.append(UInt32(i + 1))
        }

        let element = SCNGeometryElement(
            indices: indices,
            primitiveType: .line
        )

        return SCNGeometry(sources: [source], elements: [element])
    }
}
