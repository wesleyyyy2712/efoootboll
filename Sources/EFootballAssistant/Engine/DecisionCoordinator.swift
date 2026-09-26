import Foundation

public actor DecisionCoordinator {
    public private(set) var lastDecision: Recommendation?
    public private(set) var latestDecisionMs: Double = 0
    public private(set) var latestVoiceDispatchMs: Double = 0
    public private(set) var latestTTSTriggered = false

    private let engine: DecisionEngine
    private let recommender: RecommendationEngine
    private let voice: VoiceEngine
    private let diagnostics: Diagnostics
    private let minimumPriority: RecommendationPriority

    public init(engine: DecisionEngine = DecisionEngine(), recommender: RecommendationEngine = RecommendationEngine(), voice: VoiceEngine = VoiceEngine(), diagnostics: Diagnostics = Diagnostics(), minPriority: RecommendationPriority = .medium) {
        self.engine = engine
        self.recommender = recommender
        self.voice = voice
        self.diagnostics = diagnostics
        self.minimumPriority = minPriority
    }

    public func process(_ analysis: FrameAnalysis, groqLatencyMs: Double) async -> Recommendation? {
        latestDecisionMs = 0
        latestVoiceDispatchMs = 0
        latestTTSTriggered = false

        let decisionStart = Date()
        let received = analysis.recommendation
        let decided = engine.makeDecision(from: analysis)
        latestDecisionMs = Date().timeIntervalSince(decisionStart) * 1000

        guard let decided else {
            await log(analysis, groqLatencyMs: groqLatencyMs, received: received, decision: nil, reason: "no_decision")
            return nil
        }
        lastDecision = decided

        guard decided.priority >= minimumPriority else {
            await log(analysis, groqLatencyMs: groqLatencyMs, received: received, decision: decided, reason: "priority")
            return decided
        }

        guard let accepted = await recommender.accept(decided) else {
            await log(analysis, groqLatencyMs: groqLatencyMs, received: received, decision: decided, reason: "cooldown")
            return decided
        }

        let voiceStart = Date()
        latestTTSTriggered = voice.speak(accepted.text)
        latestVoiceDispatchMs = Date().timeIntervalSince(voiceStart) * 1000
        await log(analysis, groqLatencyMs: groqLatencyMs, received: received, decision: accepted, reason: latestTTSTriggered ? "spoken" : "voice_disabled")
        return accepted
    }

    private func log(_ analysis: FrameAnalysis, groqLatencyMs: Double, received: RecommendationPayload?, decision: Recommendation?, reason: String) async {
        let receivedText = received.map { String(reflecting: $0.message) } ?? "none"
        let decisionText = decision.map { String(reflecting: $0.text) } ?? "none"
        await diagnostics.log(
            "timestamp=\(analysis.timestamp) groq_latency_ms=\(groqLatencyMs) players=\(analysis.observedPlayersCount) ball_detected=\(analysis.ballObserved) spaces=\(analysis.freeSpacesObserved) recommendation_received=\(received != nil) recommendation_text=\(receivedText) decision=\(decisionText) decision_ms=\(latestDecisionMs) tts_triggered=\(latestTTSTriggered) voice_dispatch_ms=\(latestVoiceDispatchMs) reason=\(reason)"
        )
    }
}
