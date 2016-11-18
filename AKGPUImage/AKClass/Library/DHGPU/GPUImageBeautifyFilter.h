//
//  GPUImageBeautifyFilter.h
//  BeautifyFaceDemo
//
//  Created by guikz on 16/4/28.
//  Copyright © 2016年 guikz. All rights reserved.
//

#import <GPUImage/GPUImage.h>

@class GPUImageCombinationFilter;

@interface GPUImageBeautifyFilter : GPUImageFilterGroup {
    GPUImageBilateralFilter *bilateralFilter;
    GPUImageThresholdEdgeDetectionFilter *thresholdedgedetectionFilter;
    GPUImageCombinationFilter *combinationFilter;
    GPUImageBilateralFilter *bilateralSecondFilter;
    GPUImageHighlightShadowFilter *highlightShadowFilter;
    
}

@property (nonatomic, assign) CGFloat combinationIntensity;

+ (GPUImageBeautifyFilter *)beautifyFilterWithCombinationIntensity:(CGFloat)intensity
                                                      edgeStrength:(CGFloat)edgeStrength;


@end
