import Foundation
#if canImport(ScreenCaptureKit)
import ScreenCaptureKit
import CoreMedia
import CoreVideo

@available(iOS 27.0, *)
public final class ScreenCaptureKitAdapter: NSObject, CaptureManager, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    private var stream:SCStream?; private let queue=DispatchQueue(label:"efootball.capture.frames",qos:.userInitiated); private let onFrame:@Sendable(Data,TimeInterval)->Void; private let encoder=PixelBufferEncoder(); public private(set) var isCapturing=false
    public init(onFrame:@escaping @Sendable(Data,TimeInterval)->Void){self.onFrame=onFrame}
    public func start()async throws{throw NSError(domain:"ScreenCaptureKitAdapter",code:2,userInfo:[NSLocalizedDescriptionKey:"Obtenha SCContentFilter pelo SCContentSharingPicker e chame start(with:)."])}
    public func start(with filter:SCContentFilter)async throws{let config=SCStreamConfiguration();config.width=960;config.height=540;config.minimumFrameInterval=CMTime(value:1,timescale:15);let newStream=SCStream(filter:filter,configuration:config,delegate:self);try newStream.addStreamOutput(self,type:.screen,sampleHandlerQueue:queue);try await newStream.startCapture();stream=newStream;isCapturing=true}
    public func stop()async{guard let stream else{return};try? await stream.stopCapture();self.stream=nil;isCapturing=false}
    public func stream(_ stream:SCStream,didOutputSampleBuffer sampleBuffer:CMSampleBuffer,of type:SCStreamOutputType){guard type == .screen,let pixel=CMSampleBufferGetImageBuffer(sampleBuffer)else{return};let timestamp=CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds;guard let data=try? encoder.jpegData(from:pixel)else{return};onFrame(data,timestamp)}
    public func stream(_ stream:SCStream,didStopWithError error:Error){isCapturing=false}
}
#else
public final class ScreenCaptureKitAdapter:NSObject,CaptureManager,@unchecked Sendable{public private(set)var isCapturing=false;public init(onFrame:@escaping @Sendable(Data,TimeInterval)->Void){};public func start()async throws{throw NSError(domain:"ScreenCaptureKit",code:1,userInfo:[NSLocalizedDescriptionKey:"ScreenCaptureKit não está disponível neste SDK."])};public func stop()async{isCapturing=false}}
#endif
