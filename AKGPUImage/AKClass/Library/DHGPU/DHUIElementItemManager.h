//
//  DHUIElementItemManager.h
//  DHOCChat
//
//  Created by AKing on 16/4/1.
//  Copyright © 2016年 AKing. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DHSlotModel2.h"
#import "DHMakeFilterItem.h"
#import "GPUImage.h"

@class DHMakeView;

@interface DHUIElementItemManager : NSObject
{
    GPUImageOutput<GPUImageInput> *outputFilter;
}

@property (nonatomic, weak) DHMakeView                     *parentView;
@property (nonatomic, assign, getter=isAnimating) BOOL     animating;


+ (DHUIElementItemManager *)uiElementItemManagerWithInput:(GPUImageVideoCamera *)input
                                                   output:(GPUImageMovieWriter *)output
                                               outputView:(GPUImageView *)outputView;

- (void)animateKeyframesWithKeywords:(NSString *)keywords;
- (void)changeFilterItem:(DHMakeFilterItem *)newFilterItem;
- (void)changeBeautifulFilterState;
- (void)setPointsArray:(NSMutableArray *)points;
- (void)hidenFace;
- (void)stopRecord;
- (void)stopAnimation;
//测试需要的cardId,,
- (NSString *)cardIdForTestData;


@end
