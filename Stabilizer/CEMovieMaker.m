//
//  CEMovieMaker.m
//  CEMovieMaker
//
//  Created by Cameron Ehrlich on 9/17/14.
//  Copyright (c) 2014 Cameron Ehrlich. All rights reserved.
//

#import "CEMovieMaker.h"

typedef UIImage*(^CEMovieMakerUIImageExtractor)(NSObject* inputObject);

@implementation CEMovieMaker {
    int frameCount;
}


- (instancetype)initWithSettings:(NSDictionary *)videoSettings andSaveURL:(NSURL *) saveURL andTransform:(CGAffineTransform) transform {
    self = [self init];
    frameCount=0;
    if (self) {
        NSError *error;
        
        _fileURL = saveURL;
        _assetWriter = [[AVAssetWriter alloc] initWithURL:self.fileURL
                                                 fileType:AVFileTypeQuickTimeMovie error:&error];
        if (error) {
            NSLog(@"Error: %@", error.debugDescription);
        }
        NSParameterAssert(self.assetWriter);
        
        
        //        NSMutableArray *metadata = [NSMutableArray array];
        //        AVMutableMetadataItem *metaItem = [AVMutableMetadataItem metadataItem];
        //        metaItem.key = AVMetadataCommonKeyPublisher;
        //        metaItem.keySpace = AVMetadataKeySpaceCommon;
        //        metaItem.value = @"gylph";
        //        [metadata addObject:metaItem];
        //
        
        //NSLog(@"^ I bet i go here...");
        
        _videoSettings = videoSettings;
        _writerInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                                          outputSettings:videoSettings];
        // _writerInput.metadata=metadata;
        
        
        _writerInput.expectsMediaDataInRealTime=YES;
        _writerInput.transform=transform;
        
        
        
        NSParameterAssert(self.writerInput);
        NSParameterAssert([self.assetWriter canAddInput:self.writerInput]);
        
        [self.assetWriter addInput:self.writerInput];
        NSDictionary *bufferAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                          [NSNumber numberWithInt:kCVPixelFormatType_32ARGB], kCVPixelBufferPixelFormatTypeKey, nil];
        
        //
        //        NSDictionary *bufferAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
        //                                    [NSNumber numberWithInt:kCVPixelFormatType_32BGRA], kCVPixelBufferPixelFormatTypeKey, nil];
        //
        //
        
        _bufferAdapter = [[AVAssetWriterInputPixelBufferAdaptor alloc] initWithAssetWriterInput:self.writerInput sourcePixelBufferAttributes:bufferAttributes];
        NSNumber *foo = [[videoSettings objectForKey:AVVideoCompressionPropertiesKey] objectForKey:AVVideoExpectedSourceFrameRateKey] ;
        int frameRate=24;
        if (foo != nil) {
            frameRate= (int)[foo integerValue];
        }
        NSLog(@"Setting frame rate %i",frameRate);
        _frameTime = CMTimeMake(1, frameRate);
    }
    return self;
}
- (instancetype)initWithSettings:(NSDictionary *)videoSettings andSaveURL:(NSURL *) saveURL {
    return [self initWithSettings:videoSettings andSaveURL:saveURL andTransform:CGAffineTransformIdentity];
}
- (void) startWriter {
    [self.assetWriter startWriting];
    [self.assetWriter startSessionAtSourceTime:kCMTimeZero];
}

- (void) appendImage:(UIImage *) image {
    while ([self.writerInput isReadyForMoreMediaData] == false ) {
        //  NSLog(@"Rut oh not rdy for data.");
        NSDate *d =[NSDate dateWithTimeIntervalSinceNow:0.01];
        [[NSRunLoop currentRunLoop] runUntilDate:d];
    }
    if ([self.writerInput isReadyForMoreMediaData]) {
        int i=frameCount;
        CVPixelBufferRef sampleBuffer = [self newPixelBufferFromCGImage:[image CGImage]];  //at worst 2ms
        if (sampleBuffer) {
            if (i == 0) {
                [self.bufferAdapter appendPixelBuffer:sampleBuffer withPresentationTime:kCMTimeZero];
            }else{
                CMTime lastTime = CMTimeMake(i-1, self.frameTime.timescale);
                CMTime presentTime = CMTimeAdd(lastTime, self.frameTime);
                [self.bufferAdapter appendPixelBuffer:sampleBuffer withPresentationTime:presentTime];
            }
            CFRelease(sampleBuffer);
        }
        frameCount++;
    }
    else {
        NSLog(@"Not read for more data..");
    }
}
- (void) finishWriter:(CEMovieMakerCompletion)completion {
    [self.writerInput markAsFinished];
    [self.assetWriter finishWritingWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            self.completionBlock(self.fileURL);
        });
    }];
    
    CVPixelBufferPoolRelease(self.bufferAdapter.pixelBufferPool);
}


- (void) finish:(void (^)(void))handler {
    [self.writerInput markAsFinished];
    [self.assetWriter finishWritingWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (handler) {
                handler();
            }
        });
    }];
    
    CVPixelBufferPoolRelease(self.bufferAdapter.pixelBufferPool);
    
}

- (void) cancel:(void (^)(void))handler  {
    [self.writerInput markAsFinished];
    [self.assetWriter cancelWriting];
    if (handler) {
        handler();
    }
}


- (CVPixelBufferRef)newPixelBufferFromCGImage:(CGImageRef)image
{
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey,
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey,
                             nil];
    
    CVPixelBufferRef pxbuffer = NULL;
    
    CGFloat frameWidth = [[self.videoSettings objectForKey:AVVideoWidthKey] floatValue];
    CGFloat frameHeight = [[self.videoSettings objectForKey:AVVideoHeightKey] floatValue];
    
    
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault,
                                          frameWidth,
                                          frameHeight,
                                          kCVPixelFormatType_32ARGB,
                                          (__bridge CFDictionaryRef) options,
                                          &pxbuffer);
    //
    //    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault,
    //                                          frameWidth,
    //                                          frameHeight,
    //                                          kCVPixelFormatType_32BGRA,
    //                                          (__bridge CFDictionaryRef) options,
    //                                          &pxbuffer);
    //
    
    NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);
    
    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    NSParameterAssert(pxdata != NULL);
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    
    
    //    CGContextRef context = CGBitmapContextCreate(pxdata, frameWidth,
    //                                                 frameHeight, 8, 4*frameWidth, rgbColorSpace,
    //                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    //
    // CGContextSetRGBFillColor(context, 0,0,1.0,0.5);
    
    CGContextRef context = CGBitmapContextCreate(pxdata,
                                                 frameWidth,
                                                 frameHeight,
                                                 8,
                                                 4 * frameWidth,
                                                 rgbColorSpace,
                                                 (CGBitmapInfo)kCGImageAlphaNoneSkipFirst);
    NSParameterAssert(context);
    CGContextConcatCTM(context, CGAffineTransformIdentity);
    CGContextDrawImage(context, CGRectMake(0,
                                           0,
                                           CGImageGetWidth(image),
                                           CGImageGetHeight(image)),
                       image);
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    
    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
    
    return pxbuffer;
}

+ (NSDictionary *)videoSettingsWithCodec:(NSString *)codec withWidth:(CGFloat)width andHeight:(CGFloat)height
{
    
    if ((int)width % 16 != 0 ) {
        NSLog(@"Warning: video settings width must be divisible by 16.");
    }
    
    //AVVideoCodecHEVC encoding speed probably really slow.
    
    
    NSDictionary *videoSettings = @{AVVideoCodecKey : AVVideoCodecTypeH264,
                                    AVVideoWidthKey : [NSNumber numberWithInt:(int)width],
                                    AVVideoHeightKey : [NSNumber numberWithInt:(int)height]};
    
    return videoSettings;
}

@end

