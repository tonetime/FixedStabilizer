#import <vector>
#import <opencv2/opencv.hpp>
#import <opencv2/imgproc.hpp>
#import <Foundation/Foundation.h>
#import "StatusWrapper.h"


@implementation StatusWrapper  {
    NSMutableArray *fstatusArry;
}
@synthesize fstatus;

//- (void)dealloc {
//    //_bar.clear();
//NSLog(@"hi %i", point2.size());
//delete &point2;
//}

- (NSMutableArray *) statusArray {
    NSMutableArray *arr = [NSMutableArray arrayWithCapacity:fstatus.size()];
    for (int i=0; i < fstatus.size(); i++) {
        int z=fstatus[i];
        [arr addObject:[NSNumber numberWithInt:z]];
    }
    fstatusArry=arr;
    return fstatusArry;
}




#ifdef __cplusplus
- (void)setFstatus:(std::vector<unsigned char>)f{
    fstatus=f;
}
#endif

@end
