import XCTest
@testable import EFootballAssistant

final class GroqPipelineTests:XCTestCase{
    struct StubVision:VisionAIProvider{let result:VisionAIResult;func analyze(imageData:Data,mimeType:String)async throws->VisionAIResult{result}}
    func testStructuredVisionMapsToAnalysis(){let payload=RecommendationPayload(type:.forwardPass,priority:.high,message:"Jogador livre na frente");let result=VisionAIResult(ball:Point2D(x:0.5,y:0.5),teammates:[PlayerObservation(position:Point2D(x:0.7,y:0.3),team:.user,isFree:true)],gameContext:.attack,confidence:0.9,recommendation:payload);let exp=expectation(description:"pipeline");Task{let p=GroqAnalysisPipeline(vision:StubVision(result:result),minRequestInterval:0);await p.ingest(imageData:Data([1]),timestamp:1);XCTAssertEqual(await p.latest?.context,.attack);XCTAssertEqual(await p.latestRecommendation?.text,"Jogador livre na frente");exp.fulfill()};waitForExpectations(timeout:2)}
    func testCooldownSkipsSecondRequest(){let exp=expectation(description:"cooldown");let vision=StubVision(result:VisionAIResult(confidence:0.8));Task{let p=GroqAnalysisPipeline(vision:vision,minRequestInterval:60);await p.ingest(imageData:Data(),timestamp:1);await p.ingest(imageData:Data(),timestamp:2);XCTAssertEqual(await p.requests,1);XCTAssertEqual(await p.skippedByCooldown,1);exp.fulfill()};waitForExpectations(timeout:2)}
}
