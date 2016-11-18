#import "GPUImageFilter.h"


/// Creates a bulge distortion on the image
@interface GPUImageFaceliftFilter : GPUImageFilter
{
    GLint faceliftFilterTypeUniform, aspectRatioUniform, radiusUniform, centerUniform, scaleUniform;
}

@property(readwrite, nonatomic) int faceliftFilterType;//0 所有 1 左右 2 上下

/// The center about which to apply the distortion, with a default of (0.5, 0.5)
@property(readwrite, nonatomic) CGPoint center;
/// The radius of the distortion, ranging from 0.0 to 1.0, with a default of 0.05
@property(readwrite, nonatomic) CGFloat radius;
/// The amount of distortion to apply, from -1.0 to 1.0, with a default of 0
@property(readwrite, nonatomic) CGFloat scale;

//位置参数,,
@property (nonatomic, copy) NSString                  *face;
@property (nonatomic, assign) CGPoint                 offset;//偏移倍数,,
@property (nonatomic, assign) CGFloat                 multiple;//半径倍数,,
//动画参数,,
@property (nonatomic, strong) NSArray                 *scaleFrames;
@property (nonatomic, assign) int                     frameIndex;

@property (nonatomic, copy) NSString                  *testScale;

- (id)initWithFaceliftFilterType:(int)type;

- (void)calculateArrPersons:(NSArray *)arrPersons;

- (void)calculateArrPersons:(NSArray *)arrPersons frontFacingCamera:(BOOL)front;

- (void)showFaceWithScale:(CGFloat)scale;

- (void)hideFace;

@end
