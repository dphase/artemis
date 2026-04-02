import SceneKit

final class TrajectoryPathNode {

    let node: SCNNode
    private let trajectoryPoints: [SCNVector3]
    private let pastPathNode = SCNNode()
    private let futurePathNode = SCNNode()
    // Duplicate layers offset slightly for visual line thickening
    private let pastPathNode2 = SCNNode()
    private let futurePathNode2 = SCNNode()
    private let lineOffset = SCNVector3(0.015, 0.015, 0.015)

    init(pointCount: Int = 1200) {
        node = SCNNode()
        node.name = "Trajectory"

        trajectoryPoints = TrajectoryInterpolator.trajectoryPoints(count: pointCount)

        pastPathNode.name = "pastPath"
        futurePathNode.name = "futurePath"
        pastPathNode2.name = "pastPath2"
        futurePathNode2.name = "futurePath2"
        pastPathNode2.position = lineOffset
        futurePathNode2.position = lineOffset
        node.addChildNode(pastPathNode)
        node.addChildNode(futurePathNode)
        node.addChildNode(pastPathNode2)
        node.addChildNode(futurePathNode2)

        updateProgress(0)
    }

    func updateProgress(_ parameter: Double) {
        guard !trajectoryPoints.isEmpty else { return }

        let clampedParameter = min(max(parameter, 0), 1)
        let splitIndex = Int(Double(trajectoryPoints.count - 1) * clampedParameter)

        if splitIndex > 0 {
            let pastPoints = Array(trajectoryPoints[0...splitIndex])
            let geo = createFadingLineGeometry(from: pastPoints)

            let pastMaterial = SCNMaterial()
            pastMaterial.lightingModel = .constant
            pastPathNode.geometry = geo
            pastPathNode.geometry?.materials = [pastMaterial]

            // Duplicate for thickness
            let geo2 = createFadingLineGeometry(from: pastPoints)
            let pastMaterial2 = SCNMaterial()
            pastMaterial2.lightingModel = .constant
            pastPathNode2.geometry = geo2
            pastPathNode2.geometry?.materials = [pastMaterial2]
        } else {
            pastPathNode.geometry = nil
            pastPathNode2.geometry = nil
        }

        if splitIndex < trajectoryPoints.count - 1 {
            let futurePoints = Array(trajectoryPoints[splitIndex...])

            let futureMaterial = SCNMaterial()
            futureMaterial.diffuse.contents = UIColor(red: 0.75, green: 0.72, blue: 0.55, alpha: 0.5)
            futureMaterial.lightingModel = .constant
            futurePathNode.geometry = createLineGeometry(from: futurePoints)
            futurePathNode.geometry?.materials = [futureMaterial]

            // Duplicate for thickness
            let futureMaterial2 = SCNMaterial()
            futureMaterial2.diffuse.contents = UIColor(red: 0.75, green: 0.72, blue: 0.55, alpha: 0.5)
            futureMaterial2.lightingModel = .constant
            futurePathNode2.geometry = createLineGeometry(from: futurePoints)
            futurePathNode2.geometry?.materials = [futureMaterial2]
        } else {
            futurePathNode.geometry = nil
            futurePathNode2.geometry = nil
        }
    }

    private func createFadingLineGeometry(from points: [SCNVector3]) -> SCNGeometry? {
        guard points.count >= 2 else { return nil }

        let source = SCNGeometrySource(vertices: points)

        // Per-vertex colors: fade from dim at start to bright magenta at end (spacecraft)
        var colors: [SIMD4<Float>] = []
        colors.reserveCapacity(points.count)
        for i in 0..<points.count {
            let t = Float(i) / Float(points.count - 1)
            let alpha = t * t // quadratic fade-in
            let bright = max(alpha, 0.15) // minimum brightness so trail is more visible
            colors.append(SIMD4<Float>(0.9 * bright, 0.2 * bright, 0.6 * bright, bright))
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
