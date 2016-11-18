//
//  DHGPUView.h
//  DHOCChat
//
//  Created by AKing on 16/3/18.
//  Copyright © 2016年 AKing. All rights reserved.
//

#import "GPUImage.h"
#import "CanvasView.h"
#import "DHUIElementItemManager.h"

@class DHMakeView;

@interface DHGPUCameraView : GPUImageView

@property (nonatomic, strong) CanvasView                 *viewCanvas;
@property (nonatomic,getter=isRecording) BOOL            recording;
@property (copy, nonatomic)   NSString                   *videoPath;

//重构
@property (nonatomic, weak) DHMakeView                      *parentView;
@property (assign, nonatomic,getter=isHiddenFace) BOOL      hiddenFace;



- (void)gpuViewDidAppear;
- (void)gpuViewWillDisappear;

- (void)rotateCamera;

- (void)startRecord;
- (void)stopRecord;

//faceInfo
- (void)setPointsArray:(NSMutableArray *)points;
- (void)animateKeyframesWithKeywords:(NSString *)keywords;
- (void)hidenFace;

- (void)changeFilterItem:(DHMakeFilterItem *)fItem;
- (void)changeBeautifulFilterState;

- (BOOL)isAnimation;

- (NSString *)cardIdForTestData;

@end
