#import "NSArray+Statistics.h"

@implementation NSArray (Statistics)

- (NSNumber *)sum {
    NSNumber *sum = [self valueForKeyPath:@"@sum.self"];
    return sum;
}

- (NSNumber *)mean {
    NSNumber *mean = [self valueForKeyPath:@"@avg.self"];
    return mean;
}

- (NSNumber *)min {
    NSNumber *min = [self valueForKeyPath:@"@min.self"];
    return min;
}

- (NSNumber *)max {
    NSNumber *max = [self valueForKeyPath:@"@max.self"];
    return max;
}

- (NSNumber *)median {
    NSArray *sortedArray = [self sortedArrayUsingSelector:@selector(compare:)];
    NSNumber *median;
    if (sortedArray.count != 1) {
        if (sortedArray.count % 2 == 0) {
            median = @(([[sortedArray objectAtIndex:sortedArray.count / 2] integerValue]) + ([[sortedArray objectAtIndex:sortedArray.count / 2 + 1] integerValue]) / 2);
        }
        else {
            median = @([[sortedArray objectAtIndex:sortedArray.count / 2] integerValue]);
        }
    }
    else {
        median = [sortedArray objectAtIndex:1];
    }
    return median;
}

- (NSNumber *)standardDeviation {
    double sumOfDifferencesFromMean = 0;
    for (NSNumber *score in self) {
        sumOfDifferencesFromMean += pow(([score doubleValue] - [[self mean] doubleValue]), 2);
    }
    
    NSNumber *standardDeviation = @(sqrt(sumOfDifferencesFromMean / self.count));
    
    return standardDeviation;
}

@end
