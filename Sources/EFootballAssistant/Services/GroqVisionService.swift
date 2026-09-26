import Foundation

public struct VisionAIResult: Codable, Sendable {
    public var ball: Point2D?
    public var controlledPlayer: PlayerObservation?
    public var teammates: [PlayerObservation]
    public var opponents: [PlayerObservation]
    public var freeSpaces: [FreeSpace]
    public var gameContext: GameContext
    public var confidence: Double
    public var recommendation: RecommendationPayload?
    public var observedPlayersCount: Int
    public var ballObserved: Bool
    public var freeSpacesObserved: Int

    public init(
        ball: Point2D? = nil,
        controlledPlayer: PlayerObservation? = nil,
        teammates: [PlayerObservation] = [],
        opponents: [PlayerObservation] = [],
        freeSpaces: [FreeSpace] = [],
        gameContext: GameContext = .unknown,
        confidence: Double = 0,
        recommendation: RecommendationPayload? = nil,
        observedPlayersCount: Int? = nil,
        ballObserved: Bool? = nil,
        freeSpacesObserved: Int? = nil
    ) {
        self.ball = ball
        self.controlledPlayer = controlledPlayer
        self.teammates = teammates
        self.opponents = opponents
        self.freeSpaces = freeSpaces
        self.gameContext = gameContext
        self.confidence = confidence
        self.recommendation = recommendation
        self.observedPlayersCount = observedPlayersCount ?? teammates.count + opponents.count + (controlledPlayer == nil ? 0 : 1)
        self.ballObserved = ballObserved ?? (ball != nil)
        self.freeSpacesObserved = freeSpacesObserved ?? freeSpaces.count
    }

    private enum CodingKeys: String, CodingKey {
        case ball, controlledPlayer, teammates, opponents, freeSpaces, gameContext, confidence, recommendation
        case observedPlayersCount, ballObserved, freeSpacesObserved
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        ball = try values.decodeIfPresent(Point2D.self, forKey: .ball)
        controlledPlayer = try values.decodeIfPresent(PlayerObservation.self, forKey: .controlledPlayer)
        teammates = try values.decodeIfPresent([PlayerObservation].self, forKey: .teammates) ?? []
        opponents = try values.decodeIfPresent([PlayerObservation].self, forKey: .opponents) ?? []
        freeSpaces = try values.decodeIfPresent([FreeSpace].self, forKey: .freeSpaces) ?? []
        gameContext = try values.decodeIfPresent(GameContext.self, forKey: .gameContext) ?? .unknown
        confidence = try values.decodeIfPresent(Double.self, forKey: .confidence) ?? 0
        recommendation = try values.decodeIfPresent(RecommendationPayload.self, forKey: .recommendation)
        observedPlayersCount = try values.decodeIfPresent(Int.self, forKey: .observedPlayersCount)
            ?? teammates.count + opponents.count + (controlledPlayer == nil ? 0 : 1)
        ballObserved = try values.decodeIfPresent(Bool.self, forKey: .ballObserved) ?? (ball != nil)
        freeSpacesObserved = try values.decodeIfPresent(Int.self, forKey: .freeSpacesObserved) ?? freeSpaces.count
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encodeIfPresent(ball, forKey: .ball)
        try values.encodeIfPresent(controlledPlayer, forKey: .controlledPlayer)
        try values.encode(teammates, forKey: .teammates)
        try values.encode(opponents, forKey: .opponents)
        try values.encode(freeSpaces, forKey: .freeSpaces)
        try values.encode(gameContext, forKey: .gameContext)
        try values.encode(confidence, forKey: .confidence)
        try values.encodeIfPresent(recommendation, forKey: .recommendation)
        try values.encode(observedPlayersCount, forKey: .observedPlayersCount)
        try values.encode(ballObserved, forKey: .ballObserved)
        try values.encode(freeSpacesObserved, forKey: .freeSpacesObserved)
    }
}

public protocol VisionAIProvider: Sendable {
    func analyze(imageData: Data, mimeType: String) async throws -> VisionAIResult
}

public actor GroqVisionService: VisionAIProvider {
    public struct Configuration: Sendable {
        public var apiKey: String
        public var endpoint: URL
        public var model: String
        public var timeout: TimeInterval

        public init(apiKey: String, endpoint: URL = URL(string: "https://api.groq.com/openai/v1/chat/completions")!, model: String = "qwen/qwen3.8-27b", timeout: TimeInterval = 20) {
            self.apiKey = apiKey
            self.endpoint = endpoint
            self.model = model
            self.timeout = timeout
        }
    }

    private let config: Configuration
    private let session: URLSession

    public init(configuration: Configuration, session: URLSession = .shared) {
        self.config = configuration
        self.session = session
    }

    public func analyze(imageData: Data, mimeType: String = "image/jpeg") async throws -> VisionAIResult {
        let encoded = imageData.base64EncodedString()
        let prompt = "Analyze this eFootball gameplay screenshot. Return ONLY valid JSON matching this schema: {\"ball\":{\"x\":0,\"y\":0}|null,\"controlledPlayer\":{\"position\":{\"x\":0,\"y\":0},\"boundingBox\":{\"x\":0,\"y\":0,\"width\":0,\"height\":0},\"team\":\"user\",\"confidence\":0,\"isFree\":false}|null,\"teammates\":[],\"opponents\":[],\"freeSpaces\":[],\"gameContext\":\"attack|defense|transition|unknown\",\"confidence\":0,\"recommendation\":{\"type\":\"forward_pass|lateral_space|pressure_warning|recover|none\",\"priority\":1,\"message\":\"\"}|null}. Coordinates must be normalized 0..1. Do not invent objects not visible; use null/empty arrays."
        let body: [String: Any] = [
            "model": config.model,
            "temperature": 0,
            "max_completion_tokens": 900,
            "response_format": ["type": "json_object"],
            "messages": [["role": "user", "content": [["type": "text", "text": prompt], ["type": "image_url", "image_url": ["url": "data:\(mimeType);base64,\(encoded)"]]]]]
        ]
        var request = URLRequest(url: config.endpoint, timeoutInterval: config.timeout)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("eFootballAssistant/1.0", forHTTPHeaderField: "User-Agent")

        let (responseData, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let envelope = try JSONDecoder().decode(GroqEnvelope.self, from: responseData)
        guard let content = envelope.choices.first?.message.content, let json = content.data(using: .utf8) else {
            throw URLError(.cannotParseResponse)
        }
        return try GroqResponseAdapter.visionResult(from: json)
    }

    private struct GroqEnvelope: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { let content: String }
            let message: Message
        }
        let choices: [Choice]
    }
}
