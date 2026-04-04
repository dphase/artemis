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
    private let glowNodes: [SCNNode] = (0..<10).map { _ in SCNNode() }

    // Future path (grey line showing where spacecraft will go)
    private let futurePathNode = SCNNode()
    private let futurePathNode2 = SCNNode()

    /// How many points of trail to show behind the spacecraft.
    private let trailLength = 100

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
            SCNVector3(0.015, 0.015, 0.015),
            SCNVector3(-0.015, -0.015, -0.015),
            SCNVector3(0.025, -0.01, 0.015),
            SCNVector3(-0.01, 0.025, -0.015),
        ]
        let coreNodes = [trailNode, trailNode2, trailNode3, trailNode4, trailNode5]
        for (i, cn) in coreNodes.enumerated() {
            cn.name = "trail\(i)"
            cn.position = coreOffsets[i]
            node.addChildNode(cn)
        }

        // Glow layers at varying distances for soft blur effect
        let glowOffsets: [SCNVector3] = [
            SCNVector3(0.08, 0.08, 0.08),
            SCNVector3(-0.08, -0.08, -0.08),
            SCNVector3(0.08, -0.08, 0.0),
            SCNVector3(-0.08, 0.08, 0.0),
            SCNVector3(0.0, 0.08, -0.08),
            SCNVector3(0.0, -0.08, 0.08),
            SCNVector3(0.14, 0.14, 0.0),
            SCNVector3(-0.14, -0.14, 0.0),
            SCNVector3(0.0, 0.14, 0.14),
            SCNVector3(0.0, -0.14, -0.14),
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
            let traveledColor = UIColor(white: 0.55, alpha: 0.4)

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
            let futureColor = UIColor(white: 0.55, alpha: 0.4)

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

    /// Trail gradient: purple at spacecraft -> pink -> orange fading out at tail.
    private func createTrailGeometry(from points: [SCNVector3], isGlow: Bool) -> SCNGeometry? {
        guard points.count >= 2 else { return nil }

        let source = SCNGeometrySource(vertices: points)

        var colors: [SIMD4<Float>] = []
        colors.reserveCapacity(points.count)
        for i in 0..<points.count {
            let t = Float(i) / Float(points.count - 1)
            let alpha = t * t * (isGlow ? 0.25 : 1.0)

            let r: Float
            let g: Float
            let b: Float
            let u = 1.0 - t

            if u < 0.3 {
                let s = u / 0.3
                r = 0.5 + 0.35 * s
                g = 0.1 + 0.1 * s
                b = 0.8 - 0.25 * s
            } else if u < 0.6 {
                let s = (u - 0.3) / 0.3
                r = 0.85 + 0.15 * s
                g = 0.2 + 0.2 * s
                b = 0.55 - 0.3 * s
            } else {
                let s = (u - 0.6) / 0.4
                r = 1.0
                g = 0.4 + 0.2 * s
                b = 0.25 - 0.15 * s
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
