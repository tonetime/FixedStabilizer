#import <Foundation/Foundation.h>
#import "Stats.h"
#import "NSArray+Statistics.h"


@implementation Stats : NSObject {
    //NSMutableArray *sequence;

}
- (id)init {
    self.sequence=[[NSMutableArray alloc] init];
    return self;
}
- (void) addFloatToSequence:(float)f  {
    NSNumber *f1  = [NSNumber numberWithFloat:f];
    [self.sequence addObject:f1 ];
}
- (void) addIntToSequence:(int)f  {
    NSNumber *f1  = [NSNumber numberWithInt:f];
    [self.sequence addObject:f1 ];
}
-(void) printStats:(NSString *)identifer andWithMetric:(NSString *) metric {
    int size = (int)[self.sequence count];
    NSNumber *min = [self.sequence min];
    NSNumber *sum = [self.sequence sum];
    NSNumber *max = [self.sequence max];
    NSNumber *mean = [self.sequence mean];
    //printf("%s\n", [seqstr UTF8String]);
    printf("%s: entries:%i min:%.2ld%s max:%.02f%s mean:%.02f%s sum:%0.2f%s\n",
           [identifer UTF8String],
           size,
           (long)[min floatValue],
           [metric UTF8String],
           [max floatValue],
           [metric UTF8String],
           [mean floatValue],
           [metric UTF8String],
           [sum floatValue],
           [metric UTF8String]
           );
}

@end
