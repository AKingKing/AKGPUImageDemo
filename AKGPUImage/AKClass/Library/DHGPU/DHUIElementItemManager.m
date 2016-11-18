//
//  DHUIElementItemManager.m
//  DHOCChat
//
//  Created by AKing on 16/4/1.
//  Copyright © 2016年 AKing. All rights reserved.
//

#import "DHUIElementItemManager.h"
#import "GPUImageBeautifyFilter.h"
#import "FCFileManager.h"
#import "DHUIElementFilter.h"
#import "DHUIElementMultiplyFilter.h"
#import "DHUIElementOverlayFilter.h"
#import "DHUIElementSoftLightFilter.h"
#import "DHLookupFilter.h"
#import "GPUImageFaceliftFilter.h"
#import "GPUImage.h"
#import "DHCardModel2.h"
#import "DHMakeViewController.h"
#import "DHAudioModel.h"
#import "DHTipModel.h"
#import "DHFlagUtility.h"
#import "DHMakeView.h"

@interface DHUIElementItemManager ()<AVAudioPlayerDelegate>

@property (nonatomic, strong) NSArray                        *arrPersons;
@property (nonatomic, assign) BOOL                           detectFace;//用于检测人脸

@property (nonatomic, strong) DHCardModel2                   *cardAnimation;//动画效果
@property (nonatomic, strong) DHMakeFilterItem               *selectedFilter;//用户选择滤镜

@property (nonatomic, strong) NSMutableArray                 *faceArray;      //贴纸filter
@property (nonatomic, strong) NSMutableArray                 *faceliftArray;  //变形filter
@property (nonatomic, strong) NSMutableArray                 *normalArray;    //普通GPUImageFaceliftFilter

@property (nonatomic, strong) GPUImageVideoCamera            *videoCamera;
@property (nonatomic, strong) GPUImageMovieWriter            *movieWriter;
@property (nonatomic, strong) GPUImageView                   *videoShowView;

@property (nonatomic, strong) NSMutableArray                  *audioArray;
@property (nonatomic, strong) AVAudioPlayer                   *audioPlayer;
@property (nonatomic, strong) AVAudioPlayer                   *audioPlayer1;
@property (nonatomic, strong) AVAudioPlayer                   *audioPlayer2;
@property (nonatomic, strong) AVAudioPlayer                   *audioPlayer3;

@property (nonatomic, strong) NSMutableArray                  *tipsArray;

@property (nonatomic, assign) int                             animationFrame;

@property (nonatomic, assign) BOOL                            processing;
@property (nonatomic, assign) BOOL                            willStopAnimation;

@end

@implementation DHUIElementItemManager


+ (DHUIElementItemManager *)uiElementItemManagerWithInput:(GPUImageVideoCamera *)input
                                                   output:(GPUImageMovieWriter *)output
                                               outputView:(GPUImageView *)outputView
{
    return [[DHUIElementItemManager alloc] initWithInput:input output:output outputView:outputView];
}


- (id)initWithInput:(GPUImageVideoCamera *)input
             output:(GPUImageMovieWriter *)output
         outputView:(GPUImageView *)outputView
{
    self = [super init];
    if (self) {
        
        self.willStopAnimation = NO;
        self.faceArray = [NSMutableArray array];
        self.normalArray = [NSMutableArray array];
        self.faceliftArray = [NSMutableArray array];
        self.audioArray = [NSMutableArray array];
        self.tipsArray = [NSMutableArray array];
        
        self.selectedFilter = [DHMakeFilterItem getStorageFilterItem];
        
        [self setupFiltersWithInput:input
                             output:output
                         outputView:outputView];
    }
    
    return self;
}


- (void)setupFiltersWithInput:(GPUImageVideoCamera *)input
                       output:(GPUImageMovieWriter *)output
                   outputView:(GPUImageView *)outputView
{
    self.videoCamera = input;
    self.movieWriter = output;
    self.videoShowView = outputView;
    
    [self addFilterTargets];
}

//分线程中
- (void)frameProcessingCompletionBlockCallBack
{
    @synchronized (self) {
        WEAK_SELF(wself);
        @synchronized (outputFilter) {
            [outputFilter setFrameProcessingCompletionBlock:^(GPUImageOutput *filter, CMTime frameTime) {
                STRONG_SELF(sself);
                //当动画开启时，，，
                if (sself.isAnimating && sself.cardAnimation) {

                    //上次未处理结束则返回,,
                    if (sself.processing) {
                        return ;
                    }
                    sself.processing = YES;
                    
                    //音频
                    for (DHAudioModel *aModel in sself.audioArray) {
                        if (aModel.beginFrame == _animationFrame) {
                            [sself p_playAudioWithModel:aModel];
                            [sself.audioArray removeObject:aModel];
                            break;
                        }
                    }
                    
                    //tip
                    for (DHTipModel *tModel in sself.tipsArray) {
                        if (tModel.beginFrame == _animationFrame) {
                            
                            [sself.parentView showCommandTipsViewWithTag:201610 + _animationFrame
                                                                           tip:tModel.tip
                                                                      duration:tModel.duration];
                            [sself.tipsArray removeObject:tModel];
                            break;
                        }
                    }
                    
                    for (GPUImageTwoInputFilter *tFilter in sself.faceArray) {
                        if (tFilter.imgIndex >= tFilter.totalImgs) {
                            
                            [sself stopAnimation];
                            return ;
                            
                            //                        eFilter.imgIndex = 0;
                        }
                        
                        
                        int absoluteIndex = tFilter.imgIndex % tFilter.subTotalImgs;
                        UIImage *img = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/%d",tFilter.path, absoluteIndex]];
                        tFilter.uiImageView.image = img;
                        [tFilter.uiElement update];
                        
                        tFilter.imgIndex += 1;
                    }
                    
                    for (GPUImageFaceliftFilter *fFilter in sself.faceliftArray) {
                        
                        if (fFilter.frameIndex >= fFilter.scaleFrames.count) {
                            
                            [sself stopAnimation];
                            return ;
                            
                            //                        fFilter.frameIndex = 0;
                        }
                        
                        if (IS_STRING_EMPTY(fFilter.testScale)) {
                            fFilter.scale = [fFilter.scaleFrames[fFilter.frameIndex] floatValue];
                        }else {
                            fFilter.scale = [fFilter.testScale floatValue];
                        }
                        
                        //                    fFilter.scale = [fFilter.scaleFrames[fFilter.frameIndex] floatValue];
                        fFilter.frameIndex += 1;
                    }
                    
                    _animationFrame += 1;
                    //处理结束,,
                    if (sself.willStopAnimation) {
                        sself.willStopAnimation = NO;
                        [sself stopAnimation];
                    }else {
                        //self.willStopAnimation为YES时不再进入处理状态,,
                        sself.processing = NO;
                    }
                }
                
            }];
        }
    }
    
}

#pragma mark - Start/Stop Animation

- (void)animateKeyframesWithKeywords:(NSString *)keywords
{
    WEAK_SELF(wself);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        STRONG_SELF(sself);
        
        DHCardModel2 *cardModel = [DHCardModel2 prepareDataWithCommand:keywords];
        if (cardModel) {
            [sself startAnimation:cardModel];
        }

    });
    
}

- (void)changeFilterItem:(DHMakeFilterItem *)newFilterItem
{
    WEAK_SELF(wself);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        STRONG_SELF(sself);
        @synchronized (sself) {
            sself.selectedFilter = nil;
            sself.selectedFilter = newFilterItem;
            if (sself.isAnimating) {
                return;
            }else {
                [sself addFilterTargets];
            }
            
        }
    });
    
}

- (void)changeBeautifulFilterState
{
    WEAK_SELF(wself);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        STRONG_SELF(sself);
        @synchronized (sself) {
            if (sself.isAnimating) {
                return;
            }else {
                [sself addFilterTargets];
            }
            
        }
    });
}

//分线程中
- (void)startAnimation:(DHCardModel2 *)cardModel
{
    @synchronized (self) {
        if (self.isAnimating) {
            return;
        }else {
            
            self.willStopAnimation = NO;
            self.processing = NO;
            
            self.cardAnimation = nil;
            self.cardAnimation = cardModel;
            
            [self addFilterTargets];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.parentView t_removeVolumeNotifity];
            });
        }
    };
}

//分线程中
//调用addFilterTargets方法时使用@synchronized安全调用
- (void)addFilterTargets
{
    //先移除所有
    @synchronized (outputFilter) {
        outputFilter.frameProcessingCompletionBlock = nil;
    }
    [outputFilter removeAllTargets];
    [self.videoCamera removeAllTargets];

    //再次主动开启问题
    [self.faceArray removeAllObjects];
    [self.faceliftArray removeAllObjects];
    [self.normalArray removeAllObjects];
    [self.audioArray removeAllObjects];
    [self.tipsArray removeAllObjects];

    //重新创建所有filter，根据model对象是否存在判断是否需要相应filter。。
    BOOL hasEyeLeftFilter = NO;
    BOOL hasEyeRightFilter = NO;
    BOOL hasMouthCenterFilter = NO;

    NSMutableArray *tmpFaceArray = [NSMutableArray array];
    if (self.cardAnimation) {

        if (self.cardAnimation.facePosition.count > 0) {

            //先只处理一个人人脸效果
            NSArray *subArray = self.cardAnimation.facePosition[0];
            for (DHAnimationModel2 *aModel in subArray) {
                //所有部位效果,,
                if (!IS_STRING_EMPTY(aModel.sticker_set_folder)) {
                    
                    GPUImageTwoInputFilter *tFilter;
                    switch ([aModel.sticker_set_blend intValue]) {
                        case DHElementBlendOverlay:
                            tFilter = [[DHUIElementOverlayFilter alloc] init];
                            break;
                        case DHElementBlendSoftLight:
                            tFilter = [[DHUIElementSoftLightFilter alloc] init];
                            break;
                        case DHElementBlendMultiply:
                            tFilter = [[DHUIElementMultiplyFilter alloc] init];
                            break;
                        case DHElementBlendAlpha:
                        default:
                            tFilter = [[DHUIElementFilter alloc] init];
                            break;
                    }
                    
                    tFilter.uiImageView.alpha = 1.0;
                    tFilter.face = aModel.face;
                    tFilter.anchor = aModel.stickerAnchor;
                    tFilter.offset = aModel.stickerOffset;
                    tFilter.imgSize = aModel.stickerImgSize;
                    tFilter.multiple = aModel.stickerMultiple;
                    tFilter.subTotalImgs = [aModel.sticker_set_subtotal intValue];
                    tFilter.path = [DH_COMMAND_BASE_PATH(aModel.cardId) stringByAppendingString:[NSString stringWithFormat:@"/%@",aModel.sticker_set_folder]];
                    tFilter.totalImgs = [self.cardAnimation.total intValue];
                    
                    [tmpFaceArray addObject:tFilter];
                }
                
                //变形效果
                if (!IS_STRING_EMPTY(aModel.scale_set_mode)) {
                    
                    int type = [aModel.scale_set_mode intValue];
                    if (type < 0 || type > 2) {
                        type = 0;
                    }
                    GPUImageFaceliftFilter *facelift = [[GPUImageFaceliftFilter alloc] initWithFaceliftFilterType:type];
                    if ([aModel.face isEqualToString:DHFacePositionEyeLeft]) {
                        hasEyeLeftFilter = YES;
                    }else if ([aModel.face isEqualToString:DHFacePositionEyeRight]) {
                        hasEyeRightFilter = YES;
                    }else if ([aModel.face isEqualToString:DHFacePositionMouthCenter]) {
                        hasMouthCenterFilter = YES;
                    }
                    
                    facelift.face = aModel.face;
                    facelift.multiple = aModel.scaleMultiple;
                    facelift.offset = aModel.scaleOffset;
                    facelift.scaleFrames = [NSArray arrayWithArray:aModel.frame_set];
                    facelift.testScale = aModel.testScale;
                    [self.faceliftArray addObject:facelift];
                }
                
            }
        }
        
        NSMutableArray *personsArr = [self.arrPersons mutableCopy];
        [self calculateFrameWithArrPersons:personsArr];

        //音频
        NSArray *bigArr = [self.cardAnimation.sound componentsSeparatedByString:@","];
        for (NSString *subStr in bigArr) {
            
            NSArray *smallArr = [subStr componentsSeparatedByString:@"_"];
            if (smallArr.count > 2) {
                DHAudioModel *audioModel = [[DHAudioModel alloc] init];
                audioModel.playTimes = [smallArr[0] intValue] - 1;//json 0循环 1不循环
                audioModel.beginFrame = [smallArr[1] intValue];
                audioModel.videoPath =  [DH_COMMAND_BASE_PATH(self.cardAnimation.cardId) stringByAppendingString:[NSString stringWithFormat:@"/%@",smallArr[2]]];
                [self.audioArray addObject:audioModel];
            }
        }
        
        //tip
        bigArr = [self.cardAnimation.tips componentsSeparatedByString:@","];
        for (NSString *subStr in bigArr) {
            NSArray *smallArr = [subStr componentsSeparatedByString:@"_"];
            if (smallArr.count > 2) {
                DHTipModel *tModel = [[DHTipModel alloc] init];
                tModel.beginFrame = [smallArr[0] intValue];
                tModel.duration = [smallArr[1] floatValue];
                tModel.tip = smallArr[2];
                [self.tipsArray addObject:tModel];
            }
        }
        
        self.animating = YES;
    }

    //初始化瘦脸大眼参数,,变形没有且用户打开微美型时添加默认,,
    if ([DHFlagUtility filterBeautifulOpen]) {
        //左眼初始值
        if (!hasEyeLeftFilter) {
            GPUImageFaceliftFilter *facelift = [[GPUImageFaceliftFilter alloc] initWithFaceliftFilterType:0];
            facelift.face = DHFacePositionEyeLeft;
            facelift.multiple = 1.3f;
            facelift.scale = 0.05f;
            [self.normalArray addObject:facelift];
        }
        //右眼初始值
        if (!hasEyeRightFilter) {
            GPUImageFaceliftFilter *facelift = [[GPUImageFaceliftFilter alloc] initWithFaceliftFilterType:0];
            facelift.face = DHFacePositionEyeRight;
            facelift.multiple = 1.3f;
            facelift.scale = 0.05f;
            [self.normalArray addObject:facelift];
        }
        //嘴中初始值
        if (!hasMouthCenterFilter) {
            GPUImageFaceliftFilter *facelift = [[GPUImageFaceliftFilter alloc] initWithFaceliftFilterType:0];
            facelift.face = DHFacePositionMouthCenter;
            facelift.multiple = 3.5f;
            facelift.scale = -0.015f;
            [self.normalArray addObject:facelift];
        }
    }
    
    CGFloat beautifyIntensity = 0.6f;
    CGFloat beautifyEdgeStrength = 8.0f;
    DHLookupFilter *lookupFilter = nil;
    if (IS_STRING_EMPTY(self.cardAnimation.LUT)) {
        
        if ([self.selectedFilter.selectedLUTImgName length] > 0) {

                //ImgName不存在时默认使用A3.data,,
                lookupFilter = [[DHLookupFilter alloc] initWithLUTImgName:self.selectedFilter.selectedLUTImgName];
                
                beautifyIntensity = self.selectedFilter.beautifyIntensity;
                beautifyEdgeStrength = self.selectedFilter.beautifyEdgeStrength;;
 
        }
        
    }else {
        lookupFilter = [[DHLookupFilter alloc] initWithLUTImgName:[NSString stringWithFormat:@"%@.data",self.cardAnimation.LUT]];
        
        beautifyIntensity = [self.cardAnimation.intensity floatValue];
        beautifyEdgeStrength = [self.cardAnimation.strength floatValue];
    }

    //再添加，，同时所有filter要重新创建。。数组应该是保存创建filter所需的原始数据。。。。。
    GPUImageBeautifyFilter *bFilter = [GPUImageBeautifyFilter
                                       beautifyFilterWithCombinationIntensity:beautifyIntensity
                                       edgeStrength:beautifyEdgeStrength];
    outputFilter = bFilter;
    
    [self.videoCamera addTarget:bFilter];
    
    GPUImageOutput *currentFilter = bFilter;
    
    for (GPUImageFilter *fFilter in self.faceliftArray) {
        [currentFilter addTarget:fFilter];
        currentFilter = fFilter;
    }
    
    for (GPUImageFilter *normalFilter in self.normalArray) {
        [currentFilter addTarget:normalFilter];
        currentFilter = normalFilter;
    }
    
    //GPUImageThreeInputFilter 修复bug引起addTarget叠加顺序改变,,
    [tmpFaceArray enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSLog(@"4倒序遍历array：%zi-->%@",idx,obj);
        [self.faceArray addObject:obj];
    }];
    for (GPUImageTwoInputFilter *tFilter in self.faceArray) {
        [currentFilter addTarget:tFilter atTextureLocation:0];
        [tFilter.uiElement addTarget:tFilter atTextureLocation:1];
        currentFilter = tFilter;
    }
    
    //滤镜,,
    if (lookupFilter) {
        [currentFilter addTarget:lookupFilter];
        currentFilter = lookupFilter;
    }
    
    [currentFilter addTarget:self.movieWriter];
    [currentFilter addTarget:self.videoShowView];
    
    [self frameProcessingCompletionBlockCallBack];
}


- (void)stopAnimation
{
    self.cardAnimation = nil;
    self.animating = NO;
    //更新滤镜管道，，
    [self addFilterTargets];
    
    [self.audioPlayer stop];
    [self.audioPlayer1 stop];
    [self.audioPlayer2 stop];
    [self.audioPlayer3 stop];

    self.audioPlayer = nil;
    self.audioPlayer1 = nil;
    self.audioPlayer2 = nil;
    self.audioPlayer3 = nil;

    _animationFrame = 0;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
//        DHMakeViewController *mvc = [AppManager getMakeVC];
        [self.parentView t_reloadVolumeNotifity];
        //移除未识别人脸提示图片..
        [self.parentView hiddenRecognitionTipView];
        
        [self.parentView shouldStopRecord];
    });
}


#pragma mark - Show/Hide Animation
//检测到人脸,,
- (void)setPointsArray:(NSMutableArray *)points
{
    @synchronized (self) {
        //避免动画正在进行时设置数据。。
        self.arrPersons = points;
        
        //设置frame。动画效果随着脸部移动。。当
        if (!self.detectFace) {
            [self showCurrentAnimation];
        }
        //只有动画时数组(faceArray faceliftArray)才有值,,
        [self calculateFrameWithArrPersons:points];
    }
}

//未检测到人脸,,
- (void)hidenFace
{
    @synchronized (self) {
        if (self.detectFace) {
            
            [self hidenCurrentAnimation];
        }
    }
    
}


- (void)showCurrentAnimation
{
    //必须判断当前需要显示的。。。
    for (GPUImageTwoInputFilter *tFilter in self.faceArray) {
        UIImageView *imgView = tFilter.uiImageView;
        //正在使用中的动画显示。。
        imgView.alpha = 1.0f;
    }
    
    //卡牌特效结束恢复初始值
    for (GPUImageFaceliftFilter *flFilter in self.normalArray) {
        
        if ([flFilter.face isEqualToString:DHFacePositionEyeLeft]) {
            [flFilter showFaceWithScale:0.05f];
        }else if ([flFilter.face isEqualToString:DHFacePositionEyeRight]) {
            [flFilter showFaceWithScale:0.05f];
        }else if ([flFilter.face isEqualToString:DHFacePositionMouthCenter]) {
            [flFilter showFaceWithScale:-0.015f];
        }
    }
    
    self.detectFace = YES;
}


- (void)hidenCurrentAnimation
{
    for (GPUImageTwoInputFilter *tFilter in self.faceArray) {
        if (![tFilter.face isEqualToString:DHFacePositionBottomCenter]) {//背景不隐藏
            UIImageView *imgView = tFilter.uiImageView;
            imgView.alpha = 0.0f;
        }
    }
    
    for (GPUImageFaceliftFilter *fFilter in self.faceliftArray) {
        [fFilter hideFace];
    }
    
    for (GPUImageFaceliftFilter *fFilter in self.normalArray) {
        [fFilter hideFace];
    }
    
    self.detectFace = NO;
}

- (void)calculateFrameWithArrPersons:(NSArray *)points
{
    for (GPUImageTwoInputFilter *tFilter in self.faceArray) {
        [tFilter calculateArrPersons:points frontFacingCamera:[self.videoCamera cameraPosition] == AVCaptureDevicePositionFront];
    }
    
    for (GPUImageFaceliftFilter *fFilter in self.faceliftArray) {
        [fFilter calculateArrPersons:points frontFacingCamera:[self.videoCamera cameraPosition] == AVCaptureDevicePositionFront];
    }
    
    for (GPUImageFaceliftFilter *fFilter in self.normalArray) {
        [fFilter calculateArrPersons:points frontFacingCamera:[self.videoCamera cameraPosition] == AVCaptureDevicePositionFront];
    }
}

#pragma mark - Audio
//TODO: 命令词识别调用背景音乐,某帧触发调用,,
- (void)p_playAudioWithModel:(DHAudioModel *)audioModel
{
    if (self.cardAnimation) {
        
        AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:audioModel.videoPath] error:nil];
        player.delegate = self;
        player.numberOfLoops = audioModel.playTimes;//循环次数,, 0;//
        player.volume = 1.0f;
        player.enableRate = YES;
        player.rate = 1.0f;
        [player prepareToPlay];//分配播放所需的资源，并将其加入内部播放队列
        [player play];//播放;
        if (!_audioPlayer) {
            self.audioPlayer = player;
        }else if (!_audioPlayer1) {
            self.audioPlayer1 = player;
        }else if (!_audioPlayer2) {
            self.audioPlayer2 = player;
        }else if (!_audioPlayer3) {
            self.audioPlayer3 = player;
        }
    }
}


- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    //播放结束时执行的动作
    DLog(@"audioPlayerDidFinishPlaying");
}

#pragma mark -

- (void)stopRecord
{
    @synchronized (self) {
        @synchronized (outputFilter) {
            outputFilter.frameProcessingCompletionBlock = nil;
        }
        if (self.processing) {
            self.willStopAnimation = YES;
        }else {
            //防止再次进入处理过程中,,
            self.processing = YES;
            [self stopAnimation];
        }
        
    }
}

#pragma mark -

- (NSString *)cardIdForTestData
{
    if (self.cardAnimation) {
        return [self.cardAnimation.cardId copy];
    }
    return nil;
}

- (NSString *)getTimeNow
{
    NSString* date;
    
    NSDateFormatter * formatter = [[NSDateFormatter alloc ] init];
    //[formatter setDateFormat:@"YYYY.MM.dd.hh.mm.ss"];
    [formatter setDateFormat:@"YYYY-MM-dd hh:mm:ss:SSS"];
    date = [formatter stringFromDate:[NSDate date]];
    return date;
}

@end
