import Foundation
#if canImport(Vision)
import Vision
#endif

public protocol FrameProcessor: Sendable { func process(frame: Data, timestamp: TimeInterval) async -> FrameAnalysis }
public actor MockFrameProcessor: FrameProcessor {
    private let decision=DecisionEngine(); public init(){}
    public func process(frame:Data,timestamp:TimeInterval) async -> FrameAnalysis { let controlled=PlayerObservation(position:Point2D(x:0.5,y:0.6),team:.user,confidence:0.82); let mate=PlayerObservation(position:Point2D(x:0.73,y:0.38),team:.user,confidence:0.77,isFree:true); let opp=PlayerObservation(position:Point2D(x:0.58,y:0.55),team:.opponent,confidence:0.74); return FrameAnalysis(timestamp:timestamp,controlledPlayer:controlled,teammates:[mate],opponents:[opp],ball:Point2D(x:0.52,y:0.58),context:.attack,confidence:0.78) }
}
public actor AnalysisPipeline {
    public private(set) var latest: FrameAnalysis?; public private(set) var latestRecommendation: Recommendation?; public private(set) var processedFrames=0; public private(set) var latencyMs:Double=0
    private let processor: FrameProcessor; private let ai: AIService; private let recommender: RecommendationEngine; private let diagnostics: Diagnostics; private let voice: VoiceEngine
    public init(processor:FrameProcessor=MockFrameProcessor(), ai:AIService=MockAIService(), settings:AppSettings=AppSettings(), diagnostics:Diagnostics=Diagnostics()){self.processor=processor;self.ai=ai;self.recommender=RecommendationEngine();self.diagnostics=diagnostics;self.voice=VoiceEngine(settings:settings)}
    public func ingest(frame:Data,timestamp:TimeInterval=Date().timeIntervalSince1970) async { let start=Date(); await diagnostics.log("frame_received"); let a=await processor.process(frame:frame,timestamp:timestamp); latest=a; do { if let r=try await ai.recommend(for:AIRequest(analysis:a)), let accepted=await recommender.accept(r) { latestRecommendation=accepted; voice.speak(accepted.text); await diagnostics.log("recommendation: \(accepted.text)") } } catch { await diagnostics.log("ai_error: \(error.localizedDescription)") }; processedFrames += 1; latencyMs=Date().timeIntervalSince(start)*1000 }
}
