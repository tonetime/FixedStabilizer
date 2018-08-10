
#import <vector>
#import <opencv2/opencv.hpp>
#import <opencv2/imgproc.hpp>
#import <Foundation/Foundation.h>
#import "Points.h"


@implementation Points : NSObject {
}
@synthesize point2;

//- (void)dealloc {
//    //_bar.clear();
//NSLog(@"hi %i", point2.size());
//delete &point2;
//}

- (NSMutableArray *) getArrayFromPoints {
    NSMutableArray *ptsArray = [[NSMutableArray alloc] init];
    for (int i=0; i < point2.size(); i++) {
        NSArray *point = @[ [NSNumber numberWithFloat:point2[i].x], [NSNumber numberWithFloat:point2[i].y]  ];
        [ptsArray addObject:point];
    }
    return ptsArray;
}

- (int) totalPoints {
    return int(point2.size());
}

#ifdef __cplusplus
- (void)setPoints:(std::vector<cv::Point2f> )p {
    point2=p;
}
#endif

@end

