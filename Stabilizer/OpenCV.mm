#import <vector>
#import <opencv2/opencv.hpp>
#import <opencv2/imgproc.hpp>
#import <Foundation/Foundation.h>
#import "OpenCV.h"
#import "Points.h"




/// Converts an UIImage to Mat.
/// Orientation of UIImage will be lost.
static void UIImageToMat(UIImage *image, cv::Mat &mat) {
    // Create a pixel buffer.
    NSInteger width = CGImageGetWidth(image.CGImage);
    NSInteger height = CGImageGetHeight(image.CGImage);
    CGImageRef imageRef = image.CGImage;
    cv::Mat mat8uc4 = cv::Mat((int)height, (int)width, CV_8UC4);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef contextRef = CGBitmapContextCreate(mat8uc4.data, mat8uc4.cols, mat8uc4.rows, 8, mat8uc4.step, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrderDefault);
    CGContextDrawImage(contextRef, CGRectMake(0, 0, width, height), imageRef);
    CGContextRelease(contextRef);
    CGColorSpaceRelease(colorSpace);
    // Draw all pixels to the buffer.
    cv::Mat mat8uc3 = cv::Mat((int)width, (int)height, CV_8UC3);
    cv::cvtColor(mat8uc4, mat8uc3, CV_RGBA2BGR);
    mat = mat8uc3;
}

/// Converts a Mat to UIImage.
static UIImage *MatToUIImage(cv::Mat &mat) {
    // Create a pixel buffer.
    assert(mat.elemSize() == 1 || mat.elemSize() == 3);
    cv::Mat matrgb;
    if (mat.elemSize() == 1) {
        cv::cvtColor(mat, matrgb, CV_GRAY2RGB);
    } else if (mat.elemSize() == 3) {
        cv::cvtColor(mat, matrgb, CV_BGR2RGB);
    }
    
    // Change a image format.
    NSData *data = [NSData dataWithBytes:matrgb.data length:(matrgb.elemSize() * matrgb.total())];
    CGColorSpaceRef colorSpace;
    if (matrgb.elemSize() == 1) {
        colorSpace = CGColorSpaceCreateDeviceGray();
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    CGImageRef imageRef = CGImageCreate(matrgb.cols, matrgb.rows, 8, 8 * matrgb.elemSize(), matrgb.step.p[0], colorSpace, kCGImageAlphaNone|kCGBitmapByteOrderDefault, provider, NULL, false, kCGRenderingIntentDefault);
    UIImage *image = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return image;
}

#pragma mark -

@implementation OpenCV

+ (cv::Mat) drawFeaturesMat:(cv::Mat) image andFeatures:(NSArray * ) features {
    CvScalar yellow = CV_RGB(255,255,0);
    for (int i=0; i < [features count]; i++) {
        NSNumber *x= features[i][0];
        NSNumber *y= features[i][1];
        CvPoint p = CvPoint( [x floatValue],[y floatValue]);
        cv::circle(image, p, 3, yellow);
    }
    return image;
}

+ (UIImage *) drawFeaturesStd:(UIImage *) image andFeatures:(std::vector<cv::Point2f>) features {
    //CvScalar yellow = CV_RGB(255,255,0);
    //cv::circle(image, features, 3, yellow);
    return nil;
    
}
+ (UIImage *) drawFeatures:(UIImage *) image andFeatures:(NSArray * ) features {
    cv::Mat bgrMat;
    UIImageToMat(image, bgrMat);
    [OpenCV drawFeaturesMat:bgrMat andFeatures:features];
    UIImage *i = MatToUIImage(bgrMat);
    
    return i;
}

+ (Points *) goodFeaturesToTrack:(UIImage *) image andConvertToGray:(BOOL) convertToGray {
    return [OpenCV goodFeaturesToTrack:image andConvertToGray:convertToGray andPoints:1000 andQualityLevel:0.01 andMinDistance:10 andSubPixel:true];
}


+ (Points *) goodFeaturesToTrack:(UIImage *) image
                andConvertToGray:(BOOL) convertToGray
                       andPoints:(int) points
                 andQualityLevel:(double) qualityLevel
                  andMinDistance:(double) minDistance
                     andSubPixel:(BOOL) subPixel {
    
    cv::Mat imageMat;
    cv::Mat grayMat;
    std::vector<cv::Point2f> pts(points);
    
    UIImageToMat(image, imageMat);
    
    if (convertToGray) {
        cv::cvtColor(imageMat, grayMat, CV_BGR2GRAY);
    }
    else {
        grayMat=imageMat;
    }
    return [OpenCV goodFeaturesToTrackMat:grayMat andPoints:points andQualityLevel:qualityLevel andMinDistance:minDistance andSubPixel:subPixel];
    
}

+ (Points *) goodFeaturesToTrackMat:(cv::Mat) grayMat {
    return [OpenCV goodFeaturesToTrackMat:grayMat andPoints:500 andQualityLevel:0.01   andMinDistance:10 andSubPixel:true];
}


+ (Points *) goodFeaturesToTrackMat:(cv::Mat) grayMat
                          andPoints:(int) points
                    andQualityLevel:(double) qualityLevel
                     andMinDistance:(double) minDistance
                        andSubPixel:(BOOL) subPixel {
    
    std::vector<cv::Point2f> pts(points);
    Points *featurePoints=[[Points alloc] init];
    cv::goodFeaturesToTrack(grayMat, pts, points, qualityLevel, minDistance);
    //NSLog(@"Goodfeatures params:  Points:%i Quality:%f MinDistance:%f ", points,qualityLevel,minDistance);
    if (subPixel) {
        //criteria = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 100, 0.001)
        cv::cornerSubPix(grayMat, pts, cv::Size(5, 5), cv::Size(-1, -1), cv::TermCriteria(CV_TERMCRIT_EPS + CV_TERMCRIT_ITER,100,0.001) );
    }
    [featurePoints setPoints:pts];
    return featurePoints;
}

+ (UIImage *)cvtColorBGR2GRAY:(UIImage *)image {
    Points *foo2=[[Points alloc] init];
    std::vector<cv::Point2f> pts(10);
    [foo2 setPoints:pts];
    
    cv::Mat bgrMat;
    UIImageToMat(image, bgrMat);
    cv::Mat grayMat;
    cv::cvtColor(bgrMat, grayMat, CV_BGR2GRAY);
    UIImage *grayImage = MatToUIImage(grayMat);
    return grayImage;
}

@end
