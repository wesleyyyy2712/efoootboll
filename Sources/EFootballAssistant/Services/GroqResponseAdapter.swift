import Foundation

public struct GroqRealVisionResponse: Codable, Sendable {
    public var visiblePlayersCount: Int?
    public var ballVisible: Bool?
    public var freeSpaceVisible: Bool?
    public var gameContext: String?
    public var confidence: Double?
    public var recommendation: String?

    enum CodingKeys: String, CodingKey {
        case visiblePlayersCount = "visible_players_count"
        case ballVisible = "ball_visible"
        case freeSpaceVisible = "free_space_visible"
        case gameContext = "game_context"
        case confidence
        case recommendation
    }

    public init(visiblePlayersCount: Int? = nil, ballVisible: Bool? = nil, freeSpaceVisible: Bool? = nil, gameContext: String? = nil, confidence: Double? = nil, recommendation: String? = nil) {
        self.visiblePlayersCount = visiblePlayersCount
        self.ballVisible = ballVisible
        self.freeSpaceVisible = freeSpaceVisible
        self.gameContext = gameContext
        self.confidence = confidence
        self.recommendation = recommendation
    }
}

public enum GroqResponseAdapter {
    public static func decode(_ data: Data) throws -> GroqRealVisionResponse {
        try JSONDecoder().decode(GroqRealVisionResponse.self, from: data)
    }

    /// Decodes either the detailed coordinate schema or the summary schema returned by the real Groq probe.
    public static func visionResult(from data: Data) throws -> VisionAIResult {
        let object = try JSONSerialization.jsonObject(with: data)
        if let fields = object as? [String: Any],
           fields.keys.contains(where: { ["visible_players_count", "ball_visible", "free_space_visible"].contains($0) }) {
            let response = try decode(data)
            return visionResult(from: frameAnalysis(from: response, timestamp: 0))
        }
        return try JSONDecoder().decode(VisionAIResult.self, from: data)
    }

    public static func frameAnalysis(from response: GroqRealVisionResponse, timestamp: TimeInterval) -> FrameAnalysis {
        let context: GameContext
        switch response.gameContext?.lowercased() {
        case "attack": context = .attack
        case "defense": context = .defense
        case "transition": context = .transition
        default: context = .unknown
        }

        let receivedRecommendation = response.recommendation.flatMap { text -> RecommendationPayload? in
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return RecommendationPayload(type: .none, priority: .medium, message: text)
        }
        // The real probe returned counts/flags rather than coordinates. Preserve observations without fabricating positions.
        return FrameAnalysis(
            timestamp: timestamp,
            controlledPlayer: nil,
            teammates: [],
            opponents: [],
            ball: nil,
            freeSpaces: [],
            context: context,
            confidence: response.confidence ?? 0,
            recommendation: receivedRecommendation,
            observedPlayersCount: response.visiblePlayersCount ?? 0,
            ballObserved: response.ballVisible ?? false,
            freeSpacesObserved: (response.freeSpaceVisible ?? false) ? 1 : 0
        )
    }

    private static func visionResult(from analysis: FrameAnalysis) -> VisionAIResult {
        VisionAIResult(
            ball: analysis.ball,
            controlledPlayer: analysis.controlledPlayer,
            teammates: analysis.teammates,
            opponents: analysis.opponents,
            freeSpaces: analysis.freeSpaces,
            gameContext: analysis.context,
            confidence: analysis.confidence,
            recommendation: analysis.recommendation,
            observedPlayersCount: analysis.observedPlayersCount,
            ballObserved: analysis.ballObserved,
            freeSpacesObserved: analysis.freeSpacesObserved
        )
    }
}

public extension VisionAIResult {
    func frameAnalysis(timestamp: TimeInterval) -> FrameAnalysis {
        FrameAnalysis(
            timestamp: timestamp,
            controlledPlayer: controlledPlayer,
            teammates: teammates,
            opponents: opponents,
            ball: ball,
            freeSpaces: freeSpaces,
            context: gameContext,
            confidence: confidence,
            recommendation: recommendation,
            observedPlayersCount: observedPlayersCount,
            ballObserved: ballObserved,
            freeSpacesObserved: freeSpacesObserved
        )
    }
}
