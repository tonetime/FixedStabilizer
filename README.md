
# FixedStabilizer

Proof of Concept app is intended to help create cinemagraphs without a tripod. Recording a scene by hand will always incur some level of instability. This app tracks the optical flow of the video and sets the best fixed points to provide 'tripod like' stabliization. 

Examples hand held recordings stabilized are here: https://flixel.com/george2222/

# Install

1. Clone repo: https://github.com/tonetime/FixedStabilizer
2. Download opencv framework for iOS: https://opencv.org/opencv-3-3.html
3. Copy framework into FixedStabilizer Project: cp -r opencv2-3.framework/ ~/Downloads/FixedStabilizer-master/opencv2.framework (make sure to call it opencv2.framework)
4. Add framework in Targets->Build Phases-> Link Binary with Libraries


