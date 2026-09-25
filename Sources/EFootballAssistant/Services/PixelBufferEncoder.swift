import Foundation
#if canImport(CoreVideo) && canImport(ImageIO) && canImport(CoreImage)
import CoreVideo
import CoreGraphics
import CoreImage
import ImageIO

public enum PixelBufferEncoderError:Error{case invalidBuffer;case cannotCreateDestination;case cannotEncode}
public struct PixelBufferEncoder:Sendable{public init(){};public func jpegData(from pixelBuffer:CVPixelBuffer,quality:Double=0.72)throws->Data{let ci=CIImage(cvPixelBuffer:pixelBuffer);let context=CIContext();guard let cg=context.createCGImage(ci,from:ci.extent)else{throw PixelBufferEncoderError.invalidBuffer};let data=NSMutableData();guard let dest=CGImageDestinationCreateWithData(data,"public.jpeg" as CFString,1,nil)else{throw PixelBufferEncoderError.cannotCreateDestination};CGImageDestinationAddImage(dest,cg,[kCGImageDestinationLossyCompressionQuality:quality] as CFDictionary);guard CGImageDestinationFinalize(dest)else{throw PixelBufferEncoderError.cannotEncode};return data as Data}}
#endif
