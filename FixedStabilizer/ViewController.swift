import UIKit
import AVFoundation
import MobileCoreServices


class ViewController: UIViewController,UINavigationControllerDelegate,UIImagePickerControllerDelegate {
    var videoURL:URL = URL(fileURLWithPath: "")
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
//        let u2=Bundle.main.url(forResource: "churchsmall", withExtension: "m4v")
//        printOutVideoQuality(url: u2!)
        // Do any additional setup after loading the view, typically from a nib.
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()    
        // Dispose of any resources that can be recreated.
    }
    @IBAction func loadTestVideo(_ sender: Any) {
        self.videoURL = Bundle.main.url(forResource: "churchsmall", withExtension: "m4v")!
        self.performSegue(withIdentifier: "progressSegue", sender: nil)
        //self.performSegue(withIdentifier: "videoSegue", sender: nil)
    }
    
    @IBAction func unwindToVC1(segue:UIStoryboardSegue) { }

    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        self.videoURL = info[UIImagePickerControllerMediaURL] as! URL
        self.dismiss(animated: true) {
            self.performSegue(withIdentifier: "progressSegue", sender: nil)
        }
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.destination is ProgressViewController {
            let vc = segue.destination as? ProgressViewController
            vc?.videoURL=self.videoURL
        }
    }
    @IBAction func selectVideo(_ sender: Any) {
        let videoPicker=UIImagePickerController()
        videoPicker.delegate=self
        videoPicker.sourceType=UIImagePickerControllerSourceType.photoLibrary
        videoPicker.mediaTypes = [String(kUTTypeMovie)]
        videoPicker.videoMaximumDuration=10.0
        videoPicker.allowsEditing=true
        videoPicker.videoExportPreset=AVAssetExportPresetPassthrough
        //AVAssetExportPresetHEVC3840x2160
        //videoPicker.videoQuality=UIImagePickerControllerQualityType.typeLow
        present(videoPicker, animated: true, completion: nil)
    }
}

