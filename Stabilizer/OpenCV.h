#import <opencv2/opencv.hpp>
#import <UIKit/UIKit.h>
#import "Points.h"

@interface OpenCV : NSObject

+ (UIImage *) drawFeatures:(UIImage *) image andFeatures:(NSArray * ) features;
+ (UIImage *)cvtColorBGR2GRAY:(UIImage *)image;
+ (Points *) goodFeaturesToTrack:(UIImage *) image andConvertToGray:(BOOL) convertToGray;
+ (Points *) goodFeaturesToTrack:(UIImage *) image
                andConvertToGray:(BOOL) convertToGray
                       andPoints:(int) points
                 andQualityLevel:(double) qualityLevel
                  andMinDistance:(double) minDistance
                     andSubPixel:(BOOL) subPixel;

#ifdef __cplusplus

//static void UIImageToMat(UIImage *image, cv::Mat &mat);


+ (Points *) goodFeaturesToTrackMat:(cv::Mat) grayMat
                          andPoints:(int) points
                    andQualityLevel:(double) qualityLevel
                     andMinDistance:(double) minDistance
                        andSubPixel:(BOOL) subPixel;
+ (Points *) goodFeaturesToTrackMat:(cv::Mat) grayMat;

+ (UIImage *) drawFeaturesStd:(UIImage *) image andFeatures:(std::vector<cv::Point2f>) features;


#endif

@end
