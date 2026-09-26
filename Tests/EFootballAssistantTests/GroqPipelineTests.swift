import XCTest
@testable import EFootballAssistant

final class GroqPipelineTests: XCTestCase {
    struct StubVision: VisionAIProvider {
        let result: VisionAIResult
        func analyze(imageData: Data, mimeType: String) async throws -> VisionAIResult { result }
    }

    func testStructuredVisionMapsToAnalysis() async {
        let payload = RecommendationPayload(type: .forwardPass, priority: .high, message: "Jogador livre na frente")
        let result = VisionAIResult(
            ball: Point2D(x: 0.5, y: 0.5),
            teammates: [PlayerObservation(position: Point2D(x: 0.7, y: 0.3), team: .user, isFree: true)],
            gameContext: .attack,
            confidence: 0.9,
            recommendation: payload
        )
        let pipeline = GroqAnalysisPipeline(vision: StubVision(result: result), minRequestInterval: 0)

        await pipeline.ingest(imageData: Data([1]), timestamp: 1)

        let analysis = await pipeline.latest
        let recommendation = await pipeline.latestRecommendation
        XCTAssertEqual(analysis?.context, .attack)
        XCTAssertEqual(analysis?.ballObserved, true)
        XCTAssertEqual(analysis?.freeSpacesObserved, 0)
        XCTAssertEqual(recommendation?.text, "Jogador livre na frente")
    }

    func testCooldownSkipsSecondRequest() async {
        let vision = StubVision(result: VisionAIResult(confidence: 0.8))
        let pipeline = GroqAnalysisPipeline(vision: vision, minRequestInterval: 60)

        await pipeline.ingest(imageData: Data(), timestamp: 1)
        await pipeline.ingest(imageData: Data(), timestamp: 2)

        let requests = await pipeline.requests
        let skipped = await pipeline.skippedByCooldown
        XCTAssertEqual(requests, 1)
        XCTAssertEqual(skipped, 1)
    }
}
