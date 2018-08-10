

@interface Stats : NSObject {
}
@property (nonatomic, strong) NSMutableArray *sequence;
- (void) addFloatToSequence:(float)f;
- (void) addIntToSequence:(int)f;
-(void) printStats:(NSString *)identifer andWithMetric:(NSString *) metric;
@end


