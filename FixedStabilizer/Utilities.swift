
import Foundation
import Photos

class Utilities {
    static func getRandomFile() -> URL {
        let tempDir = NSTemporaryDirectory()
        //let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0];
        let filePath="\(tempDir)/GLYPH-" + randomAlphaNumericString(6) + ".mp4"
        return URL(fileURLWithPath: filePath)
    }
    
    
    static func getAssetsInAlbum(albumName:String) -> [PHAsset]{
        var phAssets:[PHAsset] = []
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
        let resultCollections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: fetchOptions)
        resultCollections.enumerateObjects({ (asset, _, _) in
            let oo=PHAsset.fetchAssets(in: asset, options: nil)
            oo.enumerateObjects({a,_,_ in
                phAssets.append(a)
                //                print("^ hmm \(a.localIdentifier) ")
                //                PHImageManager.default().requestAVAsset(forVideo: a, options: nil, resultHandler: {avAsset,_,_ in
                //                 //   print("^ my god apple \(avAsset)")
                //                })
            })
        })
        return phAssets
    }
    
    
    
    static func getAlbum(albumName:String) -> PHAssetCollection? {
        var foundAlbum: PHAssetCollection?
        let albums = PHAssetCollection.fetchAssetCollections(with: PHAssetCollectionType.album, subtype: PHAssetCollectionSubtype.any, options: nil)
        albums.enumerateObjects(options: .concurrent, using: { (album, index, stop) in
            if album.localizedTitle == albumName {
                foundAlbum = album as PHAssetCollection
                stop.pointee = true
            }
        })
        return foundAlbum
    }
    
    
    static func createAlbum(albumName: String, completion: @escaping (PHAssetCollection?)->()) {
        let foundAlbum=Utilities.getAlbum(albumName: albumName)
        if foundAlbum != nil {
            print("Album  \(albumName) was found")
            completion(nil)
            return
        }
        var albumPlaceholder: PHObjectPlaceholder?
        PHPhotoLibrary.shared().performChanges({
            let createAlbumRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
            albumPlaceholder = createAlbumRequest.placeholderForCreatedAssetCollection
        }, completionHandler: { success, error in
            if success {
                guard let placeholder = albumPlaceholder else {
                    completion(nil)
                    return
                }
                let fetchResult = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [placeholder.localIdentifier], options: nil)
                guard let album = fetchResult.firstObject else {
                    completion(nil)
                    return
                }
                completion(album)
            } else {
                completion(nil)
            }
        })
    }
    
    
    static func createAlbumIfDoesntExist(albumName:String, onCompletion: (() -> Void)?) {
        let foundAlbum=Utilities.getAlbum(albumName: albumName)
        if foundAlbum == nil {
            print("Need to init album")
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
                //request.placeholderForCreatedAssetCollection
               // request.placeholderForCreatedAssetCollection
            },
                                                   completionHandler: {(success,error) in
                                                    if(success){
                                                        if (onCompletion != nil) {
                                                            onCompletion!()
                                                        }
                                                        print("Successfully created folder")
                                                    }else{
                                                        
                                                        print("Error creating folder")
                                                    }
            })
        }
        else {
            print("Album  \(albumName) was found")
            if (onCompletion != nil) {
                onCompletion!()
            }
        }
    }
    static func saveVideoAndAddToAlubm(_ url:URL, albumName:String) {
        let album=Utilities.getAlbum(albumName: albumName)
        PHPhotoLibrary.shared().performChanges({ () -> Void in
            if let assetChangeRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url) {
                if album != nil {
                    let asset = assetChangeRequest.placeholderForCreatedAsset!
                    let assets = NSArray(object: asset)
                    let collectionChangeRequest = PHAssetCollectionChangeRequest(for: album!)
                    collectionChangeRequest?.addAssets(assets)
                }
                else {
                    print("Hmm could not find album \(albumName)")
                }
            }
            }
        )
    }
    
    static func saveVideo(_ url:URL) {
        PHPhotoLibrary.shared().performChanges({ () -> Void in
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }, completionHandler: {(success, error) -> Void in
            print("Video saved.")
        }
        )
    }
    static func saveVideoAndCheckAuth(_ url:URL, album:String) {
        if PHPhotoLibrary.authorizationStatus() == .authorized {
            Utilities.saveVideoAndAddToAlubm(url, albumName: album)
        }
        else {
            PHPhotoLibrary.requestAuthorization({ (autorizationStatus) in
                if autorizationStatus == .authorized {
                    Utilities.saveVideoAndAddToAlubm(url, albumName: album)
                }
            })
        }
    }
    
    
    static func randomAlphaNumericString(_ length: Int) -> String {
        let allowedChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let allowedCharsCount = UInt32(allowedChars.characters.count)
        var randomString = ""
        for _ in (0..<length) {
            let randomNum = Int(arc4random_uniform(allowedCharsCount))
            let newCharacter = allowedChars[allowedChars.characters.index(allowedChars.startIndex, offsetBy: randomNum)]
            randomString += String(newCharacter)
        }
        return randomString
    }
    static func getFrameForTime(_ t:Float, fps:Float) -> Int {
        let r=fps * t
        return Int(round(r))
    }
    static func currentTimeMillis() -> Int64{
        let nowDouble = Date().timeIntervalSince1970
        return Int64(nowDouble*1000)
    }
    
    static func createVideoSettings(_ asset:AVAsset, frameRate:Float=24.0, frameInterval:Int=1,inverseWidthHeight:Bool=false) -> [String:NSObject] {
        let assetTrack = asset.tracks(withMediaType: AVMediaType.video).first!
        let size = assetTrack.naturalSize
        var w=size.width
        var h=size.height
        if inverseWidthHeight {
            w=size.height
            h=size.width
        }
        let numPixels = w*h
        var bitsPerSecond: Int
        var bitsPerPixel: Float
        if numPixels < 640 * 480 {
            bitsPerPixel = 4.05; // This bitrate approximately matches the quality produced by AVCaptureSessionPresetMedium or Low.
        } else {
            bitsPerPixel = 10.1; // This bitrate approximately matches the quality produced by AVCaptureSessionPresetHigh.
        }
        bitsPerSecond = Int(Float(numPixels) * bitsPerPixel)
        bitsPerSecond = Int(Double(bitsPerSecond))
        let compressionProperties: NSDictionary = [AVVideoAverageBitRateKey : bitsPerSecond,
                                                   AVVideoExpectedSourceFrameRateKey : frameRate,
                                                   AVVideoMaxKeyFrameIntervalKey : frameInterval]
        let settings = [AVVideoCodecKey : AVVideoCodecType.h264,
                        AVVideoWidthKey : w,
                        AVVideoHeightKey : h,
                        AVVideoCompressionPropertiesKey : compressionProperties] as [String : Any]
        print(settings)
        return settings as! [String : NSObject]
    }
}
