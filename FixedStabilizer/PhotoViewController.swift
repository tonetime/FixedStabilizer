import Foundation

class PhotoViewController: UIViewController,UIGestureRecognizerDelegate {
    @IBOutlet weak var image: UIImageView!
    @IBOutlet weak var frameCount: UILabel!
    var idx:Int = 0
    
    override func viewDidLoad() {
    }
    override func viewDidAppear(_ animated: Bool) {
        print("add image??")
        self.image.contentMode=UIViewContentMode.scaleAspectFit
        applyStuf()
    }
    @IBAction func goback(_ sender: Any) {
        
    }
    @IBAction func goright(_ sender: Any) {
        idx+=1
        if (idx > (MyGlobals.images.count-1)) {
            idx = 0
        }
        applyStuf()
    }
    @IBAction func goleft(_ sender: Any) {
        idx-=1
        if (idx < 0) {
            idx = (MyGlobals.images.count - 1)
        }
        applyStuf()
    }
    func applyStuf() {
        setFrameLabel()
        self.image.image=nil
        var i = MyGlobals.images[idx] as UIImage
        //print("Image \( i.size.width) x \(i.size.height)  ")
        let b = i.size.width > i.size.height ? i.size.width : i.size.height
        let  scaleDown = b / CGFloat(640)
        i = i.scaleImageToSize(newSize: CGSize(width: i.size.width / scaleDown, height: i.size.height / scaleDown))
        //Have a label for the scaled image size.  And (if applicable the amount of features shown).
        self.image.image = i
    }
    func setFrameLabel() {
        self.frameCount.text="Frames \(idx) of \(MyGlobals.images.count)"
    }
}
