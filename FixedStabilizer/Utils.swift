import Foundation
import AVFoundation

struct MyGlobals {
    static let unstabilizedSavedURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("tmp2.mp4")
    //static let stabilizedURL=URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("stabletmp2.mp4")
    static var stabilizedURL=URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("stabletmp.mp4")
    static var images=Array<UIImage>()
    
}

func printOutVideoQuality(url:URL) {
    let asset = AVAsset(url: url)
    let seconds = String(format:"%.2fs",CMTimeGetSeconds(asset.duration))
    let fileSize = AVURLAsset(url: url).fileSize
    guard let track = AVURLAsset(url: url).tracks(withMediaType: AVMediaType.video).first  else { return }
    let size = track.naturalSize
    let bps = String(format: "%.2fmbps", (track.estimatedDataRate/1024/1024))
    let frameRate=track.nominalFrameRate
    let keys = keyframes(inputUrl: url)
    print("\(Int(size.width))x\(Int(size.height)) @\(frameRate)fps fileSize:\(fileSize) \(seconds) \(track.mediaFormat) \(bps) [\(keys)]"  )
}

extension UIImage {
    
    
    /// Scales an image to fit within a bounds with a size governed by the passed size. Also keeps the aspect ratio.
    /// Switch MIN to MAX for aspect fill instead of fit.
    ///
    /// - parameter newSize: newSize the size of the bounds the image must fit within.
    ///
    /// - returns: a new scaled image.
    func scaleImageToSize(newSize: CGSize) -> UIImage {
        var scaledImageRect = CGRect.zero
        
        let aspectWidth = newSize.width/size.width
        let aspectheight = newSize.height/size.height
        
        let aspectRatio = max(aspectWidth, aspectheight)
        
        scaledImageRect.size.width = size.width * aspectRatio;
        scaledImageRect.size.height = size.height * aspectRatio;
        scaledImageRect.origin.x = (newSize.width - scaledImageRect.size.width) / 2.0;
        scaledImageRect.origin.y = (newSize.height - scaledImageRect.size.height) / 2.0;
        
        UIGraphicsBeginImageContext(newSize)
        draw(in: scaledImageRect)
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return scaledImage!
    }
}

extension AVURLAsset {
    var fileSize: String {
        let keys: Set<URLResourceKey> = [.totalFileSizeKey, .fileSizeKey]
        let resourceValues = try? url.resourceValues(forKeys: keys)
        let size = (resourceValues?.fileSize ?? resourceValues?.totalFileSize) ?? 0
        let mb = (Float(size))/1024/1024
        return String(format: "%.2fMB", mb)
    }
}
func keyframes(inputUrl:URL) -> String {
    let asset = AVAsset(url: inputUrl)
    let reader = try! AVAssetReader(asset: asset)
    
    let videoTrack = asset.tracks(withMediaType: AVMediaType.video)[0]
    let trackReaderOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: nil)
    
    reader.add(trackReaderOutput)
    reader.startReading()
    
    var numFrames = 0
    var keyFrames = 0
    
    while true {
        if let sampleBuffer = trackReaderOutput.copyNextSampleBuffer() {
            // NB: not every sample buffer corresponds to a frame!
            if CMSampleBufferGetNumSamples(sampleBuffer) > 0 {
                numFrames += 1
                if let attachmentArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, false)  {
                    let x = attachmentArray as NSArray
                    let attachment = x[0] as! NSDictionary
                    // print("attach on frame \(frame): \(attachment)")
                    if let depends = attachment[kCMSampleAttachmentKey_DependsOnOthers] as? NSNumber {
                        if !depends.boolValue {
                            keyFrames += 1
                        }
                    }
                }
            }
        } else {
            break
        }
    }
    
    return "\(keyFrames)keys - \(numFrames) frames"
}


extension AVAssetTrack {
    var mediaFormat: String {
        var format = ""
        let descriptions = self.formatDescriptions as! [CMFormatDescription]
        for (index, formatDesc) in descriptions.enumerated() {
            // Get String representation of media type (vide, soun, sbtl, etc.)
            let type =
                CMFormatDescriptionGetMediaType(formatDesc).toString()
            // Get String representation media subtype (avc1, aac, tx3g, etc.)
            let subType =
                CMFormatDescriptionGetMediaSubType(formatDesc).toString()
            // Format string as type/subType
            format += "\(type)/\(subType)"
            // Comma separate if more than one format description
            if index < descriptions.count - 1 {
                format += ","
            }
        }
        return format
    }
}

extension FourCharCode {
    // Create a String representation of a FourCC
    func toString() -> String {
        let bytes: [CChar] = [
            CChar((self >> 24) & 0xff),
            CChar((self >> 16) & 0xff),
            CChar((self >> 8) & 0xff),
            CChar(self & 0xff),
            0
        ]
        let result = String(cString: bytes)
        let characterSet = CharacterSet.whitespaces
        return result.trimmingCharacters(in: characterSet)
    }
}
