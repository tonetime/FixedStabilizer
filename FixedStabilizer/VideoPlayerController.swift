
import Foundation
import AVFoundation
import AVKit

class VideoPlayerController: UIViewController,UIGestureRecognizerDelegate {

    var videoURL : URL?
    var obs:NSObjectProtocol?
    var player:AVPlayer?
    var totalFrames:Int = 0
    var fps:Double = 0
    var currentFrame:Int = 0

    @IBAction func goright(_ sender: Any) {
        Utilities.createAlbum(albumName: "Glyph",completion: {_ in
            Utilities.saveVideoAndCheckAuth(MyGlobals.stabilizedURL, album:"Glyph")
            let alertView = UIAlertController(title: "Video Saved", message: "Video Saved to Your Photo Library", preferredStyle: .alert)
            alertView.addAction(UIAlertAction(title: "Ok!", style: .cancel,handler:{  [weak self] action in
                
            }))
            self.present(alertView,animated:true,completion: {
            })
        })
    }
    @IBAction func goleft(_ sender: Any) {
        print("go left")
    }
    @IBAction func goback(_ sender: Any) {
        self.player?.pause()
        performSegue(withIdentifier: "unwind", sender: self)

        //self.dismiss(animated: true, completion: nil)
    }
    override func viewDidLoad() {
    }
    @objc func togglePlayer() {
        if (self.player?.rate==0) {
            self.player?.play()
        }
        else {
            self.player?.pause()
        }
        
        print("do something")
    }

    override func viewDidAppear(_ animated: Bool) {
        
//        let videoURL = URL(string: "https://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4")
        let videoURL = MyGlobals.stabilizedURL
        printOutVideoQuality(url: videoURL)

        self.player = AVPlayer(url: videoURL)
        self.setupObserver()

        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = self.view.bounds
        let asset=self.player?.currentItem?.asset
        let minF=self.player?.currentItem?.asset.tracks(withMediaType: AVMediaType.video).first?.minFrameDuration
        self.fps = Double(minF!.timescale)/Double((minF?.value)!)
        self.totalFrames=Int((CMTimeGetSeconds(asset!.duration) *  self.fps))
        self.view.layer.insertSublayer(playerLayer, at: 0)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(togglePlayer))
        view.addGestureRecognizer(tapGesture)
        self.player?.play()
        
    }
    
    func setupObserver() {
    
        self.obs=NotificationCenter.default.addObserver(forName: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: player?.currentItem, queue: nil)
        { [weak self] notification in
            self!.player?.pause()
            let s=CMTimeMakeWithSeconds(Float64(0),600)
            self!.player?.seek(to: s, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero,
                               completionHandler: { (result) -> Void in
                                self!.player?.play()
            })
        }
        self.obs=(self.player?.addPeriodicTimeObserver(forInterval: CMTime(value: 10, timescale: 1000), queue: nil) { [weak self] time in
            //let t=Float(time.seconds)
            let frame = self?.getFrameForTime(Float(time.seconds))
            self?.currentFrame=frame!
            //let total = self?.totalFrames
            //print("We are on frame \(frame!) out of \(total!)")
        } as! NSObjectProtocol)
    }
    func getFrameForTime(_ t:Float) -> Int {
        let r=Float(self.fps) * t
        return Int(round(r))
    }
}
