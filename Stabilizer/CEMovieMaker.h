//
//  CEMovieMaker.h
//  CEMovieMaker
//
//  Created by Cameron Ehrlich on 9/17/14.
//  Copyright (c) 2014 Cameron Ehrlich. All rights reserved.
//


#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>


typedef void(^CEMovieMakerCompletion)(NSURL *fileURL);

#if __has_feature(objc_generics) || __has_extension(objc_generics)
#define CE_GENERIC_URL <NSURL *>
#define CE_GENERIC_IMAGE <UIImage *>
#else
#define CE_GENERIC_URL
#define CE_GENERIC_IMAGE
#endif


@interface CEMovieMaker : NSObject

@property (nonatomic, strong) AVAssetWriter *assetWriter;
@property (nonatomic, strong) AVAssetWriterInput *writerInput;
@property (nonatomic, strong) AVAssetWriterInputPixelBufferAdaptor *bufferAdapter;
@property (nonatomic, strong) NSDictionary *videoSettings;
@property (nonatomic, assign) CMTime frameTime;
@property (nonatomic, strong) NSURL *fileURL;
@property (nonatomic, copy) CEMovieMakerCompletion completionBlock;

- (instancetype)initWithSettings:(NSDictionary *)videoSettings andSaveURL:(NSURL *) saveURL;
- (instancetype)initWithSettings:(NSDictionary *)videoSettings andSaveURL:(NSURL *) saveURL andTransform:(CGAffineTransform) transform;


- (void) appendImage:(UIImage *) image;
- (void) startWriter;
- (void) finishWriter:(CEMovieMakerCompletion)completion;
- (void)finish:(void (^)(void))handler;
- (void) cancel:(void (^)(void))handler;
+ (NSDictionary *)videoSettingsWithCodec:(NSString *)codec withWidth:(CGFloat)width andHeight:(CGFloat)height;


@end
