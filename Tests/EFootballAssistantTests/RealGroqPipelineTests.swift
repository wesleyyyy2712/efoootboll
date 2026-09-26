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

    private struct FixtureVisionProvider: VisionAIProvider {
        let fixture: Data

        func analyze(imageData: Data, mimeType: String) async throws -> VisionAIResult {
            try GroqResponseAdapter.visionResult(from: fixture)
        }
    }

    private func loadRealGroqFixture() throws -> Data {
        let testDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let fixtureURL = testDirectory
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/groq_real_response.json")
        return try Data(contentsOf: fixtureURL)
    }

    func testRealGroqFixtureFlowsThroughPipelineDecisionAndVoiceEngine() async throws {
        let json = try loadRealGroqFixture()
        let decoded = try GroqResponseAdapter.decode(json)
        let mappedAnalysis = GroqResponseAdapter.frameAnalysis(from: decoded, timestamp: 123)

        XCTAssertEqual(mappedAnalysis.timestamp, 123)
        XCTAssertEqual(mappedAnalysis.confidence, 0.95)
        XCTAssertEqual(mappedAnalysis.observedPlayersCount, 8)
        XCTAssertTrue(mappedAnalysis.ballObserved)
        XCTAssertEqual(mappedAnalysis.freeSpacesObserved, 1)
        XCTAssertNil(mappedAnalysis.ball, "The summary response has no coordinates; do not fabricate a ball position")
        XCTAssertEqual(mappedAnalysis.recommendation?.message, "Use o botão 'Dash & Pressure' para recuperar a posse de bola e pressione o adversário.")

        let recorder = SpeechRecorder()
        let diagnostics = Diagnostics()
        let pipeline = GroqAnalysisPipeline(
            vision: FixtureVisionProvider(fixture: json),
            voice: VoiceEngine(onSpeak: { recorder.record($0) }),
            diagnostics: diagnostics,
            minRequestInterval: 0
        )

        await pipeline.ingest(imageData: Data([1]), timestamp: 123)
        let firstAnalysis = await pipeline.latest
        let firstRecommendation = await pipeline.latestRecommendation
        let firstMetrics = await pipeline.metrics
        let firstEvents = await diagnostics.events
        XCTAssertEqual(firstAnalysis?.observedPlayersCount, 8)
        XCTAssertEqual(firstAnalysis?.ballObserved, true)
        XCTAssertEqual(firstAnalysis?.freeSpacesObserved, 1)
        XCTAssertEqual(firstRecommendation?.priority, .medium)
        XCTAssertEqual(firstRecommendation?.text, mappedAnalysis.recommendation?.message)
        XCTAssertEqual(recorder.messages, [mappedAnalysis.recommendation?.message].compactMap { $0 })
        XCTAssertGreaterThanOrEqual(firstMetrics.visionMs, 0)
        XCTAssertGreaterThanOrEqual(firstMetrics.decisionMs, 0)
        XCTAssertGreaterThanOrEqual(firstMetrics.audioMs, 0)
        XCTAssertGreaterThanOrEqual(firstMetrics.totalMs, firstMetrics.visionMs)

        let firstEvent = try XCTUnwrap(firstEvents.first(where: { $0.message.contains("timestamp=123") }))
        XCTAssertTrue(firstEvent.message.contains("players=8"))
        XCTAssertTrue(firstEvent.message.contains("ball_detected=true"))
        XCTAssertTrue(firstEvent.message.contains("spaces=1"))
        XCTAssertTrue(firstEvent.message.contains("recommendation_received=true"))
        XCTAssertTrue(firstEvent.message.contains("decision=\"Use o botão 'Dash & Pressure'"))
        XCTAssertTrue(firstEvent.message.contains("groq_latency_ms="))
        XCTAssertTrue(firstEvent.message.contains("decision_ms="))
        XCTAssertTrue(firstEvent.message.contains("voice_dispatch_ms="))
        XCTAssertTrue(firstEvent.message.contains("tts_triggered=true"))

        await pipeline.ingest(imageData: Data([1]), timestamp: 124)
        let allEvents = await diagnostics.events
        XCTAssertEqual(recorder.messages.count, 1, "A repeated recommendation must be blocked by cooldown")
        let repeatedDiagnostic = try XCTUnwrap(allEvents.last(where: { $0.message.contains("timestamp=124") }))
        XCTAssertTrue(repeatedDiagnostic.message.contains("tts_triggered=false"))
        XCTAssertTrue(repeatedDiagnostic.message.contains("reason=cooldown"))
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
}
