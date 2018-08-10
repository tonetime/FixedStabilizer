
#import <opencv2/opencv.hpp>
#import "Points.h"
#import "StatusWrapper.h"
#import "FrameFeature.h"
#import <Foundation/Foundation.h>

@implementation FrameFeature : NSObject {
    
}

@synthesize reducedPoints;
@synthesize validFrame;

-(id) initWithFeatureData:(Points *)points andStartingPoints:(Points *)startingPoints andPointStatus:(StatusWrapper *)pointStatus andFrameIndex:(int *)frameIndex {
    self = [super init];
    self.points=points;
    self.startingPoints=startingPoints;
    self.pointStatus=pointStatus;
    self.frameIndex=frameIndex;
    self.validFrame=true;
    return self;
}

#ifdef __cplusplus
- (void)setReductedPoints:(std::vector< std::vector <cv::Point2f>> )reduced {
    reducedPoints=reduced;
}
#endif

- (NSComparisonResult)compare:(FrameFeature *)otherObject {
    if (self.frameIndex==otherObject.frameIndex) {
        return NSOrderedSame;
    }
    else if (self.frameIndex > otherObject.frameIndex) {
        return NSOrderedDescending;
    }
    else {
        return NSOrderedAscending;
    }
}



- (void) calcDistance {
    self.distances=[FrameFeature calcDistanceForPoints:self.points a:self.startingPoints];
}

- (double) getDistanceMean {
    double distanceMean=[self mean:self.distances];
    return distanceMean;
}
- (double) mean:(NSArray *) arr {
    double sum=0.0;
    int greaterThan10=0;
    for (int i=0; i < arr.count; i++) {
        double d= [arr[i] doubleValue];
        sum += d;
        if (d > 20 ) {
            greaterThan10++;
        }
        if (d > 100) {
            //  NSLog(@"Distance is %f",d);
            
        }
        
    }
    
    //float m=sum/arr.count;
    //NSLog(@"%i : Distances >100 %i,  Mean: %f", self.frameIndex, greaterThan10,m);
    return sum/arr.count;
}

+(double) findLargestTrimRatio:(NSMutableArray *) frameFeatures {
    return 0.0;
}
+ (NSMutableArray *) calcDistanceForPoints:(Points *) points1 a:(Points *) points2 {
    std::vector<cv::Point2f> pww1 = points1.point2;
    std::vector<cv::Point2f> pww2 = points2.point2;
    int size=  int(pww1.size());
    NSMutableArray *myArray = [NSMutableArray arrayWithCapacity:size];
    for (int i=0; i < size; i++) {
        double d=[FrameFeature distanceToPoint:pww1[i].x x2:pww2[i].x y1:pww1[i].y y2:pww2[i].y];
        [myArray addObject: [NSNumber numberWithDouble:d]];
    }
    return myArray;
}
+ (double) distanceToPoint:(double) x1 x2:(double) x2 y1:(double) y1 y2:(double) y2 {
    double dx = x1 - x2;
    double dy = y1 - y2;
    double distance= sqrtf(dx*dx + dy*dy);
    //NSLog(@"P1 (%lf,%lf) -> P2(%lf,%lf) = %lf",x1,y1,x2,y2,distance);
    return distance;
}
@end
