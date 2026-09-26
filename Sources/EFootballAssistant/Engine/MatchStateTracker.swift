import Foundation

public enum MatchAnalysisState: String, Codable, Sendable, Equatable {
    case idle = "IDLE"
    case systemInitialized = "SYSTEM_INITIALIZED"
    case eFootballDetected = "EFOOTBALL_DETECTED"
    case fieldDetected = "FIELD_DETECTED"
    case playersDetected = "PLAYERS_DETECTED"
    case userTeamDetected = "USER_TEAM_DETECTED"
    case matchAnalysisActive = "MATCH_ANALYSIS_ACTIVE"
}

public struct MatchStateSnapshot: Sendable, Equatable {
    public let state: MatchAnalysisState
    public let systemInitialized: Bool
    public let eFootballDetected: Bool
    public let fieldDetected: Bool
    public let playersDetected: Bool
    public let userTeamDetected: Bool
    public let matchAnalysisActive: Bool

    public init(
        state: MatchAnalysisState = .idle,
        systemInitialized: Bool = false,
        eFootballDetected: Bool = false,
        fieldDetected: Bool = false,
        playersDetected: Bool = false,
        userTeamDetected: Bool = false,
        matchAnalysisActive: Bool = false
    ) {
        self.state = state
        self.systemInitialized = systemInitialized
        self.eFootballDetected = eFootballDetected
        self.fieldDetected = fieldDetected
        self.playersDetected = playersDetected
        self.userTeamDetected = userTeamDetected
        self.matchAnalysisActive = matchAnalysisActive
    }
}

public actor MatchStateTracker {
    public private(set) var snapshot = MatchStateSnapshot()

    private let voice: VoiceEngine
    private let diagnostics: Diagnostics
    private let confidenceThreshold: Double
    private let playerConfidenceThreshold: Double

    public init(
        voice: VoiceEngine,
        diagnostics: Diagnostics,
        confidenceThreshold: Double = 0.45,
        playerConfidenceThreshold: Double = 0.75
    ) {
        self.voice = voice
        self.diagnostics = diagnostics
        self.confidenceThreshold = confidenceThreshold
        self.playerConfidenceThreshold = playerConfidenceThreshold
    }

    /// Called only after the real capture stream has successfully started.
    public func initializeSession() async {
        guard !snapshot.systemInitialized else { return }
        snapshot = MatchStateSnapshot(
            state: .systemInitialized,
            systemInitialized: true,
            eFootballDetected: snapshot.eFootballDetected,
            fieldDetected: snapshot.fieldDetected,
            playersDetected: snapshot.playersDetected,
            userTeamDetected: snapshot.userTeamDetected,
            matchAnalysisActive: snapshot.matchAnalysisActive
        )
        voice.speak("Sistema inicializado.")
        await diagnostics.log("system_initialized reason=capture_started")
    }

    /// Advances states only when the Groq-derived analysis contains sufficient evidence.
    /// It deliberately does not infer shirt color or user team from color alone.
    public func observe(_ analysis: FrameAnalysis) async {
        guard snapshot.systemInitialized else { return }
        let evidence = analysis.confidence >= confidenceThreshold
        let hasVisualObjects = analysis.observedPlayersCount > 0 || analysis.ballObserved || analysis.freeSpacesObserved > 0
        var changed = false

        if !snapshot.eFootballDetected && evidence && hasVisualObjects {
            snapshot = updated(state: .eFootballDetected, eFootballDetected: true)
            voice.speak("eFootball detectado.")
            await diagnostics.log("efootball_detected timestamp=\(analysis.timestamp) confidence=\(analysis.confidence) reason=groq_visual_evidence")
            changed = true
        }

        if !snapshot.fieldDetected && evidence && (analysis.ballObserved || analysis.freeSpacesObserved > 0) {
            snapshot = updated(state: .fieldDetected, fieldDetected: true)
            voice.speak("Campo identificado.")
            await diagnostics.log("field_detected timestamp=\(analysis.timestamp) confidence=\(analysis.confidence) reason=ball_or_space_evidence")
            changed = true
        }

        if !snapshot.playersDetected && evidence && analysis.observedPlayersCount >= 2 {
            snapshot = updated(state: .playersDetected, playersDetected: true)
            voice.speak("Jogadores localizados.")
            await diagnostics.log("players_detected timestamp=\(analysis.timestamp) confidence=\(analysis.confidence) reason=player_count")
            changed = true
        }

        // This is based on structured team/control fields only. No shirt-color assumption is made.
        let hasUserTeamEvidence = analysis.controlledPlayer != nil || !analysis.teammates.isEmpty
        if !snapshot.userTeamDetected && evidence && analysis.confidence >= playerConfidenceThreshold && hasUserTeamEvidence {
            snapshot = updated(state: .userTeamDetected, userTeamDetected: true)
            voice.speak("Time identificado. Análise iniciada.")
            await diagnostics.log("user_team_detected timestamp=\(analysis.timestamp) confidence=\(analysis.confidence) reason=structured_team_evidence")
            changed = true
        }

        let ready = snapshot.eFootballDetected && snapshot.fieldDetected && snapshot.playersDetected && snapshot.userTeamDetected
        if !snapshot.matchAnalysisActive && ready {
            snapshot = updated(state: .matchAnalysisActive, matchAnalysisActive: true)
            await diagnostics.log("match_analysis_started timestamp=\(analysis.timestamp) confidence=\(analysis.confidence) reason=required_states_ready")
            changed = true
        }

        _ = changed
    }

    private func updated(
        state: MatchAnalysisState,
        systemInitialized: Bool? = nil,
        eFootballDetected: Bool? = nil,
        fieldDetected: Bool? = nil,
        playersDetected: Bool? = nil,
        userTeamDetected: Bool? = nil,
        matchAnalysisActive: Bool? = nil
    ) -> MatchStateSnapshot {
        MatchStateSnapshot(
            state: state,
            systemInitialized: systemInitialized ?? snapshot.systemInitialized,
            eFootballDetected: eFootballDetected ?? snapshot.eFootballDetected,
            fieldDetected: fieldDetected ?? snapshot.fieldDetected,
            playersDetected: playersDetected ?? snapshot.playersDetected,
            userTeamDetected: userTeamDetected ?? snapshot.userTeamDetected,
            matchAnalysisActive: matchAnalysisActive ?? snapshot.matchAnalysisActive
        )
    }
}
