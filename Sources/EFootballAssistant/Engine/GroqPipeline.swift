import Foundation

public struct PipelineMetrics: Sendable {
    public var visionMs: Double = 0
    public var decisionMs: Double = 0
    public var audioMs: Double = 0
    public var totalMs: Double = 0
    public var fps: Double = 0
}

public actor GroqAnalysisPipeline {
    public private(set) var latest: FrameAnalysis?
    public private(set) var latestRecommendation: Recommendation?
    public private(set) var metrics = PipelineMetrics()
    public private(set) var requests = 0
    public private(set) var skippedByCooldown = 0

    private let vision: VisionAIProvider
    private let coordinator: DecisionCoordinator
    private let diagnostics: Diagnostics
    private let minRequestInterval: TimeInterval
    private var lastRequest = Date.distantPast
    private var processedTimestamps: [TimeInterval] = []

    public init(vision: VisionAIProvider, recommender: RecommendationEngine = RecommendationEngine(), voice: VoiceEngine = VoiceEngine(), diagnostics: Diagnostics = Diagnostics(), minRequestInterval: TimeInterval = 1.0) {
        self.vision = vision
        self.diagnostics = diagnostics
        self.coordinator = DecisionCoordinator(recommender: recommender, voice: voice, diagnostics: diagnostics)
        self.minRequestInterval = minRequestInterval
    }

    public func ingest(imageData: Data, mimeType: String = "image/jpeg", timestamp: TimeInterval = Date().timeIntervalSince1970) async {
        let started = Date()
        guard Date().timeIntervalSince(lastRequest) >= minRequestInterval else {
            skippedByCooldown += 1
            return
        }
        lastRequest = Date()
        requests += 1
        await diagnostics.log("groq_request_started")
        let visionStart = Date()

        do {
            let result = try await vision.analyze(imageData: imageData, mimeType: mimeType)
            metrics.visionMs = Date().timeIntervalSince(visionStart) * 1000
            let analysis = result.frameAnalysis(timestamp: timestamp)
            latest = analysis

            latestRecommendation = await coordinator.process(analysis, groqLatencyMs: metrics.visionMs)
            metrics.decisionMs = await coordinator.latestDecisionMs
            metrics.audioMs = await coordinator.latestVoiceDispatchMs

            processedTimestamps.append(timestamp)
            if processedTimestamps.count > 30 { processedTimestamps.removeFirst() }
            if let first = processedTimestamps.first, timestamp > first {
                metrics.fps = Double(processedTimestamps.count - 1) / (timestamp - first)
            }
            metrics.totalMs = Date().timeIntervalSince(started) * 1000
            await diagnostics.log("groq_request_finished")
        } catch {
            await diagnostics.log("groq_error: \(error.localizedDescription)")
        }
    }
}
