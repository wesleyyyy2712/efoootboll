import XCTest
@testable import EFootballAssistant

final class MatchStateTrackerTests: XCTestCase {
    func testSessionStatesAreAnnouncedOnceAndReachActiveWithStructuredEvidence() async {
        let diagnostics = Diagnostics()
        let speech = SpeechRecorder()
        let tracker = MatchStateTracker(
            voice: VoiceEngine(onSpeak: { speech.record($0) }),
            diagnostics: diagnostics
        )

        await tracker.initializeSession()
        await tracker.initializeSession()
        let controlled = PlayerObservation(position: Point2D(x: 0.5, y: 0.5), team: .user, confidence: 0.9)
        let teammate = PlayerObservation(position: Point2D(x: 0.7, y: 0.4), team: .user, confidence: 0.9)
        let opponent = PlayerObservation(position: Point2D(x: 0.3, y: 0.4), team: .opponent, confidence: 0.9)
        let analysis = FrameAnalysis(
            timestamp: 10,
            controlledPlayer: controlled,
            teammates: [teammate],
            opponents: [opponent],
            ball: Point2D(x: 0.5, y: 0.5),
            confidence: 0.9
        )
        await tracker.observe(analysis)
        await tracker.observe(analysis)

        let snapshot = await tracker.snapshot
        XCTAssertTrue(snapshot.matchAnalysisActive)
        XCTAssertEqual(speech.messages.filter { $0 == "Sistema inicializado." }.count, 1)
        XCTAssertEqual(speech.messages.filter { $0 == "eFootball detectado." }.count, 1)
        XCTAssertEqual(speech.messages.filter { $0 == "Campo identificado." }.count, 1)
        XCTAssertEqual(speech.messages.filter { $0 == "Jogadores localizados." }.count, 1)
        XCTAssertEqual(speech.messages.filter { $0 == "Time identificado. Análise iniciada." }.count, 1)
    }

    func testInsufficientTeamEvidenceDoesNotClaimUserTeam() async {
        let tracker = MatchStateTracker(voice: VoiceEngine(), diagnostics: Diagnostics())
        await tracker.initializeSession()
        let analysis = FrameAnalysis(
            timestamp: 20,
            controlledPlayer: nil,
            teammates: [],
            opponents: [PlayerObservation(position: Point2D(x: 0.3, y: 0.4), team: .opponent)],
            ball: Point2D(x: 0.5, y: 0.5),
            confidence: 0.95
        )
        await tracker.observe(analysis)

        let snapshot = await tracker.snapshot
        XCTAssertFalse(snapshot.userTeamDetected)
        XCTAssertFalse(snapshot.matchAnalysisActive)
    }

    private final class SpeechRecorder: @unchecked Sendable {
        private var values: [String] = []
        private let lock = NSLock()

        func record(_ text: String) {
            lock.lock()
            values.append(text)
            lock.unlock()
        }

        var messages: [String] {
            lock.lock()
            defer { lock.unlock() }
            return values
        }
    }
}
