import Foundation

public struct Point2D: Codable, Equatable, Sendable { public var x: Double; public var y: Double; public init(x: Double, y: Double) { self.x = x; self.y = y } }
public struct BoundingBox: Codable, Equatable, Sendable { public var x: Double; public var y: Double; public var width: Double; public var height: Double; public init(x: Double, y: Double, width: Double, height: Double) { self.x = x; self.y = y; self.width = width; self.height = height } }
public struct FreeSpace: Codable, Equatable, Sendable { public var center: Point2D; public var size: Double; public var direction: String; public var confidence: Double; public init(center: Point2D, size: Double, direction: String, confidence: Double) { self.center = center; self.size = size; self.direction = direction; self.confidence = confidence } }
public enum Team: String, Codable, Sendable { case user, opponent }
public struct PlayerObservation: Codable, Equatable, Sendable { public var id: UUID; public var position: Point2D; public var boundingBox: BoundingBox?; public var team: Team; public var confidence: Double; public var isFree: Bool; public var velocity: Point2D?; public init(id: UUID = UUID(), position: Point2D, team: Team, boundingBox: BoundingBox? = nil, confidence: Double = 1, isFree: Bool = false, velocity: Point2D? = nil) { self.id = id; self.position = position; self.team = team; self.boundingBox = boundingBox; self.confidence = confidence; self.isFree = isFree; self.velocity = velocity } }
public enum GameContext: String, Codable, Sendable { case attack, defense, transition, unknown }
public enum RecommendationType: String, Codable, Sendable { case forwardPass = "forward_pass", lateralSpace = "lateral_space", pressureWarning = "pressure_warning", recover, none }
public struct RecommendationPayload: Codable, Equatable, Sendable { public var type: RecommendationType; public var priority: RecommendationPriority; public var message: String; public init(type: RecommendationType, priority: RecommendationPriority, message: String) { self.type = type; self.priority = priority; self.message = message } }
public struct FrameAnalysis: Codable, Equatable, Sendable {
    public var timestamp: TimeInterval
    public var controlledPlayer: PlayerObservation?
    public var teammates: [PlayerObservation]
    public var opponents: [PlayerObservation]
    public var ball: Point2D?
    public var freeSpaces: [FreeSpace]
    public var context: GameContext
    public var confidence: Double
    public var recommendation: RecommendationPayload?
    public var observedPlayersCount: Int
    public var ballObserved: Bool
    public var freeSpacesObserved: Int
    public init(timestamp: TimeInterval, controlledPlayer: PlayerObservation?, teammates: [PlayerObservation] = [], opponents: [PlayerObservation] = [], ball: Point2D? = nil, freeSpaces: [FreeSpace] = [], context: GameContext = .unknown, confidence: Double = 0, recommendation: RecommendationPayload? = nil, observedPlayersCount: Int? = nil, ballObserved: Bool? = nil, freeSpacesObserved: Int? = nil) { self.timestamp = timestamp; self.controlledPlayer = controlledPlayer; self.teammates = teammates; self.opponents = opponents; self.ball = ball; self.freeSpaces = freeSpaces; self.context = context; self.confidence = confidence; self.recommendation = recommendation; self.observedPlayersCount = observedPlayersCount ?? teammates.count + opponents.count; self.ballObserved = ballObserved ?? (ball != nil); self.freeSpacesObserved = freeSpacesObserved ?? freeSpaces.count }
}
public enum RecommendationPriority: Int, Codable, Comparable, Sendable { case low = 1, medium = 2, high = 3; public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue } }
public struct Recommendation: Codable, Equatable, Sendable { public var text: String; public var priority: RecommendationPriority; public var createdAt: Date; public init(text: String, priority: RecommendationPriority) { self.text = text; self.priority = priority; self.createdAt = Date() } }
public struct AIRequest: Codable, Sendable { public var analysis: FrameAnalysis; public init(analysis: FrameAnalysis) { self.analysis = analysis } }
public struct AppSettings: Codable, Sendable { public var voiceEnabled = true; public var voiceRate: Float = 0.48; public var volume: Float = 1; public var language = "pt-BR"; public var frequency = "balanced"; public var sensitivity = 0.65; public var economyMode = false; public var analysisQuality = "balanced"; public init() {} }
