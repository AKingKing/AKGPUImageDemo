//
//  GPUImageBeautifyFilter.m
//  BeautifyFaceDemo
//
//  Created by guikz on 16/4/28.
//  Copyright © 2016年 guikz. All rights reserved.
//

#import "GPUImageBeautifyFilter.h"

// Internal CombinationFilter(It should not be used outside)
@interface GPUImageCombinationFilter : GPUImageThreeInputFilter
{
    GLint smoothDegreeUniform;
}

@property (nonatomic, assign) CGFloat intensity;
@property (nonatomic, assign) CGFloat edgeStrength;

@end

NSString *const kGPUImageBeautifyFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 varying highp vec2 textureCoordinate2;
 varying highp vec2 textureCoordinate3;
 
 uniform sampler2D inputImageTexture;
 uniform sampler2D inputImageTexture2;
 uniform sampler2D inputImageTexture3;
 uniform mediump float smoothDegree;
 
 
// // RGB <-> HSV conversion, thanks to http://lolengine.net/blog/2013/07/27/rgb-to-hsv-in-glsl
// highp vec3 rgb2hsv(highp vec3 c)
//{
//    highp vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
//    highp vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
//    highp vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
//    
//    highp float d = q.x - min(q.w, q.y);
//    highp float e = 1.0e-10;
//    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
//}
// 
// // HSV <-> RGB conversion, thanks to http://lolengine.net/blog/2013/07/27/rgb-to-hsv-in-glsl
// highp vec3 hsv2rgb(highp vec3 c)
//{
//    highp vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
//    highp vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
//    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
//}

 
 void main()
 {
     highp vec4 bilateral = texture2D(inputImageTexture, textureCoordinate);
     highp vec4 canny = texture2D(inputImageTexture2, textureCoordinate2);
     highp vec4 origin = texture2D(inputImageTexture3,textureCoordinate3);
     highp vec4 smooth;
     lowp float r = origin.r;
     lowp float g = origin.g;
     lowp float b = origin.b;
     if (canny.r < 0.2 && r > 0.3725 && g > 0.1568 && b > 0.0784 && r > b && (max(max(r, g), b) - min(min(r, g), b)) > 0.0588 && abs(r-g) > 0.0588) {
         smooth = (1.0 - smoothDegree) * (origin - bilateral) + bilateral;
     }
     else {
         smooth = origin;
     }
     smooth.r = log(1.0 + 0.2 * smooth.r)/log(1.2);
     smooth.g = log(1.0 + 0.2 * smooth.g)/log(1.2);
     smooth.b = log(1.0 + 0.2 * smooth.b)/log(1.2);
     gl_FragColor = smooth;
     
//     //肤色调整
//     // Convert color to HSV, extract hue
//     highp vec3 colorHSV = rgb2hsv(smooth.rgb);
//     highp float hue = colorHSV.x;
//     // check how far from skin hue
//     highp float dist = hue - 0.05; //skinHue 0.05
//     if (dist > 0.5)
//         dist -= 1.0;
//     if (dist < -0.5)
//         dist += 1.0;
//     dist = abs(dist)/0.5; // normalized to [0,1]
//     // Apply Gaussian like filter
//     highp float weight = exp(-dist*dist*40.0); //skinHueThreshold 40.0
//     weight = clamp(weight, 0.0, 1.0);
//     lowp float skinToneAdjust = 0.0; //建议最小/最大：-0.3和0.3
//     colorHSV.y += skinToneAdjust * weight * 0.4; //maxSaturationShift 0.4
//     //colorHSV.z += skinToneAdjust * weight * 0.4; //maxHueShift 0.25
//     // final color
//     highp vec3 finalColorRGB = hsv2rgb(colorHSV.rgb);
     
     
//     lowp float average = (smooth.r + smooth.g + smooth.b) / 3.0;
//     lowp float mx = max(smooth.r, max(smooth.g, smooth.b));
//     lowp float vibrance = 0.3; //使用0.0作为默认设置，建议最小/最大-1.2左右和1.2，
//     lowp float amt = (mx - average) * (-vibrance * 3.0);
//     smooth.rgb = mix(smooth.rgb, vec3(mx), amt);
//     
//     // display
//     gl_FragColor = smooth;
     
     
 }
 );

@implementation GPUImageCombinationFilter

- (id)init {
    if (self = [super initWithFragmentShaderFromString:kGPUImageBeautifyFragmentShaderString]) {
        smoothDegreeUniform = [filterProgram uniformIndex:@"smoothDegree"];
    }
    self.intensity = 0.6f;
    self.edgeStrength = 8.0f;
    return self;
}

- (void)setIntensity:(CGFloat)intensity {
    _intensity = intensity;
    [self setFloat:intensity forUniform:smoothDegreeUniform program:filterProgram];
}

@end

@implementation GPUImageBeautifyFilter

+ (GPUImageBeautifyFilter *)beautifyFilterWithCombinationIntensity:(CGFloat)intensity
                                                      edgeStrength:(CGFloat)edgeStrength
{
    return [[GPUImageBeautifyFilter alloc] initWithCombinationIntensity:intensity edgeStrength:edgeStrength];
}

- (id)initWithCombinationIntensity:(CGFloat)intensity edgeStrength:(CGFloat)edgeStrength
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    // First pass: face smoothing filter
    bilateralFilter = [[GPUImageBilateralFilter alloc] init];
    //bilateralFilter.texelSpacingMultiplier = 4.0;
    bilateralFilter.distanceNormalizationFactor = 6.0;
    [self addFilter:bilateralFilter];
    
    // Second pass: edge detection
    thresholdedgedetectionFilter = [[GPUImageThresholdEdgeDetectionFilter alloc] init];
    thresholdedgedetectionFilter.edgeStrength = edgeStrength;
    [self addFilter:thresholdedgedetectionFilter];
    
    // Third pass: combination bilateral, edge detection and origin
    combinationFilter = [[GPUImageCombinationFilter alloc] init];
    [combinationFilter setIntensity:intensity];
    [self addFilter:combinationFilter];
    
    //阴影和高光优化
    highlightShadowFilter = [[GPUImageHighlightShadowFilter alloc] init];
    highlightShadowFilter.shadows = 0.1;
    highlightShadowFilter.highlights = 0.9;
    [self addFilter:highlightShadowFilter];
    
//    //双边模糊优化
//    bilateralSecondFilter = [[GPUImageBilateralFilter alloc] init];
//    bilateralSecondFilter.texelSpacingMultiplier = 0.4;
//    bilateralSecondFilter.distanceNormalizationFactor = 8.0;
//    [self addFilter:bilateralSecondFilter];
    
    
    //美颜处理
    [bilateralFilter addTarget:combinationFilter];
    [thresholdedgedetectionFilter addTarget:combinationFilter];
    [combinationFilter addTarget:highlightShadowFilter];
//    [highlightShadowFilter addTarget:bilateralSecondFilter];
    
    self.initialFilters = [NSArray arrayWithObjects:bilateralFilter,thresholdedgedetectionFilter,combinationFilter,nil];
    self.terminalFilter = highlightShadowFilter;
    
    return self;
}

#pragma mark -
#pragma mark GPUImageInput protocol

- (void)newFrameReadyAtTime:(CMTime)frameTime atIndex:(NSInteger)textureIndex;
{
    for (GPUImageOutput<GPUImageInput> *currentFilter in self.initialFilters)
    {
        if (currentFilter != self.inputFilterToIgnoreForUpdates)
        {
            if (currentFilter == combinationFilter) {
                textureIndex = 2;
            }
            [currentFilter newFrameReadyAtTime:frameTime atIndex:textureIndex];
        }
    }
}

- (void)setInputFramebuffer:(GPUImageFramebuffer *)newInputFramebuffer atIndex:(NSInteger)textureIndex;
{
    for (GPUImageOutput<GPUImageInput> *currentFilter in self.initialFilters)
    {
        if (currentFilter == combinationFilter) {
            textureIndex = 2;
        }
        [currentFilter setInputFramebuffer:newInputFramebuffer atIndex:textureIndex];
    }
}

@end
