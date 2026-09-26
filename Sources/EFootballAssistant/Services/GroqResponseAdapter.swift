import Foundation

public struct GroqRealVisionResponse: Codable, Sendable { public var visiblePlayersCount:Int?; public var ballVisible:Bool?; public var freeSpaceVisible:Bool?; public var gameContext:String?; public var confidence:Double?; public var recommendation:String?; enum CodingKeys:String,CodingKey{case visiblePlayersCount="visible_players_count";case ballVisible="ball_visible";case freeSpaceVisible="free_space_visible";case gameContext="game_context";case confidence;case recommendation}; public init(visiblePlayersCount:Int?=nil,ballVisible:Bool?=nil,freeSpaceVisible:Bool?=nil,gameContext:String?=nil,confidence:Double?=nil,recommendation:String?=nil){self.visiblePlayersCount=visiblePlayersCount;self.ballVisible=ballVisible;self.freeSpaceVisible=freeSpaceVisible;self.gameContext=gameContext;self.confidence=confidence;self.recommendation=recommendation} }
public enum GroqResponseAdapter {
    public static func decode(_ data:Data) throws -> GroqRealVisionResponse { try JSONDecoder().decode(GroqRealVisionResponse.self,from:data) }
    public static func frameAnalysis(from response:GroqRealVisionResponse,timestamp:TimeInterval) -> FrameAnalysis {
        let context:GameContext = response.gameContext == "attack" ? .attack : response.gameContext == "defense" ? .defense : response.gameContext == "transition" ? .transition : .unknown
        // The real probe returned counts/flags rather than coordinates. Do not fabricate player or ball positions.
        let receivedRecommendation = response.recommendation.flatMap { text -> RecommendationPayload? in guard !text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else{return nil}; return RecommendationPayload(type:.none,priority:.medium,message:text) }
        return FrameAnalysis(timestamp:timestamp,controlledPlayer:nil,teammates:[],opponents:[],ball:nil,freeSpaces:[],context:context,confidence:response.confidence ?? 0,recommendation:receivedRecommendation,observedPlayersCount:response.visiblePlayersCount ?? 0,ballObserved:response.ballVisible ?? false,freeSpacesObserved:(response.freeSpaceVisible ?? false) ? 1 : 0)
    }
}
