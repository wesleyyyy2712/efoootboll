import Foundation
#if canImport(AVFAudio)
import AVFAudio
#endif

public actor Diagnostics {
    public struct Event: Sendable { public let date: Date; public let message: String }
    public private(set) var events: [Event] = []
    public init() {}
    public func log(_ message: String) { events.append(Event(date: Date(), message: message)); if events.count > 500 { events.removeFirst() } }
}

public actor RecommendationEngine {
    private var lastText = ""
    private var lastDate = Date.distantPast
    private let cooldown: TimeInterval
    public init(cooldown: TimeInterval = 2.5) { self.cooldown = cooldown }
    public func accept(_ recommendation: Recommendation) -> Recommendation? {
        let now = Date()
        guard recommendation.text != lastText || now.timeIntervalSince(lastDate) > cooldown || recommendation.priority == .high else { return nil }
        lastText = recommendation.text; lastDate = now
        return recommendation
    }
}

public final class VoiceEngine: NSObject, @unchecked Sendable {
    #if canImport(AVFAudio)
    private let synthesizer = AVSpeechSynthesizer()
    #endif
    private var settings: AppSettings
    public init(settings: AppSettings = AppSettings()) { self.settings = settings; super.init() }
    public func update(_ settings: AppSettings) { self.settings = settings }
    public func speak(_ text: String) {
        guard settings.voiceEnabled else { return }
        #if canImport(AVFAudio)
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = settings.voiceRate
        utterance.volume = settings.volume
        utterance.voice = AVSpeechSynthesisVoice(language: settings.language)
        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.speak(utterance)
        #endif
    }
}

public struct DecisionEngine: Sendable {
    public init() {}
    public func makeDecision(from analysis: FrameAnalysis) -> Recommendation? {
        guard analysis.confidence >= 0.45 else { return nil }
        if analysis.opponents.filter({ $0.position.x > 0.45 && $0.position.x < 0.7 }).count >= 2 { return Recommendation(text: "Cuidado com a pressão", priority: .high) }
        if let player = analysis.teammates.first(where: { $0.isFree }) { return Recommendation(text: player.position.x > 0.5 ? "Passe para a direita" : "Passe para a esquerda", priority: .high) }
        return nil
    }
}
