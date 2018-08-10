#include <iostream>

#import <opencv2/opencv.hpp>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "FixedStabilizer.h"
#import "Points.h"
#import "OpenCV.h"
#import "Trim.hpp"
#import "StatusWrapper.h"
#import "FrameFeature.h"
#import "Stats.h"
#import "CEMovieMaker.h"


static float VIDEO_SCALE_FACTOR = 0.5; //scale the video down for performance.
static int MAX_CORNERS=500;

@implementation FixedStabilizer  {
    cv::Mat startingMat;
    std::vector<cv::Point2f> startPoints;
    std::vector<cv::Point2f> originalStartingPoints;
    std::vector<cv::Mat>  startingPyramid;
    std::vector<cv::Mat>  currentPyramid;
    std::vector<cv::Mat>  transforms;
    std::vector< std::vector <cv::Point2f>>  reducedPoints;
    Trim trim;
    int frameCount;
    int skippedFrames;
    float maxTrim;
    
    Points *startingPoints;
    dispatch_queue_t queue;
    dispatch_group_t goodPointsGroup;
    dispatch_group_t opticalFlowGroup;
    CIContext *context;
    NSArray *stdMask;
    NSArray *offsetMask;
    cv::Size frameSize;
    cv::Size realFrameSize;
    std::vector<PyramidHold> pyramids;

}

+ (void)resetSharedInstance {
    sharedInstance = nil;
}
static FixedStabilizer  *sharedInstance = nil;
// Get the shared instance and create it if necessary.
+ (FixedStabilizer *)sharedInstance {
    if (sharedInstance == nil) {
        sharedInstance = [[FixedStabilizer alloc] init];
    }
    return sharedInstance;
}

- (void) cleanUp {
    pyramids.clear();
    reducedPoints.clear();
    pyramids.shrink_to_fit();
    reducedPoints.shrink_to_fit();
    self->pyramids.reserve(1024*1024);
    self->context=nil;
}

- (id) init {
    self->queue=dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    self.frameFeatures=[[NSMutableArray alloc] init];
    frameCount=0;
    skippedFrames=0;
    maxTrim=0;
    self->pyramids.reserve(1024*1024);
    self->goodPointsGroup=dispatch_group_create();
    self->opticalFlowGroup=dispatch_group_create();
    self->startingPoints=[[Points alloc] init];
    return self;
}

- (void) processVideo:(NSURL *) url {
    [self processVideo:url andSaveImages:false];
}

- (float) skippedFramesPct {
    return float(skippedFrames)/float(frameCount);
}

//saveImages parameter for debugging purposes.
-(NSArray *) processVideo:(NSURL *) url andSaveImages:(bool) saveImages {
    Stats *s1 = [[Stats alloc] init];
    NSMutableArray *images= [[NSMutableArray alloc] init];
    int imageFramesProcessed=0;
    AVAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
    AVAssetReader *assetReader = [[AVAssetReader alloc] initWithAsset:asset error:NULL];
    AVAssetTrack *videoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    NSDictionary *outputSettings = @{(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8Planar)};
    //NSDictionary *outputSettings = @{(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)};
    AVAssetReaderTrackOutput *assetReaderOutput=[[AVAssetReaderTrackOutput alloc] initWithTrack:videoTrack outputSettings:outputSettings];
    assetReaderOutput.alwaysCopiesSampleData=false;
    [assetReader addOutput:assetReaderOutput];
    [assetReader startReading];
    
    CMSampleBufferRef sample=[assetReaderOutput copyNextSampleBuffer];
    while (sample != nil) {
        long long m1 = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
        UIImage *i=nil;
        //if ((ccc==0 || ccc==150 || ccc==200)) {
        i=[self processFrame:sample andSaveImages:saveImages];
        //}
        long long m2 = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
        //NSLog(@"Time to process frame %llu ms", (m2-m1));
        [s1 addFloatToSequence:(m2-m1)];
        
        //printf("Time to process frame %llu ms\n", (m2-m1));
        CFRelease(sample);
        sample=[assetReaderOutput copyNextSampleBuffer];
        if (saveImages && imageFramesProcessed < 100 && i != nil) {
            [images addObject:i];
        }
        imageFramesProcessed++;
    }
    [s1 printStats:@"Frame Processing" andWithMetric:@"ms"];
    return images;
}

-(NSArray *) processImages:(NSArray *) images {
    for (id image in images) {
        cv::Mat img;
        UIImageToMat(image, img);
        cv::Mat grayMat;
        cv::cvtColor(img, grayMat, CV_BGR2GRAY);
        [self processFrameMat:grayMat];
    }
    return nil;
}

//assuming a planar buffer.
- (UIImage *) processFrame:(CMSampleBufferRef) ref andSaveImages:(bool) saveImages {
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(ref);
    CVPixelBufferLockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
    void *grayscalePixels = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);
    int bufferWidth = (int)CVPixelBufferGetWidth(imageBuffer);
    int bufferHeight = (int)CVPixelBufferGetHeight(imageBuffer);
    cv::Mat grayMat = cv::Mat(bufferHeight,bufferWidth,CV_8UC1,grayscalePixels); //put buffer in open cv, no memory copied
    // long long m1 = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0)
    [self processFrameMat:grayMat];
    //long long m2 = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
    //NSLog(@"Time to resize %llu ms", (m2-m1));
    CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
    if (saveImages==true) {
        return MatToUIImage(grayMat);
    }
    else {
        grayMat.release();
        return nil;

    }
}

- (void)processFrameMat:(cv::Mat )mat {
    if (VIDEO_SCALE_FACTOR != 1.0) {
        cv::Mat scaledMat;
        cv::Size scaledSize=cv::Size(mat.cols*VIDEO_SCALE_FACTOR,mat.rows*VIDEO_SCALE_FACTOR);
        cv::resize(mat, scaledMat, scaledSize);
        mat=scaledMat;
    }
    if (self->frameSize.height==0) {
        self->frameSize=cv::Size(mat.cols, mat.rows);
        if (VIDEO_SCALE_FACTOR != 1.0) {
            realFrameSize=cv::Size(frameSize.width*(1/VIDEO_SCALE_FACTOR), frameSize.height*(1/VIDEO_SCALE_FACTOR));
        }
        else {
            realFrameSize=frameSize;
        }
    }
    if (frameCount==0) {
        startingMat=mat.clone();
        dispatch_group_async(goodPointsGroup, queue, ^{
            long long m1 = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
            cv::buildOpticalFlowPyramid(self->startingMat, self->startingPyramid,cv::Size(21,21), 3);
            //self->startPoints=[self goodFeaturesToTrack:self->startingMat];
            self->originalStartingPoints=[self goodFeaturesToTrack:self->startingMat];

            // self->startPoints=[self adjustPointsToScale:self->originalStartingPoints];
            self->startPoints=adjustPoints(self->originalStartingPoints, VIDEO_SCALE_FACTOR);  //adjust the points based on video scale.
            self->startingMat.release();
            self->startingMat=NULL;
            [self->startingPoints setPoints:self->startPoints];

            long long m2 = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
            //std::cout << "Good features to track:"  << self->startPoints.size() <<"\n";
            printf("Time to build startingPyramid and get starting features: %llu ms GoodOrigFeatures:%lu \n", m2-m1 , self->startPoints.size());
        });
    }
    else {
        std::vector<cv::Mat> cc;
        long long m1 = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
        cv::buildOpticalFlowPyramid(mat, cc,cv::Size(21,21), 3);
        PyramidHold p=PyramidHold(frameCount, cc);
        @synchronized(self) {
           // std::cout <<"Pyramids queue size:" << pyramids.size() << "\n";
            self->pyramids.push_back(p);
        }
      // dispatch_group_async(opticalFlowGroup, queue, ^{
            dispatch_group_wait(self->goodPointsGroup, DISPATCH_TIME_FOREVER);
            long long mm1 = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
            
            PyramidHold pp;
            @synchronized(self) {
                if (self->pyramids.size() >0) {
                    pp=self->pyramids.back();
                    self->pyramids.pop_back();
                    //NSLog(@"Just popeed a pyramid");
                }
            }
            std::vector<cv::Point2f> pts(MAX_CORNERS);
            std::vector<unsigned char> status;
            std::vector<float> errors;
            
            cv::calcOpticalFlowPyrLK(self->startingPyramid, pp.pyramid, self->originalStartingPoints, pts, status, errors);
            pp.pyramid.clear();
            pp.pyramid.shrink_to_fit();
            
            StatusWrapper *s=[[StatusWrapper alloc] init];
            [s setFstatus:status];
            Points *p1=[[Points alloc] init];
            pts=adjustPoints(pts, VIDEO_SCALE_FACTOR);
            [p1 setPoints:pts];
            //printf("Calc opflow for idx:%i total points: %i\n", pp.indx, [p1 totalPoints]);
            FrameFeature * f=[[FrameFeature alloc] initWithFeatureData:p1 andStartingPoints:self->startingPoints andPointStatus:s andFrameIndex: &pp.indx];
            //f.distances= [FrameFeature calcDistanceForPoints:f.points a:f.startingPoints];
            [self.frameFeatures addObject:f];
            long long mm2 = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
            if (self->frameCount % 50 ==0 ){
                printf("Time to calcOpticalFlow: %llu ms\n", mm2-mm1);
            }
       // });

        long long m2 = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
        if (frameCount % 50 == 0 ) {
            printf("Build current opt pyramid: %llu ms\n", m2-m1);
        }
    }
    frameCount++;
}

static std::vector<cv::Point2f> adjustPoints(std::vector<cv::Point2f> points, float scaleFactor) {
    std::vector<cv::Point2f> newPoints;
    for (int i=0; i < points.size();i++) {
        cv::Point2f p=points[i];
        float nx= p.x * (1/scaleFactor);
        float ny= p.y * (1/scaleFactor);
        // std::cout << "x was:" << p.x << " now: " << nx << " y was:" << p.y << " now:" << ny << "\n";
        cv::Point2f np=cv::Point2f(nx,ny);
        newPoints.push_back(np);
    }
    return newPoints;
}
- (std::vector<cv::Point2f>) goodFeaturesToTrack:(cv::Mat) grayMat {
    std::vector<cv::Point2f> points;
    cv::goodFeaturesToTrack(grayMat, points, MAX_CORNERS, 0.01, 10);
    cv::cornerSubPix(grayMat, points, cv::Size(5, 5), cv::Size(-1, -1), cv::TermCriteria(CV_TERMCRIT_EPS + CV_TERMCRIT_ITER,100,0.001) );
    return points;
}

- (void) postProcess {
    dispatch_group_wait(opticalFlowGroup, DISPATCH_TIME_FOREVER);
    //printf("Starting post process!!\n");
    if (self.postProcessDone==true) {
        printf("Post process already done!");
        return;
    }
    if ([self.frameFeatures count]==0) {
        printf("No frames have been processed!");
        return;
    }
    long long m1 = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);

    NSMutableArray *sortedArray = [NSMutableArray arrayWithArray: [self.frameFeatures sortedArrayUsingSelector:@selector(compare:)]];
    self.frameFeatures=sortedArray;
    [self calculateDistances];
    
    //wait for queue to finish->
    self->stdMask=[self stdDeviationMask];   //might be able to do this in real time as well.  When deviation hits a threshold it's flagged.
    self->offsetMask=[FixedStabilizer calcOffscreenMask:self.frameFeatures];  //this could be done in real time..
    self->reducedPoints=[self getReducedPoints];
    self.postProcessDone=true;
    [self calcTransforms];
    long long m2 = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
    
    printf("Post processed in %llims. Total Frames %lu. Skipped Frame Pct: %.02f \n", (m2-m1), self->reducedPoints.size(), [self skippedFramesPct]);
}

- (void) calculateDistances {
    int framesFlaggedFalse=0;
    for (int i=0; i < [self.frameFeatures count]; i++) {
        NSMutableArray *dist;
        FrameFeature *f=self.frameFeatures[i];
        if (i==0) {
            dist=[FrameFeature calcDistanceForPoints:f.points a:f.startingPoints];
        }
        else {
            FrameFeature *prevFeature=self.frameFeatures[i-1];
            dist=[FrameFeature calcDistanceForPoints:f.points a:prevFeature.points];
        }
        f.distances=dist;
        double m=[f getDistanceMean];
        if (framesFlaggedFalse > 2 || m > 20) {
            //three frames over 20 have been flagged. Shut down any future frames.
            f.validFrame=false;
            skippedFrames++;
            framesFlaggedFalse++;
        }
        else {
            f.validFrame=true;
        }
    }
    NSLog(@"Frames tagged false: %i of %lu",framesFlaggedFalse,(unsigned long)[self.frameFeatures count]);
}

+ (NSArray *) calcOffscreenMask:(NSArray *) frameFeatures {
    //long long m1 = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
    if(![frameFeatures count]) return nil;
    FrameFeature *f=frameFeatures[0];
    int size=(int)f.points.point2.size();
    NSMutableArray *offscreenMask = [NSMutableArray arrayWithCapacity:size];
    for (int i=0; i < size; i++) {
        [offscreenMask addObject:[NSNumber numberWithInt:1]];
    }
    
    //for every feature.
    for (int i=0; i < [frameFeatures count]; i++) {
        FrameFeature *ff=frameFeatures[i];
        bool isOffset=false;
        std::vector<cv::Point2f> points = ff.points.point2;
        for (int z=0; z < points.size(); z++) {
            if (points[z].x <= 0 || points[z].y <=0 ) {
                isOffset=true;
                [offscreenMask replaceObjectAtIndex:z withObject:[NSNumber numberWithInt:0]];
                // NSLog(@"Any offsets? %f %f index %i:%i", points[z].x, points[z].y, i,z);
                //break;
            }
        }
    }
    //long long m2 = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
    // NSLog(@"Time for offset: %i ms", m2-m1);
    // NSLog(@"Off screern %i", [offscreenMask count]);
    return offscreenMask;
}
- (void) calcTransforms {
    if (self.postProcessDone != true) {
        NSLog(@"Can't exec getTransforms without postprocess");
        return;
    }
    long long m1 = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
    for (int z=0; z < [self.frameFeatures count]; z++) {
        FrameFeature *f=self.frameFeatures[z];
        if (f.validFrame==false) {
            cv::Mat m;
            transforms.push_back(m);
            NSLog(@"Lets skip %i",z);
            continue;
        }
        std::vector< std::vector <cv::Point2f>> matchingPoints = [self getReducedPointsForFeature:f];   //umm....
        //NSLog(@"m1: %i m2:%i", matchingPoints[0].size(), matchingPoints[1].size());
        std::vector <cv::Point2f> mmm=matchingPoints[0];
        std::vector <cv::Point2f> mmm2=matchingPoints[1];
        
        if (matchingPoints[0].size()==0 || matchingPoints[1].size()==0) {
            NSLog(@"Cannot find any matching points skipping");
            cv::Mat m;
            transforms.push_back(m);
            skippedFrames++;
            f.validFrame=false;
            continue;
        }
        
        //std::cout << mmm[0] << " -> " << mmm2[0] << "\n";
        
        cv::Mat mask;
        cv::Mat rigid=cv::estimateRigidTransform(matchingPoints[0], matchingPoints[1], false);
        
        if (rigid.cols==0) {
            NSLog(@"Frame could not calculate rigid transform.  Skipping: %i",z);
            cv::Mat m;
            transforms.push_back(m);
            skippedFrames++;
            f.validFrame=false;
            continue;
        }
        cv::Mat homo=cv::findHomography(matchingPoints[0], matchingPoints[1],  cv::RANSAC,5,mask);
        cv::Mat homo2;
        cv::Mat rigid2;
        homo.convertTo(homo2, CV_32F);
        rigid.convertTo(rigid2, CV_32F);
        // homo.reshape(2,0);
        float trimmed=trim.estimateOptimalTrimRatio(homo2, self->realFrameSize);
        // std::cout << homo2 << " and frame size " << self->frameSize << "\n";
        
        cv::Mat C = (cv::Mat_<float>(1,3) << 0, 0,  1);
        rigid2.push_back(C);
        //std::cout << rigid << "\n";
        //std::cout << homo2 << "\n";
        float trimmed2=trim.estimateOptimalTrimRatio(rigid2, self->realFrameSize);
        if (trimmed > 0.1) {
            NSLog(@"Too much trim, skip this frame. %i t: %f",z,trimmed);
            cv::Mat m;
            transforms.push_back(m);
            f.validFrame=false;
            continue;
        }
        //NSLog(@"Trim %f & trim2: %f",trim,trim2);
        //        cv::Mat B_new(3,3,CV_32F);
        //        B_new.row(0) = rigid2.row(0);
        //        B_new.row(1) = rigid2.row(1);
        //        B_new.row(2) = cv::Mat::ones(1,3,CV_32F);
        transforms.push_back(rigid);
        //if (trimmed > maxTrim) maxTrim=trimmed;
        if (trimmed2 > maxTrim) maxTrim=trimmed2;
        //maxTrim=0.05;
        
        
    }
    long long m2 = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
#if Benchmarks
    NSLog(@"Time to post process %llu ms", m2-m1);
#endif
}

- (std::vector< std::vector <cv::Point2f>>) getReducedPointsForFeature:(FrameFeature *) f {
    if (f.reducedPoints.size()  > 0) {
        return f.reducedPoints;
    }
    NSArray *reduceMask=[FixedStabilizer reduceMask:f andStdMask:stdMask andOffsetMask:offsetMask];
    std::vector< std::vector <cv::Point2f>> reduceArr;
    std::vector<cv::Point2f>  reducedPointsF;
    std::vector<cv::Point2f>  reducedStartingPoints;
    std::vector<cv::Point2f>  points=f.points.point2;
    std::vector<cv::Point2f>  startingPointsF=f.startingPoints.point2;
    for (int i=0; i < [reduceMask count]; i++ ) {
        NSNumber *r = reduceMask[i];
        if (r.intValue==1) {
            reducedPointsF.push_back(points[i]);
            reducedStartingPoints.push_back(startingPointsF[i]);
        }
    }
    
    reduceArr.push_back(reducedStartingPoints);
    reduceArr.push_back(reducedPointsF);
    //NSLog(@"Points reduced is %i Reduce mask size:%i", reducedPointsF.size(), [reduceMask count]);
    [f setReductedPoints:reduceArr];
    return reduceArr;
}
-  (std::vector< std::vector <cv::Point2f>>) getReducedPoints {
    std::vector< std::vector <cv::Point2f>> reduceArrA;
    for (int z=0; z < [self.frameFeatures count]; z++) {
        FrameFeature *f=self.frameFeatures[z];
        std::vector< std::vector <cv::Point2f>> matchingPoints = [self getReducedPointsForFeature:f];
        reduceArrA.push_back(matchingPoints[1]);
    }
    return reduceArrA;
}

+ (NSArray *) reduceMask:(FrameFeature *) f andStdMask:(NSArray *) stdMask andOffsetMask:(NSArray *) offsetMask {
    NSMutableArray *statusArray=[f.pointStatus statusArray];
    int reduced=0;
    for (int i=0; i < [statusArray count];i++) {
        NSNumber *n=statusArray[i];
        if (n.intValue > 0) {
            if (  ((NSNumber *)stdMask[i]).intValue == 0) {
                reduced++;
                [statusArray replaceObjectAtIndex:i withObject:[NSNumber numberWithInt:0]];
            }
            if (  ((NSNumber *)offsetMask[i]).intValue == 0) {
                reduced++;
                [statusArray replaceObjectAtIndex:i withObject:[NSNumber numberWithInt:0]];
            }
        }
    }
    std::vector<cv::Point2f> ppp = f.points.point2;
    return statusArray;
}


- (NSArray *) stdDeviationMask {
    //NSLog(@"Buliding std mask");
    if (self.stdDeviations == NULL) {
        [self calcStdDeviation];
    }
    double precision=0.3;
    for (int i=0; i < 30; i++) {
        precision = 0.3 * (2*i);
        if (precision <=0 ) precision=0.3;
        int stdCounter=0;
        for (int z=0; z < [self.stdDeviations count]; z++) {
            NSNumber  *n1 =self.stdDeviations[z];
            if (n1.doubleValue < precision) {
                stdCounter++;
            }
        }
        if (stdCounter > ([self.stdDeviations count] * 0.25)) {
            break;
        }
    }
    int matches=0;
    NSMutableArray *mask=[NSMutableArray arrayWithCapacity:[self.stdDeviations count]];
    for (int z=0; z < [self.stdDeviations count]; z++) {
        NSNumber  *n1 =self.stdDeviations[z];
        if (n1.doubleValue < precision) {
            matches++;
            [mask addObject:[NSNumber numberWithInt:1]];
        }
        else {
            [mask addObject:[NSNumber numberWithInt:0]];
        }
    }
    NSLog(@"Std precision %f with matches %i", precision,matches);
    //    NSLog(@"Maks %@", mask);
    return mask;
}

- (void) calcStdDeviation {
    long long m1 = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
    self.stdDeviations=[FixedStabilizer calcStdDeviation:self.frameFeatures];
    long long m2 = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
#if Benchmarks
    NSLog(@"Time for standard deviation: %lld ms", m2-m1);
#endif
}

+ (NSMutableArray *) calcStdDeviation:(NSArray *) frameFeatures {
    if(![frameFeatures count]) return nil;
    FrameFeature *f=frameFeatures[0];
    int size= int(f.points.point2.size());
    NSMutableArray *stdDeviationArray = [NSMutableArray arrayWithCapacity:size];
    for (int i=0; i < size; i++) {
        NSArray *distanceRow=[FixedStabilizer getDistanceRow:frameFeatures andRow:i];
        NSNumber *std=[FixedStabilizer standardDeviationOf:distanceRow];
        [stdDeviationArray addObject:std];
    }
    
    return stdDeviationArray;
}
+ (NSArray *) getDistanceRow:(NSArray *) frameFeatures andRow:(int) row {
    NSMutableArray *myArray = [NSMutableArray arrayWithCapacity:[frameFeatures count]];
    for (id object in frameFeatures) {
        FrameFeature *f=object;
        if (f.validFrame==true) {
            [myArray addObject: f.distances[row]];
        }
        //        else {
        //            NSLog(@"LOOK I SKIPPED %i, %i", f.validFrame, f.frameIndex);
        //        }
    }
    return myArray;
}

+ (NSNumber *)standardDeviationOf:(NSArray *)array {
    if(![array count]) return nil;
    double mean = [[FixedStabilizer meanOf:array] doubleValue];
    double sumOfSquaredDifferences = 0.0;
    for(NSNumber *number in array) {
        double valueOfNumber = [number doubleValue];
        double difference = valueOfNumber - mean;
        sumOfSquaredDifferences += difference * difference;
    }
    return [NSNumber numberWithDouble:sqrt(sumOfSquaredDifferences / [array count])];
}
+ (NSNumber *)meanOf:(NSArray *)array {
    double runningTotal = 0.0;
    for(NSNumber *number in array) {
        runningTotal += [number doubleValue];
    }
    return [NSNumber numberWithDouble:(runningTotal / [array count])];
}


- (NSArray *) applyVideoTransform:(NSURL *) sourceUrl  andMovie:(CEMovieMaker *) movie andShowPoints:(bool) showPoints {
    long long m1 = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
    int fCount=0;
    if (movie) {
        [movie startWriter];
    }
    NSMutableArray *transformedImages=[[NSMutableArray alloc] init];
    if (self.postProcessDone==false) {
        NSLog(@"Need to post processes!");
        return transformedImages;
    }
    //INTER_LINEAR OK? FAST
    //INTER_LANCZOS4  OK SLOW 20S
    //INTER_NEAREST HORRIBLE  9.6S
    //INTER_AREA  OK?  9.3ms
    //INTER_CUBIC OK 11.8MS
    
    int flags =  cv::INTER_LINEAR |  cv::WARP_INVERSE_MAP;
    //int flags=cv::WARP_INVERSE_MAP;
    AVAsset *asset = [AVURLAsset URLAssetWithURL:sourceUrl options:nil];
    AVAssetReader *assetReader = [[AVAssetReader alloc] initWithAsset:asset error:NULL];
    AVAssetTrack *videoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    NSDictionary *outputSettings = @{(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)};
    AVAssetReaderTrackOutput *assetReaderOutput=[[AVAssetReaderTrackOutput alloc] initWithTrack:videoTrack outputSettings:outputSettings];
    assetReaderOutput.alwaysCopiesSampleData=false;
    [assetReader addOutput:assetReaderOutput];
    [assetReader startReading];
    CMSampleBufferRef sample=[assetReaderOutput copyNextSampleBuffer];
    while (sample != nil) {
        if (fCount!=0) {
            FrameFeature *f=self.frameFeatures[fCount-1];
            if (f.validFrame==false) {
                NSLog(@"Skip this bad boy %i", fCount);
                CFRelease(sample);
                sample=[assetReaderOutput copyNextSampleBuffer];
                fCount++;
                continue;
            }
        }
        CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sample);
        CVPixelBufferLockBaseAddress( pixelBuffer, 0 );
        int bufferWidth = (int)CVPixelBufferGetWidth(pixelBuffer);
        int bufferHeight = (int)CVPixelBufferGetHeight(pixelBuffer);
        unsigned char *pixel = (unsigned char *)CVPixelBufferGetBaseAddress(pixelBuffer);
        cv::Mat image = cv::Mat(bufferHeight,bufferWidth,CV_8UC4,pixel);
        
        if (showPoints) {
            image=[self drawFeat:image andIndex:(fCount-1)];
        }
        @autoreleasepool {
            
            if (fCount!=0) {
                cv::Mat outputMat;
                //on a 4k frame this function costs 100ms on iphone 7
                cv::warpAffine(image, outputMat, self->transforms[fCount-1], self->realFrameSize,flags);
                

                image=outputMat;
            }
            
            UIImage *outputImage;
            cv::Mat trimmedMat=trimFrameCopy(maxTrim, image);
            cv::Mat resizeMat;
            cv::resize(trimmedMat,resizeMat,self->realFrameSize);
            outputImage=UIImageFromCVMat(resizeMat);
            //trim,resize,output costs about 50ms on a 4k frame with iphone 7
            
            if (movie) {
                [movie appendImage:outputImage];
            }
            //            if (fCount < 100) {
            //                [transformedImages addObject:outputImage];
            //            }
            //          resizeMat.release();
            //           trimmedMat.release();
        }
        if (fCount % 50==0 || fCount > 270) {
            NSLog(@"Processing and encoding frame %i",fCount);
        }
        CVPixelBufferUnlockBaseAddress( pixelBuffer, 0 );
        CFRelease(sample);
        sample=[assetReaderOutput copyNextSampleBuffer];
        fCount++;
    }
    
    long long m2 = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
    NSLog(@"Time to encode video %llu ms", (m2-m1));
    return transformedImages;
}



- (cv::Mat) drawFeat:(cv::Mat) mat andIndex:(int) i {
    if (i==-1) {
        FrameFeature *f=self.frameFeatures[0];
        Points *p=f.startingPoints;
        std::vector<cv::Point2f> pp=p.point2;
        CvScalar yellow = CV_RGB(255,255,0);
        for (int z=0; z < pp.size(); z++) {
            cv::circle(mat, pp[z], 3, yellow);
        }
    }
    else {
        if (i >= reducedPoints.size()) {
            NSLog(@"oh i think we drew all there is..");
            return mat;
        }
        std::vector<cv::Point2f> reducedP = reducedPoints[i];
        CvScalar yellow = CV_RGB(255,255,0);
        for (int i=0; i < reducedP.size(); i++) {
            // std::cout << reducedP[i] << "\n";
            cv::circle(mat, reducedP[i], 3, yellow);
        }
    }
    return mat;
}


static cv::Mat trimFrameCopy(float trimRatio, cv::Mat frame) {
    int dx = static_cast<int>(floor(trimRatio * frame.cols));
    int dy = static_cast<int>(floor(trimRatio * frame.rows));
    cv::Mat frameCopy;
    frame(cv::Rect(dx, dy, frame.cols - 2*dx, frame.rows - 2*dy)).copyTo(frameCopy);
    return frameCopy;
}


static UIImage *UIImageFromCVMat(cv::Mat &cvMat) {
    NSData *data = [NSData dataWithBytes:cvMat.data length:cvMat.elemSize()*cvMat.total()];
    
    CGColorSpaceRef colorSpace;
    CGBitmapInfo bitmapInfo;
    
    if (cvMat.elemSize() == 1) {
        colorSpace = CGColorSpaceCreateDeviceGray();
        bitmapInfo = kCGImageAlphaNone | kCGBitmapByteOrderDefault;
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
        bitmapInfo = kCGBitmapByteOrder32Little | (
                                                   cvMat.elemSize() == 3? kCGImageAlphaNone : kCGImageAlphaNoneSkipFirst
                                                   );
    }
    
    
    //let context = CGBitmapContextCreate(baseAddress,width,height,8,bytesPerRow, colorSpace, CGBitmapInfo.ByteOrder32Little.rawValue | CGImageAlphaInfo.PremultipliedFirst.rawValue)
    
    
    bitmapInfo=  kCGBitmapByteOrder32Little | kCGImageAlphaFirst;
    
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    // Creating CGImage from cv::Mat
    CGImageRef imageRef = CGImageCreate(
                                        cvMat.cols,                 //width
                                        cvMat.rows,                 //height
                                        8,                          //bits per component
                                        8 * cvMat.elemSize(),       //bits per pixel
                                        cvMat.step[0],              //bytesPerRow
                                        colorSpace,                 //colorspace
                                        bitmapInfo,                 // bitmap info
                                        provider,                   //CGDataProviderRef
                                        NULL,                       //decode
                                        false,                      //should interpolate
                                        kCGRenderingIntentDefault   //intent
                                        );
    
    // Getting UIImage from CGImage
    UIImage *finalImage = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return finalImage;
}


static void UIImageToMat(UIImage *image, cv::Mat &mat) {
    
    // Create a pixel buffer.
    NSInteger width = CGImageGetWidth(image.CGImage);
    NSInteger height = CGImageGetHeight(image.CGImage);
    CGImageRef imageRef = image.CGImage;
    cv::Mat mat8uc4 = cv::Mat((int)height, (int)width, CV_8UC4);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef contextRef = CGBitmapContextCreate(mat8uc4.data, mat8uc4.cols, mat8uc4.rows, 8, mat8uc4.step, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrderDefault);
    CGContextDrawImage(contextRef, CGRectMake(0, 0, width, height), imageRef);
    CGContextRelease(contextRef);
    CGColorSpaceRelease(colorSpace);
    // Draw all pixels to the buffer.
    cv::Mat mat8uc3 = cv::Mat((int)width, (int)height, CV_8UC3);
    cv::cvtColor(mat8uc4, mat8uc3, CV_RGBA2BGR);
    mat = mat8uc3;
}

/// Converts a Mat to UIImage.
static UIImage *MatToUIImage(cv::Mat &mat) {
    // Create a pixel buffer.
    assert(mat.elemSize() == 1 || mat.elemSize() == 3);
    cv::Mat matrgb;
    if (mat.elemSize() == 1) {
        cv::cvtColor(mat, matrgb, CV_GRAY2RGB);
    } else if (mat.elemSize() == 3) {
        cv::cvtColor(mat, matrgb, CV_BGR2RGB);
    }
    
    // Change a image format.
    NSData *data = [NSData dataWithBytes:matrgb.data length:(matrgb.elemSize() * matrgb.total())];
    CGColorSpaceRef colorSpace;
    if (matrgb.elemSize() == 1) {
        colorSpace = CGColorSpaceCreateDeviceGray();
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    CGImageRef imageRef = CGImageCreate(matrgb.cols, matrgb.rows, 8, 8 * matrgb.elemSize(), matrgb.step.p[0], colorSpace, kCGImageAlphaNone|kCGBitmapByteOrderDefault, provider, NULL, false, kCGRenderingIntentDefault);
    UIImage *image = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return image;
}

- (NSArray *) drawFeatures:(NSArray *) images {
    NSMutableArray *drawImages=[NSMutableArray arrayWithCapacity:[images count]];
    for (int i=0; i <= [self.frameFeatures count];i++) {
        if (i==0) {
            FrameFeature *f=self.frameFeatures[0];
            Points *p=f.startingPoints;
            cv::Mat imageMat;
            UIImageToMat(images[0], imageMat);
            std::vector<cv::Point2f> pp=p.point2;
            CvScalar yellow = CV_RGB(255,255,0);
            for (int z=0; z < pp.size(); z++) {
                cv::circle(imageMat, pp[z], 3, yellow);
            }
            UIImage *z=MatToUIImage(imageMat);
            [drawImages addObject:z];
        }
        else {
            
            [drawImages addObject:[self drawFeature:i-1 onImage:images[i]]];
        }
    }
    return drawImages;
}
- (UIImage *) drawFeature:(int) frame onImage:(UIImage *) image {
    if (_postProcessDone==false) {
        NSLog(@"Cannot draw features til postprocessing is done");
        return nil;
    }
    cv::Mat imageMat;
    UIImageToMat(image, imageMat);
    std::vector<cv::Point2f> reducedP;
    if (frame == -1) {
        
    }
    else {
        
    }
    reducedP = self->reducedPoints[frame];
    CvScalar yellow = CV_RGB(255,255,0);
    
    if (frame % 10 ==0) {
        NSLog(@"i %i there are %lu features", frame,reducedP.size());
    }
    for (int i=0; i < reducedP.size(); i++) {
        // std::cout << reducedP[i] << "\n";
        cv::circle(imageMat, reducedP[i], 3, yellow);
    }
    UIImage *i=MatToUIImage(imageMat);
    return i;
}






@end
