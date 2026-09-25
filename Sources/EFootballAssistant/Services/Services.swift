import Foundation
#if canImport(ReplayKit)
import ReplayKit
#endif

public protocol AIService: Sendable { func recommend(for request: AIRequest) async throws -> Recommendation? }
public struct MockAIService: AIService {
    public init() {}
    public func recommend(for request: AIRequest) async throws -> Recommendation? {
        let a=request.analysis
        guard a.confidence >= 0.45 else { return nil }
        if a.opponents.contains(where: { $0.position.x < 0.55 && $0.position.y > 0.45 }) { return Recommendation(text: "Cuidado com a pressão", priority: .high) }
        if let free=a.teammates.first(where: {$0.isFree}) { let side=free.position.x > 0.55 ? "direita" : "esquerda"; return Recommendation(text: "Livre na \(side)", priority: .high) }
        if a.context == .attack { return Recommendation(text: "Avance pelo meio", priority: .medium) }
        return nil
    }
}
public actor RemoteAIService: AIService {
    public struct Configuration: Sendable { public var endpoint: URL; public var apiKey: String?; public var model: String; public var timeout: TimeInterval; public init(endpoint: URL, apiKey: String?=nil, model: String="default", timeout: TimeInterval=1.5) { self.endpoint=endpoint; self.apiKey=apiKey; self.model=model; self.timeout=timeout } }
    private let config: Configuration; private let session: URLSession
    public init(configuration: Configuration, session: URLSession = .shared) { self.config=configuration; self.session=session }
    public func recommend(for request: AIRequest) async throws -> Recommendation? { var r=URLRequest(url: config.endpoint, timeoutInterval: config.timeout); r.httpMethod="POST"; r.setValue("application/json", forHTTPHeaderField:"Content-Type"); if let key=config.apiKey { r.setValue("Bearer \(key)", forHTTPHeaderField:"Authorization") }; r.httpBody=try JSONEncoder().encode(request); let (data,response)=try await session.data(for:r); guard let http=response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }; return try JSONDecoder().decode(Recommendation?.self, from:data) }
}
public protocol CaptureManager: Sendable { func start() async throws; func stop() async; var isCapturing: Bool { get async } }
public actor MockCaptureManager: CaptureManager { public private(set) var isCapturing=false; public init(){}; public func start() async throws { isCapturing=true }; public func stop() async { isCapturing=false } }
