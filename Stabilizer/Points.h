#import <Foundation/Foundation.h>

#ifdef __cplusplus
#import <vector>
#import <opencv2/opencv.hpp>
#import <opencv2/imgproc.hpp>
#endif

@interface Points : NSObject {
}

- (NSMutableArray *) getArrayFromPoints;
- (int) totalPoints;

#ifdef __cplusplus
@property (atomic, readonly) std::vector<cv::Point2f> point2;
- (void)setPoints:(std::vector<cv::Point2f> )p;
#endif

@end

