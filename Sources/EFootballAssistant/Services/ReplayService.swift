import Foundation
#if canImport(AVFoundation)
import AVFoundation
import CoreMedia
import ImageIO

public struct StageMetrics:Sendable{public var captureMs:Double=0;public var processingMs:Double=0;public var visionMs:Double=0;public var aiMs:Double=0;public var decisionMs:Double=0;public var audioMs:Double=0;public var totalMs:Double=0}
public struct ReplayReport:Sendable{public var framesRead=0;public var framesProcessed=0;public var averageLatencyMs=0.0;public var maxLatencyMs=0.0;public var recommendations:[String]=[];public var errors:[String]=[];public var metrics=StageMetrics();public var fps=0.0}
public final class VideoReplayService:@unchecked Sendable{
 public init(){}
 public func process(url:URL,everyNthFrame:Int=3,handler:@escaping @Sendable(Data,TimeInterval) async -> Void)async throws->ReplayReport{let asset=AVAsset(url:url);let duration=try await asset.load(.duration);let tracks=try await asset.load(.tracks);let fps=tracks.first?.nominalFrameRate ?? 30;let generator=AVAssetImageGenerator(asset:asset);generator.appliesPreferredTrackTransform=true;let step=Double(max(1,everyNthFrame))/Double(max(1,fps));var report=ReplayReport();var time=0.0;while time<duration.seconds{let started=Date();do{let cg=try generator.copyCGImage(at:CMTime(seconds:time,preferredTimescale:600),actualTime:nil);await handler(NSImageDataBridge.jpegData(cgImage:cg),time);report.framesRead += 1;if report.framesRead % max(1,everyNthFrame)==0{report.framesProcessed += 1;let latency=Date().timeIntervalSince(started)*1000;report.averageLatencyMs += latency;report.maxLatencyMs=max(report.maxLatencyMs,latency)}}catch{report.errors.append(error.localizedDescription)};time += step};if report.framesProcessed>0{report.averageLatencyMs /= Double(report.framesProcessed);report.fps=Double(report.framesProcessed)/max(duration.seconds,0.001)};return report}
 public func run(url:URL,pipeline:GroqAnalysisPipeline,everyNthFrame:Int=3)async throws->ReplayReport{try await process(url:url,everyNthFrame:everyNthFrame){data,timestamp in await pipeline.ingest(imageData:data,timestamp:timestamp)}}
}
private enum NSImageDataBridge{static func jpegData(cgImage:CGImage)->Data{let rep=NSMutableData();guard let dest=CGImageDestinationCreateWithData(rep,"public.jpeg" as CFString,1,nil)else{return Data()};CGImageDestinationAddImage(dest,cgImage,[kCGImageDestinationLossyCompressionQuality:0.75] as CFDictionary);CGImageDestinationFinalize(dest);return rep as Data}}
#endif
