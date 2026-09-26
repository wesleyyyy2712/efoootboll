import Foundation

public struct Detection: Sendable, Codable { public var id: UUID; public var team: Team?; public var boundingBox: BoundingBox; public var confidence: Double; public init(id: UUID = UUID(), team: Team?, boundingBox: BoundingBox, confidence: Double) { self.id = id; self.team = team; self.boundingBox = boundingBox; self.confidence = confidence } }
public protocol ObjectDetector: Sendable { func detect(imageData: Data) async throws -> [Detection] }
public struct DetectorConfiguration: Sendable { public var playerModelIdentifier: String?; public var ballModelIdentifier: String?; public var confidenceThreshold: Double; public init(playerModelIdentifier: String? = nil, ballModelIdentifier: String? = nil, confidenceThreshold: Double = 0.5) { self.playerModelIdentifier = playerModelIdentifier; self.ballModelIdentifier = ballModelIdentifier; self.confidenceThreshold = confidenceThreshold } }

public actor TemporalTracker {
    private var previous: [UUID: (position: Point2D, time: TimeInterval)] = [:]
    public init() {}
    public func update(detections: [Detection], timestamp: TimeInterval) -> [PlayerObservation] {
        var output: [PlayerObservation] = []
        for detection in detections {
            let center = Point2D(x: detection.boundingBox.x + detection.boundingBox.width / 2, y: detection.boundingBox.y + detection.boundingBox.height / 2)
            let velocity: Point2D? = previous[detection.id].map { old in
                let dt = max(timestamp - old.time, 0.001)
                return Point2D(x: (center.x - old.position.x) / dt, y: (center.y - old.position.y) / dt)
            }
            previous[detection.id] = (center, timestamp)
            output.append(PlayerObservation(id: detection.id, position: center, boundingBox: detection.boundingBox, team: detection.team ?? .opponent, confidence: detection.confidence, isFree: false, velocity: velocity))
        }
        return output
    }
}

public struct SpaceEstimator: Sendable {
    public init() {}
    public func estimate(players: [PlayerObservation], fieldPadding: Double = 0.05) -> [FreeSpace] {
        let grid = stride(from: fieldPadding, through: 1 - fieldPadding, by: 0.1)
        var spaces: [FreeSpace] = []
        for y in grid { for x in grid {
            let point = Point2D(x: x, y: y)
            let nearest = players.map { hypot($0.position.x - x, $0.position.y - y) }.min() ?? 1
            if nearest > 0.12 {
                let direction = x > 0.6 ? "right" : (x < 0.4 ? "left" : "middle")
                spaces.append(FreeSpace(center: point, size: nearest, direction: direction, confidence: min(1, nearest * 3)))
            }
        } }
        return spaces
    }
}
