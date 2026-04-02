import SceneKit

final class TrajectoryNode: SCNNode {

    // MARK: - Properties

    private var trajectoryPoints: [SCNVector3] = []
    private let pastPathNode = SCNNode()
    private let futurePathNode = SCNNode()

    // MARK: - Convenience Init

    convenience init(pointCount: Int = 1200) {
        self.init()
        name = "Trajectory"

        let points = TrajectoryInterpolator.trajectoryPoints(count: pointCount)
        self.trajectoryPoints = points

        pastPathNode.name = "pastPath"
        futurePathNode.name = "futurePath"
        addChildNode(pastPathNode)
        addChildNode(futurePathNode)

        // Start with the full path shown as future
        updateProgress(0)
    }

    // MARK: - Public API

    /// Updates the past/future trajectory split.
    /// - Parameter parameter: A value in 0...1 representing mission progress.
    func updateProgress(_ parameter: Double) {
        let clampedParameter = min(max(parameter, 0), 1)
        let splitIndex = Int(Double(trajectoryPoints.count - 1) * clampedParameter)

        // Past path: from start through the split point (inclusive)
        if splitIndex > 0 {
            let pastPoints = Array(trajectoryPoints[0...splitIndex])
            pastPathNode.geometry = createLineGeometry(from: pastPoints)

            let pastMaterial = SCNMaterial()
            pastMaterial.name = "pastTrajectory"
            pastMaterial.diffuse.contents = UIColor(red: 0.5, green: 0.3, blue: 0.8, alpha: 0.6)
            pastMaterial.lightingModel = .constant
            pastPathNode.geometry?.materials = [pastMaterial]
        } else {
            pastPathNode.geometry = nil
        }

        // Future path: from split point to end
        if splitIndex < trajectoryPoints.count - 1 {
            let futurePoints = Array(trajectoryPoints[splitIndex...])
            futurePathNode.geometry = createLineGeometry(from: futurePoints)

            let futureMaterial = SCNMaterial()
            futureMaterial.name = "futureTrajectory"
            futureMaterial.diffuse.contents = UIColor(white: 0.5, alpha: 0.3)
            futureMaterial.lightingModel = .constant
            futurePathNode.geometry?.materials = [futureMaterial]
        } else {
            futurePathNode.geometry = nil
        }
    }

    // MARK: - Helpers

    /// Creates a line-strip geometry from an array of points.
    private func createLineGeometry(from points: [SCNVector3]) -> SCNGeometry? {
        guard points.count >= 2 else { return nil }

        // Vertex positions
        let source = SCNGeometrySource(vertices: points)

        // Line-strip indices as pairs: [0,1, 1,2, 2,3, ...]
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
