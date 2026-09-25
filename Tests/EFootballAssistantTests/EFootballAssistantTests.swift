import XCTest
@testable import EFootballAssistant

final class EFootballAssistantTests: XCTestCase {
    func testMockProcessorCreatesAttackState() async { let p=MockFrameProcessor(); let a=await p.process(frame:Data(),timestamp:1); XCTAssertEqual(a.context,.attack); XCTAssertGreaterThan(a.confidence,0.4); XCTAssertEqual(a.teammates.count,1) }
    func testHighPriorityRecommendationIsAccepted() async { let r=RecommendationEngine(cooldown:60); let x=await r.accept(Recommendation(text:"Direita",priority:.high)); XCTAssertEqual(x?.text,"Direita"); let y=await r.accept(Recommendation(text:"Direita",priority:.low)); XCTAssertNil(y) }
    func testPipelineProcessesFrame() async { let p=AnalysisPipeline(); await p.ingest(frame:Data([1])); XCTAssertEqual(await p.processedFrames,1); XCTAssertNotNil(await p.latest) }
}
