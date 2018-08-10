#import <Foundation/Foundation.h>

#ifdef __cplusplus
#import <vector>
#import <opencv2/opencv.hpp>
#import <opencv2/imgproc.hpp>
#endif

@interface StatusWrapper : NSObject {
}

- (NSMutableArray *) statusArray;

#ifdef __cplusplus
@property (atomic, readonly) std::vector<unsigned char> fstatus;
- (void)setFstatus:(std::vector<unsigned char> )fstatus;

#endif

@end

