import XCTest
@testable import EFootballAssistant

final class RealGroqPipelineTests: XCTestCase {
    private final class SpeechRecorder: @unchecked Sendable {
        private let lock = NSLock()
        private var recorded: [String] = []

        func record(_ text: String) {
            lock.lock()
            recorded.append(text)
            lock.unlock()
        }

        var messages: [String] {
            lock.lock()
            defer { lock.unlock() }
            return recorded
        }
    }

    private func loadRealGroqFixture() throws -> Data {
        let testDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let fixtureURL = testDirectory
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/groq_real_response.json")
        return try Data(contentsOf: fixtureURL)
    }

    func testRealGroqFixtureFlowsThroughAnalysisDecisionAndVoiceEngine() async throws {
        let json = try loadRealGroqFixture()
        let result = try GroqResponseAdapter.visionResult(from: json)
        let analysis = result.frameAnalysis(timestamp: 123)

        XCTAssertEqual(analysis.timestamp, 123)
        XCTAssertEqual(analysis.confidence, 0.95)
        XCTAssertEqual(analysis.observedPlayersCount, 8)
        XCTAssertTrue(analysis.ballObserved)
        XCTAssertEqual(analysis.freeSpacesObserved, 1)
        XCTAssertNil(analysis.ball, "The summary response has no coordinates; do not fabricate a ball position")
        XCTAssertEqual(analysis.recommendation?.message, "Use o botão 'Dash & Pressure' para recuperar a posse de bola e pressione o adversário.")

        let recorder = SpeechRecorder()
        let voice = VoiceEngine(onSpeak: { recorder.record($0) })
        let diagnostics = Diagnostics()
        let coordinator = DecisionCoordinator(engine: DecisionEngine(), voice: voice, diagnostics: diagnostics, minPriority: .medium)
        let groqLatencyMs = 854.5 // measured by the successful HTTP 200 Groq probe

        let recommendation = await coordinator.process(analysis, groqLatencyMs: groqLatencyMs)
        let firstTTSTriggered = await coordinator.latestTTSTriggered
        let firstDecisionMs = await coordinator.latestDecisionMs
        let firstVoiceDispatchMs = await coordinator.latestVoiceDispatchMs
        XCTAssertEqual(recommendation?.priority, .medium)
        XCTAssertEqual(recommendation?.text, analysis.recommendation?.message)
        XCTAssertTrue(firstTTSTriggered)
        XCTAssertEqual(recorder.messages, [analysis.recommendation?.message].compactMap { $0 })
        XCTAssertGreaterThanOrEqual(firstDecisionMs, 0)
        XCTAssertGreaterThanOrEqual(firstVoiceDispatchMs, 0)
        print("Pipeline latency (Groq probe / DecisionEngine / VoiceEngine dispatch): \(groqLatencyMs) ms / \(firstDecisionMs) ms / \(firstVoiceDispatchMs) ms")

        let events = await diagnostics.events
        let firstEvent = try XCTUnwrap(events.first)
        XCTAssertTrue(firstEvent.message.contains("timestamp=123"))
        XCTAssertTrue(firstEvent.message.contains("groq_latency_ms=854.5"))
        XCTAssertTrue(firstEvent.message.contains("players=8"))
        XCTAssertTrue(firstEvent.message.contains("ball_detected=true"))
        XCTAssertTrue(firstEvent.message.contains("spaces=1"))
        XCTAssertTrue(firstEvent.message.contains("recommendation_received=true"))
        XCTAssertTrue(firstEvent.message.contains("decision="))
        XCTAssertTrue(firstEvent.message.contains("Dash & Pressure"))
        XCTAssertTrue(firstEvent.message.contains("decision_ms="))
        XCTAssertTrue(firstEvent.message.contains("voice_dispatch_ms="))
        XCTAssertTrue(firstEvent.message.contains("tts_triggered=true"))

        let repeated = await coordinator.process(analysis, groqLatencyMs: groqLatencyMs)
        let repeatedTTSTriggered = await coordinator.latestTTSTriggered
        XCTAssertEqual(repeated?.text, recommendation?.text)
        XCTAssertEqual(recorder.messages.count, 1, "A repeated recommendation must be blocked by cooldown")
        XCTAssertFalse(repeatedTTSTriggered)

        let allEvents = await diagnostics.events
        XCTAssertEqual(allEvents.count, 2)
        XCTAssertTrue(allEvents[1].message.contains("tts_triggered=false"))
        XCTAssertTrue(allEvents[1].message.contains("reason=cooldown"))
    }

    func testLowConfidenceRecommendationNeverReachesVoiceEngine() async {
        let received = RecommendationPayload(type: .none, priority: .high, message: "Passe para frente")
        let analysis = FrameAnalysis(timestamp: 124, controlledPlayer: nil, confidence: 0.2, recommendation: received)
        let recorder = SpeechRecorder()
        let coordinator = DecisionCoordinator(voice: VoiceEngine(onSpeak: { recorder.record($0) }))

        let decision = await coordinator.process(analysis, groqLatencyMs: 0)
        let ttsTriggered = await coordinator.latestTTSTriggered

        XCTAssertNil(decision)
        XCTAssertTrue(recorder.messages.isEmpty)
        XCTAssertFalse(ttsTriggered)
    }

    func testLowPriorityRecommendationNeverReachesVoiceEngine() async {
        let received = RecommendationPayload(type: .none, priority: .low, message: "Continue avançando")
        let analysis = FrameAnalysis(timestamp: 125, controlledPlayer: nil, confidence: 0.95, recommendation: received)
        let recorder = SpeechRecorder()
        let diagnostics = Diagnostics()
        let coordinator = DecisionCoordinator(voice: VoiceEngine(onSpeak: { recorder.record($0) }), diagnostics: diagnostics, minPriority: .medium)

        let decision = await coordinator.process(analysis, groqLatencyMs: 0)
        let ttsTriggered = await coordinator.latestTTSTriggered
        let events = await diagnostics.events

        XCTAssertEqual(decision?.priority, .low)
        XCTAssertTrue(recorder.messages.isEmpty)
        XCTAssertFalse(ttsTriggered)
        XCTAssertTrue(events.first?.message.contains("reason=priority") == true)
    }
}
