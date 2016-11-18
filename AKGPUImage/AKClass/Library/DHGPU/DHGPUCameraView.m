//
//  DHGPUView.m
//  DHOCChat
//
//  Created by AKing on 16/3/18.
//  Copyright © 2016年 AKing. All rights reserved.
//

#import "DHGPUCameraView.h"
#import "FCFileManager.h"
#import "AKVideoManager.h"
#import "DHTrackFaceProgress.h"

#import "DHFlagUtility.h"

@interface DHGPUCameraView ()<GPUImageVideoCameraDelegate,GPUImageMovieWriterDelegate,CAAnimationDelegate,DHTrackFaceProgressDelegate>
{
    GPUImageVideoCamera *videoCamera;
    GPUImageMovieWriter *movieWriter;
    CALayer *_focusLayer;
    CGPoint _mouthUpper;
}

@property (nonatomic, strong) DHUIElementItemManager          *uiElementItemManager;

@property (nonatomic, strong) DHTrackFaceProgress             *trackFaceProgress;

@end

@implementation DHGPUCameraView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        
        
        self.trackFaceProgress = [[DHTrackFaceProgress alloc] init];
        self.trackFaceProgress.delegate = self;
        
        videoCamera = [[GPUImageVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPreset1280x720 cameraPosition:AVCaptureDevicePositionFront];
        videoCamera.outputImageOrientation = UIInterfaceOrientationPortrait;
        videoCamera.horizontallyMirrorFrontFacingCamera = YES;
        videoCamera.runBenchmark = YES;
        [videoCamera addAudioInputsAndOutputs];
        [videoCamera setDelegate:self];
        videoCamera.frameRate = 30;
        
        //点击调整对焦和曝光
        UITapGestureRecognizer *singleFingerOne = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(cameraViewTapAction:)];
        [self addGestureRecognizer:singleFingerOne];
        
        UITapGestureRecognizer *doubleTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(rotateCamera)];
        [doubleTapGesture setNumberOfTapsRequired:2];
        [self addGestureRecognizer:doubleTapGesture];
        
        //这行很关键，意思是只有当没有检测到doubleTapGestureRecognizer 或者 检测doubleTapGestureRecognizer失败，singleTapGestureRecognizer才有效
        [singleFingerOne requireGestureRecognizerToFail:doubleTapGesture];
        
        [self setupConfig];
        [videoCamera startCameraCapture]; 
    }
    
    return self;
}

- (void)setupConfig
{
    [self dh_removeAllSubviews];
    [videoCamera removeAllTargets];
    
    
    GPUImageView *gView = [[GPUImageView alloc] initWithFrame:RECT((self.width - DHShowVideoWidth) / 2,
                                                                   (self.height - DHShowVideoHeight) / 2,
                                                                   DHShowVideoWidth, DHShowVideoHeight)];
    gView.tag = 2016091201;
//    gView.fillMode = kGPUImageFillModePreserveAspectRatioAndFill;
    [self addSubview:gView];
    
    
    //视频输出。。
    int videoWidth = (int)DHOutputVideoWidth;
    int videoHeight = (int)DHOutputVideoHeight;
    //http://stackoverflow.com/questions/29505631/crop-video-in-ios-see-weird-green-line-around-video
    while (videoWidth % 4 > 0) {
        videoWidth += 1;
    }
    while (videoHeight % 4 > 0) {
        videoHeight += 1;
    }
    NSMutableDictionary *videoSettings = [NSMutableDictionary dictionary];
    [videoSettings setObject:AVVideoCodecH264 forKey:AVVideoCodecKey];
    [videoSettings setObject:[NSNumber numberWithInt:videoWidth] forKey:AVVideoWidthKey];//尺寸
    [videoSettings setObject:[NSNumber numberWithInt:videoHeight] forKey:AVVideoHeightKey];
    
    NSMutableDictionary *audioSettings = [NSMutableDictionary dictionary];
    [audioSettings setObject:[NSNumber numberWithInt:kAudioFormatMPEG4AAC] forKey:AVFormatIDKey];
    [audioSettings setObject:[NSNumber numberWithInt:1] forKey:AVNumberOfChannelsKey];
    [audioSettings setObject:[NSNumber numberWithFloat:44100.0f] forKey:AVSampleRateKey];
    [audioSettings setObject:[NSNumber numberWithInt:64000] forKey:AVEncoderBitRateKey];
    
    NSString *documents = [FCFileManager pathForDocumentsDirectory];
    NSString *filePath = [documents stringByAppendingPathComponent:@"/natural_gpu.mp4"];
    [FCFileManager removeItemAtPath:filePath];
    unlink([filePath UTF8String]);
    NSURL *mURL = [NSURL fileURLWithPath:filePath];
    self.videoPath = filePath;
    
    movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:mURL
                                                           size:SIZE(videoWidth, videoHeight)//输出尺寸
                                                       fileType:AVFileTypeMPEG4
                                                 outputSettings:videoSettings];
    movieWriter.encodingLiveVideo = YES;
    
    //solve "Couldn't write a frame"
    movieWriter.assetWriter.movieFragmentInterval = kCMTimeInvalid;
    
    [movieWriter setHasAudioTrack:YES audioSettings:audioSettings];
    [movieWriter setDelegate:self];
    
    self.uiElementItemManager = [DHUIElementItemManager uiElementItemManagerWithInput:videoCamera
                                                                               output:movieWriter
                                                                           outputView:gView];
    
    
    
    WEAK_SELF(wself);
    //初始化焦点，防止上次手势对焦点结束记录到本次
    [wself focusAtPoint:CGPointMake(.5f, .5f)];
    //识别脸部焦点，为保证进光量，延时0.6秒执行
    CGPoint pointOfInterest = CGPointMake(.5f, .5f);
    if (!CGPointEqualToPoint(_mouthUpper, CGPointZero)) {
        pointOfInterest = _mouthUpper;
    }
    double delayInSeconds = 0.6 ;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [wself focusAtPoint:pointOfInterest];
    });

    self.viewCanvas = [[CanvasView alloc] initWithFrame:gView.frame];
    [self addSubview:self.viewCanvas];
    self.viewCanvas.backgroundColor = [UIColor clearColor];
}

//videoCamera start/stop
- (void)gpuViewDidAppear
{
    [self.trackFaceProgress setupFaceDetector];
    
    //重新配置，movieWriter要重新创建，不然有crash，，
    /**
     *  http://www.jianshu.com/p/bd204b34a85d
     https://www.google.com.hk/webhp?rlz=1C5CHFA_enUS654JP655&ie=UTF-8&rct=j#q=GPUImageMovieWriter+cannot+call+method+when+status+is+2&safe=strict&start=0
     */
    [self setupConfig];
    
    [videoCamera startCameraCapture];
}

- (void)gpuViewWillDisappear
{
    [self.trackFaceProgress pause];
    
    [videoCamera stopCameraCapture];
    UIView *gView = [self viewWithTag:2016091201];
    [gView removeFromSuperview];
    if (self.isRecording) {
        [self stopRecord];
    }else {
        [self.uiElementItemManager stopAnimation];
    }
}

- (void)rotateCamera
{
    [videoCamera rotateCamera];
}

//movieWriter start/stop
- (void)startRecord
{
    self.recording = YES;
    videoCamera.audioEncodingTarget = movieWriter;
    [movieWriter startRecording];
}

- (void)stopRecord
{
    self.recording = NO;
    [self.uiElementItemManager stopRecord];
    videoCamera.audioEncodingTarget = nil;
    [movieWriter finishRecording];
}

- (void)changeFilterItem:(DHMakeFilterItem *)fItem
{
    [self.uiElementItemManager changeFilterItem:fItem];
}

- (void)changeBeautifulFilterState
{
    [self.uiElementItemManager changeBeautifulFilterState];
}

- (BOOL)isAnimation
{
    return self.uiElementItemManager.isAnimating;
}

- (void)cameraViewTapAction:(UITapGestureRecognizer *)tgr
{
    if (tgr.state == UIGestureRecognizerStateRecognized) {
        CGPoint location = [tgr locationInView:self];
        [self setfocusImage];
        [self layerAnimationWithPoint:location];
        AVCaptureDevice *device = videoCamera.inputCamera;
        CGPoint pointOfInterest = CGPointMake(.5f, .5f);
        NSLog(@"taplocation x = %f y = %f", location.x, location.y);
        CGSize frameSize = [self frame].size;
        
        if ([videoCamera cameraPosition] == AVCaptureDevicePositionFront) {
            location.x = frameSize.width - location.x;
        }
        
        pointOfInterest = CGPointMake(location.y / frameSize.height, 1.f - (location.x / frameSize.width));
        
        
        NSError *error;
        if ([device lockForConfiguration:&error]) {
            //后置摄像头 对焦模式+曝光
            if ([videoCamera cameraPosition] == AVCaptureDevicePositionBack && [device isFocusPointOfInterestSupported] && [device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
                [device setFocusPointOfInterest:pointOfInterest];
                [device setFocusMode:AVCaptureFocusModeAutoFocus];
                if([device isExposurePointOfInterestSupported] && [device isExposureModeSupported:AVCaptureExposureModeAutoExpose])
                {
                    [device setExposurePointOfInterest:pointOfInterest];
                    [device setExposureMode:AVCaptureExposureModeAutoExpose];
                    //偏移量
                    [device setExposureTargetBias:0.1 completionHandler:^(CMTime syncTime) {}];
                }
            }
            //前置摄像头 仅曝光
            if([videoCamera cameraPosition] == AVCaptureDevicePositionFront && [device isExposurePointOfInterestSupported] && [device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure])
            {
                [device setExposurePointOfInterest:pointOfInterest];
                [device setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
            }
            
            [device unlockForConfiguration];
            
            
            NSLog(@"FOCUS OK");
        } else {
            NSLog(@"ERROR = %@", error);
        }
    }
    
}

- (void)setfocusImage{
    
    [_focusLayer removeFromSuperlayer];
    
    UIImage *focusImage = [UIImage imageNamed:@"fc_cam_focus"];
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, focusImage.size.width, focusImage.size.height)];
    imageView.image = focusImage;
    CALayer *layer = imageView.layer;
    [self.layer addSublayer:layer];
    _focusLayer = layer;
}

- (void)layerAnimationWithPoint:(CGPoint)point {
    if (_focusLayer) {
        self.userInteractionEnabled = NO;
        CALayer *focusLayer = _focusLayer;
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        [focusLayer setPosition:point];
        focusLayer.transform = CATransform3DMakeScale(2.0f,2.0f,1.0f);
        [CATransaction commit];
        CABasicAnimation *animation = [ CABasicAnimation animationWithKeyPath: @"transform" ];
        animation.toValue = [ NSValue valueWithCATransform3D: CATransform3DMakeScale(1.0f,1.0f,1.0f)];
        animation.delegate = self;
        animation.duration = 0.3f;
        animation.repeatCount = 1;
        animation.removedOnCompletion = NO;
        animation.fillMode = kCAFillModeForwards;
        [focusLayer addAnimation: animation forKey:@"animation"];
        // 0.5秒钟延时
        [self performSelector:@selector(focusLayerNormal) withObject:self afterDelay:0.5f];
    }
}

- (void)focusLayerNormal
{
    self.userInteractionEnabled = YES;
    [_focusLayer removeFromSuperlayer];
    
}

- (void)focusAtPoint:(CGPoint)point
{
    //测试初始坐标位置，请注释
    //CGSize frameSize = [self frame].size;
    //UIImage *focusImage = [UIImage imageNamed:@"fc_cam_focus"];
    //UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, focusImage.size.width, focusImage.size.height)];
    //imageView.image = focusImage;
    //CALayer *layer = imageView.layer;
    //layer.bounds = CGRectMake(0, 0, focusImage.size.width,focusImage.size.height);//层设置为图片大小
    //layer.contents =(id)focusImage.CGImage;
    //layer.position = CGPointMake( frameSize.width * pointOfInterest.x, frameSize.height * pointOfInterest.y);//层在view的位置
    //[self.layer addSublayer:layer];
    //_focusLayer = layer;
    
    AVCaptureDevice *device = videoCamera.inputCamera;
    
    NSError *error = nil;
    
    if ([device lockForConfiguration:&error]) {
        //自动闪光灯，
        if ([device isFlashModeSupported:AVCaptureFlashModeOn]) {
            [device setFlashMode:AVCaptureFlashModeOn];
            NSLog(@"Flash now");
        }
        //白平衡模式
        if([device isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance] ) {
            [device setWhiteBalanceMode:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance];
            NSLog(@"WhiteBalance now");
        }
        //对焦模式
        if ([device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus] && [device isFocusPointOfInterestSupported]) {
            [device setFocusPointOfInterest:point];
            [device setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
            NSLog(@"Focus now");
        }
        //曝光模式
        if ([device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
            [device setExposurePointOfInterest:point];
            [device setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
            NSLog(@"Expose now");
        }
        [device unlockForConfiguration];
        
    }
    else {
        NSLog(@"Error Mode");
    }
    
}


#pragma mark - Face Info

- (void)animateKeyframesWithKeywords:(NSString *)keywords
{
    [self.uiElementItemManager animateKeyframesWithKeywords:keywords];
}

- (void)setPointsArray:(NSMutableArray *)points
{
    [self p_parseMouthFromPoints:points];
//    NSLog(@"...points:%@....",points);
    [self.uiElementItemManager setPointsArray:points];
}

- (void)hidenFace
{
    [self.uiElementItemManager hidenFace];
}

- (void)p_parseMouthFromPoints:(NSMutableArray *)points
{
    if (points.count > 0) {
        //只做第一个的人脸处理,,
        NSDictionary *dicPerson = points.firstObject;
        if ([dicPerson objectForKey:POINTS_KEY]) {
            for (DHTrackPoint *tPoint in [dicPerson objectForKey:POINTS_KEY]) {
                if ([tPoint.pointKey isEqualToString:MOUTH_UPPER]) {
                    _mouthUpper = POINT(tPoint.point.x / DHShowVideoWidth, tPoint.point.y / DHShowVideoHeight);
                    break;
                }
            }
        }
    }

}


#pragma mark -

- (NSString *)cardIdForTestData
{
    return [self.uiElementItemManager cardIdForTestData];
}

#pragma mark - VideoCamera Delegate

- (void)willOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer{
    //分线程处理。。
//    if (_delegate && [_delegate respondsToSelector:@selector(willOutputSampleBuffer:cameraPosition:)]) {
//        [_delegate willOutputSampleBuffer:sampleBuffer cameraPosition:[videoCamera cameraPosition]];
//    }
    
    //已在分线程处理。。脸部画面处理成脸部位置数据，，
    [self.trackFaceProgress trackFaceProgress:sampleBuffer
                               cameraPosition:[videoCamera cameraPosition]
                         interfaceOrientation:UIInterfaceOrientationPortrait];//TODO:..
}

//#pragma mark - DHGPUCameraViewDelegate
//
////输出最新脸部画面。。CameraViewDelegate
//- (void)willOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer cameraPosition:(AVCaptureDevicePosition)cameraPosition{
//    
//}


#pragma mark - DHTrackFaceProgressDelegate

//输出最新脸部位置数据分析。。
- (void)showFaceRectWithPersonsArray:(NSMutableArray *)arrPersons
{
    //回调到主线程
    //arrPersons。。
    //实时脸部数据，，
    if (self.viewCanvas.hidden) {
        self.viewCanvas.hidden = NO;
    }
    @synchronized (self) {
        self.hiddenFace = NO;
    }
    self.viewCanvas.arrPersons = arrPersons;
    [self.viewCanvas setNeedsDisplay];
    
    //为animationImgView设置最新脸部数据。。
    [self setPointsArray:arrPersons];
    
//    [self.parentView hiddenRecognitionTipView];
}

//未检测到人脸时回调。。。
- (void)hideFaceRect
{
    //回调到主线程
    if (!self.viewCanvas.hidden) {
        self.viewCanvas.hidden = YES ;
    }
    @synchronized (self) {
        self.hiddenFace = YES;
    }
    
    [self hidenFace];
    
    if ([self isAnimation]) {
//        [self.parentView showRecognitionTipView];
    }
}


#pragma mark - GPUImageMovieWriterDelegate

- (void)movieRecordingCompleted
{
    NSLog(@"movieRecordingCompleted");
}

- (void)movieRecordingFailedWithError:(NSError*)error
{
    NSLog(@"movieRecordingFailedWithError");
}

@end
