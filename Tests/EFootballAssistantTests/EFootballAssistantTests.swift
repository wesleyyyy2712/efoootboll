import XCTest
@testable import EFootballAssistant

final class EFootballAssistantTests: XCTestCase {
    func testMockProcessorCreatesAttackState() async {
        let processor = MockFrameProcessor()
        let analysis = await processor.process(frame: Data(), timestamp: 1)

        XCTAssertEqual(analysis.context, .attack)
        XCTAssertGreaterThan(analysis.confidence, 0.4)
        XCTAssertEqual(analysis.teammates.count, 1)
    }

    func testHighPriorityRecommendationIsAccepted() async {
        let engine = RecommendationEngine(cooldown: 60)
        let first = await engine.accept(Recommendation(text: "Direita", priority: .high))
        let second = await engine.accept(Recommendation(text: "Direita", priority: .low))

        XCTAssertEqual(first?.text, "Direita")
        XCTAssertNil(second)
    }

    func testPipelineProcessesFrame() async {
        let pipeline = AnalysisPipeline()
        await pipeline.ingest(frame: Data([1]))
        let processedFrames = await pipeline.processedFrames
        let latest = await pipeline.latest

        XCTAssertEqual(processedFrames, 1)
        XCTAssertNotNil(latest)
    }
}
