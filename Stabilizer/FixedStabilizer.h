#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import "Points.h"
#import "CEMovieMaker.h"

@interface FixedStabilizer : NSObject

//-(NSArray *) processVideo:(NSArray *) images;

@property NSMutableArray *frameFeatures;
@property NSArray* stdDeviations;
@property bool postProcessDone;


+ (FixedStabilizer *)sharedInstance;
+ (void)resetSharedInstance;
- (void) postProcess;
- (void) processVideo:(NSURL *) url;
- (NSArray *) processVideo:(NSURL *) url andSaveImages:(bool) saveImages;
- (NSArray *) processImages:(NSArray *) images;
- (float) skippedFramesPct;
- (NSArray *) applyVideoTransform:(NSURL *) sourceUrl  andMovie:(CEMovieMaker *) movie andShowPoints:(bool) showPoints;
- (NSArray *) drawFeatures:(NSArray *) images;
- (void) cleanUp;



@end
