import UIKit
import AVFoundation
import MobileCoreServices

class ProgressViewController: UIViewController {
    var videoURL:URL = URL(fileURLWithPath: "")
    var skipPctThreshold=Float(0.40)

    @IBOutlet weak var progressOutlet: UIProgressView!
    @IBOutlet weak var status: UILabel!
    

    override func viewDidLoad() {
    }
    override func viewDidAppear(_ animated: Bool) {
        self.progressOutlet.progress=0
        
        self.status.text="Loading"
        printOutVideoQuality(url: self.videoURL)
//        let s=FixedStabilizer.sharedInstance()
        let s = FixedStabilizer()
        
        self.status.text="Processing Optical Flow"
        s.processVideo(self.videoURL)
      //  let images1 = s?.processVideo(self.videoURL, andSaveImages: true) as! NSArray
//        for i in MyGlobals.images {
//            print(i)
//        }
        
        
        
        self.status.text="Calculating Transforms"
        s.postProcess()
       // let images = s?.drawFeatures(images1 as! [Any])
       // MyGlobals.images = s?.drawFeatures(images1 as! [Any]) as! [UIImage]

       // self.performSegue(withIdentifier: "photoID", sender: nil)


      //  return

        let pct=s.skippedFramesPct()
        if (pct > skipPctThreshold) {
            let alertView = UIAlertController(title: "Cannot Stabilize", message: "Could not perform fixed stabilization. Initial Video Needs to be more stable.\n", preferredStyle: .alert)
            alertView.addAction(UIAlertAction(title: "Go Back", style: .cancel,handler:{  [weak self] action in
                self?.dismiss(animated: true, completion: nil)
            }))
            present(alertView,animated:true,completion: {
            })
        }
        else {
            let a=AVAsset(url: self.videoURL)
            let settings=createVideoSettings(a)
            print(settings)
            do {
                try FileManager.default.removeItem(at: MyGlobals.stabilizedURL)
            }
            catch {
                // print(error)
            }
            //let saveFile = Utilities.getRandomFile()
            MyGlobals.stabilizedURL=Utilities.getRandomFile()
            var transform=a.tracks(withMediaType: AVMediaType.video).first?.preferredTransform
            if (transform == nil) { transform=CGAffineTransform.identity }
            let movie=CEMovieMaker(settings: settings, andSave: MyGlobals.stabilizedURL, andTransform: transform!)
            self.status.text="Transforming Video"
            s.applyVideoTransform(self.videoURL, andMovie: movie, andShowPoints: false)
            movie?.finish({()->Void in
                do {
                    let attr : NSDictionary? = try FileManager.default.attributesOfItem(atPath: MyGlobals.stabilizedURL.path) as NSDictionary?
                    if let _attr = attr {
                        let ff = (_attr.fileSize())/1024/1024;
                        print("File saved at  \(ff) MB")                        
                        s.cleanUp()
                        self.performSegue(withIdentifier: "videoSegue", sender: nil)
                    }
                } catch { }
            })
        }
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
    }
    func createVideoSettings(_ asset:AVAsset) -> [String:NSObject] {
        let assetTrack = asset.tracks(withMediaType: AVMediaType.video).first!
        let size = assetTrack.naturalSize
        let frameRate=assetTrack.nominalFrameRate
        let w=size.width
        let h=size.height
        let numPixels = w*h
        var bitsPerSecond: Int
        var bitsPerPixel: Float
        if numPixels <= 640 * 480 {
            bitsPerPixel = 14.05; // This bitrate approximately matches the quality produced by AVCaptureSessionPresetMedium or Low.
        }
        else if numPixels <= 1900 * 1200 {
            bitsPerPixel  = 5.0
        }
        else {
            bitsPerPixel = 3.1;
        }
        bitsPerSecond = Int(Float(numPixels) * bitsPerPixel)
        bitsPerSecond = Int(Double(bitsPerSecond))
        print("bites per pixel \(bitsPerPixel) \(bitsPerSecond) to ")

        let compressionProperties: NSDictionary = [AVVideoAverageBitRateKey : bitsPerSecond,
                                                   AVVideoExpectedSourceFrameRateKey : frameRate,
                                                   AVVideoMaxKeyFrameIntervalKey : 20]
        let settings = [AVVideoCodecKey : AVVideoCodecType.h264,
                        AVVideoWidthKey : w,
                        AVVideoHeightKey : h,
                        AVVideoCompressionPropertiesKey : compressionProperties] as [String : Any]
        print("Settings for saving final movie: \(settings)")
        return settings as! [String : NSObject]
    }

}
