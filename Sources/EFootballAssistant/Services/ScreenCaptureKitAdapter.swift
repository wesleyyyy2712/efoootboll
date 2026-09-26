import Foundation
#if canImport(ScreenCaptureKit)
import ScreenCaptureKit
import CoreMedia
import CoreVideo

@available(iOS 27.0, macOS 14.0, *)
public final class ScreenCaptureKitAdapter: NSObject, CaptureManager, SCStreamOutput, SCStreamDelegate, SCContentSharingPickerObserver, @unchecked Sendable {
    private var stream: SCStream?
    private var pendingStart: CheckedContinuation<Void, Error>?
    private let queue = DispatchQueue(label: "efootball.capture.frames", qos: .userInitiated)
    private let onFrame: @Sendable (Data, TimeInterval) -> Void
    private let encoder = PixelBufferEncoder()
    public private(set) var isCapturing = false

    public init(onFrame: @escaping @Sendable (Data, TimeInterval) -> Void) { self.onFrame = onFrame }

    /// Presents Apple's system picker; the user chooses the app/display to capture.
    public func start() async throws {
        guard !isCapturing else { return }
        try await withCheckedThrowingContinuation { continuation in
            pendingStart = continuation
            let picker = SCContentSharingPicker.shared
            var configuration = SCContentSharingPickerConfiguration()
            configuration.allowsChangingSelectedContent = false
            picker.configuration = configuration
            picker.add(self)
            picker.present()
        }
    }

    public func start(with filter: SCContentFilter) async throws {
        guard !isCapturing else { return }
        let config = SCStreamConfiguration()
        config.width = 960
        config.height = 540
        config.minimumFrameInterval = CMTime(value: 1, timescale: 15)
        let newStream = SCStream(filter: filter, configuration: config, delegate: self)
        try newStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
        try await newStream.startCapture()
        stream = newStream
        isCapturing = true
        pendingStart?.resume()
        pendingStart = nil
    }

    public func stop() async {
        if let stream { try? await stream.stopCapture() }
        self.stream = nil
        isCapturing = false
        SCContentSharingPicker.shared.remove(self)
    }

    public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, let pixel = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        guard let data = try? encoder.jpegData(from: pixel) else { return }
        onFrame(data, timestamp)
    }

    public func stream(_ stream: SCStream, didStopWithError error: Error) {
        isCapturing = false
        pendingStart?.resume(throwing: error)
        pendingStart = nil
    }

    public func contentSharingPicker(_ picker: SCContentSharingPicker, didUpdateWith filter: SCContentFilter, for stream: SCStream?) {
        Task { try? await start(with: filter) }
    }

    public func contentSharingPicker(_ picker: SCContentSharingPicker, didCancelFor stream: SCStream?) {
        pendingStart?.resume(throwing: CancellationError())
        pendingStart = nil
    }

    public func contentSharingPickerStartDidFailWithError(_ error: Error) {
        pendingStart?.resume(throwing: error)
        pendingStart = nil
    }
}
#else
public final class ScreenCaptureKitAdapter:NSObject,CaptureManager,@unchecked Sendable{public private(set)var isCapturing=false;public init(onFrame:@escaping @Sendable(Data,TimeInterval)->Void){};public func start()async throws{throw NSError(domain:"ScreenCaptureKit",code:1,userInfo:[NSLocalizedDescriptionKey:"ScreenCaptureKit não está disponível neste SDK."])};public func stop()async{isCapturing=false}}
#endif
