

#import "OpenCV.h"
#import <UIKit/UIKit.h>
#import "Points.h"
#import "StatusWrapper.h"

@interface FrameFeature : NSObject


@property Points *points;
@property Points *startingPoints;
@property StatusWrapper *pointStatus;
@property NSMutableArray *distances;
@property int *frameIndex;
@property double *distance;
@property double *trim;
@property bool validFrame;

- (id)initWithFeatureData:(Points *) points
        andStartingPoints:(Points *) startingPoints
           andPointStatus:(StatusWrapper *) pointStatus
            andFrameIndex:(int *) frameIndex;
- (void) calcDistance;
- (double) getDistanceMean;
- (bool) validFrame;


+(double) findLargestTrimRatio:(NSMutableArray *) frameFeatures;
+ (NSMutableArray *) calcDistanceForPoints:(Points *) points1 a:(Points *) points2;
+ (double) distanceToPoint:(double) x1 x2:(double) x2 y1:(double) y1 y2:(double) y2;

#ifdef __cplusplus
@property (atomic, readonly)  std::vector< std::vector <cv::Point2f>> reducedPoints;
- (void)setReductedPoints:(std::vector< std::vector <cv::Point2f>> )reduced;

#endif


@end
