#import "GPUImageFaceliftFilter.h"
#import "DHTrackFaceProgress.h"
#import "DHAnimationModel2.h"

NSString *const kGPUImageFaceliftFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 
 uniform highp float faceliftFilterType;
 uniform highp float aspectRatio;
 uniform highp vec2 center;
 uniform highp float radius;
 uniform highp float scale;


 void main()
 {
    highp vec2 textureCoordinateToUse = vec2(textureCoordinate.x, ((textureCoordinate.y - center.y) * aspectRatio) + center.y);
    highp float dist = distance(center, textureCoordinateToUse);
    textureCoordinateToUse = textureCoordinate;
    
    if (dist < radius)
    {
        textureCoordinateToUse -= center;
        highp float percent = 1.0 - ((radius - dist) / radius) * scale;
        percent = percent * percent;
        
        if (faceliftFilterType < 0.9) {
            //整体缩放
            textureCoordinateToUse = vec2(textureCoordinateToUse * percent);
        }else if (faceliftFilterType < 1.9) {
            //左右
            textureCoordinateToUse = vec2(textureCoordinateToUse.x * percent, textureCoordinateToUse.y);
        }else {
            //上下缩放
            textureCoordinateToUse = vec2(textureCoordinateToUse.x , textureCoordinateToUse.y * percent);
        }
        
        textureCoordinateToUse += center;
    }
    
    gl_FragColor = texture2D(inputImageTexture, textureCoordinateToUse );    
 }
);


CGFloat ffDistanceBetweenPoints (CGPoint first, CGPoint second) {
    CGFloat deltaX = second.x - first.x;
    CGFloat deltaY = second.y - first.y;
    return sqrt(deltaX*deltaX + deltaY*deltaY );
};

CGPoint ffCenterBetweenPoints (CGPoint first, CGPoint second) {
    CGFloat cX = (second.x + first.x) / 2;
    CGFloat cY = (second.y + first.y) / 2;
    return CGPointMake(cX, cY);
};

@interface GPUImageFaceliftFilter ()

- (void)adjustAspectRatio;

@property (readwrite, nonatomic) CGFloat aspectRatio;

@end

@implementation GPUImageFaceliftFilter

@synthesize aspectRatio = _aspectRatio;
@synthesize center = _center;
@synthesize radius = _radius;
@synthesize scale = _scale;

#pragma mark -
#pragma mark Initialization and teardown


- (id)initWithFaceliftFilterType:(int)type
{
    if (!(self = [super initWithFragmentShaderFromString:kGPUImageFaceliftFragmentShaderString]))
    {
		return nil;
    }
    
    faceliftFilterTypeUniform = [filterProgram uniformIndex:@"faceliftFilterType"];
    aspectRatioUniform = [filterProgram uniformIndex:@"aspectRatio"];
    radiusUniform = [filterProgram uniformIndex:@"radius"];
    scaleUniform = [filterProgram uniformIndex:@"scale"];
    centerUniform = [filterProgram uniformIndex:@"center"];

    self.faceliftFilterType = type;
    self.radius = 0.05;
    self.scale = 0.0f;
    self.center = CGPointMake(0.5, 0.5);
    
    self.offset = CGPointZero;
    self.multiple = 1.0f;
    
    return self;
}

#pragma mark -
#pragma mark Accessors

- (void)setFaceliftFilterType:(int)faceliftFilterType
{
    _faceliftFilterType = faceliftFilterType;
    
    [self setFloat:_faceliftFilterType forUniform:faceliftFilterTypeUniform program:filterProgram];
}


- (void)adjustAspectRatio;
{
    if (GPUImageRotationSwapsWidthAndHeight(inputRotation))
    {
        [self setAspectRatio:(inputTextureSize.width / inputTextureSize.height)];
    }
    else
    {
        [self setAspectRatio:(inputTextureSize.height / inputTextureSize.width)];
    }
}

- (void)forceProcessingAtSize:(CGSize)frameSize;
{
    [super forceProcessingAtSize:frameSize];
    [self adjustAspectRatio];
}

- (void)setInputSize:(CGSize)newSize atIndex:(NSInteger)textureIndex;
{
    CGSize oldInputSize = inputTextureSize;
    [super setInputSize:newSize atIndex:textureIndex];
    
    if ( (!CGSizeEqualToSize(oldInputSize, inputTextureSize)) && (!CGSizeEqualToSize(newSize, CGSizeZero)) )
    {
        [self adjustAspectRatio];
    }
}

- (void)setAspectRatio:(CGFloat)newValue;
{
    _aspectRatio = newValue;
    
    [self setFloat:_aspectRatio forUniform:aspectRatioUniform program:filterProgram];
}

- (void)setInputRotation:(GPUImageRotationMode)newInputRotation atIndex:(NSInteger)textureIndex;
{
    [super setInputRotation:newInputRotation atIndex:textureIndex];
    [self setCenter:self.center];
    [self adjustAspectRatio];
}

- (void)setRadius:(CGFloat)newValue;
{
    _radius = newValue;
    
    [self setFloat:_radius forUniform:radiusUniform program:filterProgram];
}

- (void)setScale:(CGFloat)newValue;
{
    _scale = newValue;

    [self setFloat:_scale forUniform:scaleUniform program:filterProgram];
}

- (void)setCenter:(CGPoint)newValue;
{
    _center = newValue;
    
    CGPoint rotatedPoint = [self rotatedPoint:_center forRotation:inputRotation];
    
    [self setPoint:rotatedPoint forUniform:centerUniform program:filterProgram];
}

- (void)calculateArrPersons:(NSArray *)arrPersons
{
    [self calculateArrPersons:arrPersons frontFacingCamera:YES];
}

- (void)calculateArrPersons:(NSArray *)arrPersons frontFacingCamera:(BOOL)front
{
    CGFloat oW = 0;
    CGPoint cPoint = CGPointZero;
    
    if (arrPersons.count > 0) {
        //只做第一个的人脸处理,,
        NSDictionary *dicPerson = arrPersons.firstObject;
        
        CGPoint oWBorder = CGPointZero;
        CGPoint oWMiddle = CGPointZero;

        
        if ([dicPerson objectForKey:POINTS_KEY]) {
            
            int num = 0;
            if ([self.face isEqualToString:DHFacePositionBrowMiddle]) {
                
                CGPoint browLeft = CGPointZero;
                CGPoint browRight = CGPointZero;
                
                for (DHTrackPoint *tPoint in [dicPerson objectForKey:POINTS_KEY]) {
                    if ([tPoint.pointKey isEqualToString:RIGHT_EYEBROW_MIDDLE]) {
                        browRight = tPoint.point;
                        num += 1;
                        if (num == 2) {
                            break;
                        }
                    }else if ([tPoint.pointKey isEqualToString:LEFT_EYEBROW_MIDDLE]) {
                        oWBorder = tPoint.point;
                        browLeft = tPoint.point;
                        num += 1;
                        if (num == 2) {
                            break;
                        }
                    }
                }
                
                oWMiddle = ffCenterBetweenPoints(browLeft, browRight);
                oW = ffDistanceBetweenPoints(oWMiddle, oWBorder);
                cPoint = oWMiddle;
            }else if ([self.face isEqualToString:DHFacePositionBrowLeft]) {
                
                if (front) {//以前置摄像头为准
                    [self p_browLeft:dicPerson width:&oW point:&cPoint];
                }else {
                    [self p_browRight:dicPerson width:&oW point:&cPoint];
                }
                
                
            }else if ([self.face isEqualToString:DHFacePositionBrowRight]) {
                
                if (front) {//以前置摄像头为准
                    [self p_browRight:dicPerson width:&oW point:&cPoint];
                }else {
                    [self p_browLeft:dicPerson width:&oW point:&cPoint];
                }
                
            }else if ([self.face isEqualToString:DHFacePositionEyeMiddle]) {
                
                CGPoint eyeLeft = CGPointZero;
                CGPoint eyeRight = CGPointZero;
                
                for (DHTrackPoint *tPoint in [dicPerson objectForKey:POINTS_KEY]) {
                    if ([tPoint.pointKey isEqualToString:RIGHT_EYE_CENTER]) {
                        eyeRight = tPoint.point;
                        num += 1;
                        if (num == 2) {
                            break;
                        }
                    }else if ([tPoint.pointKey isEqualToString:LEFT_EYE_CENTER]) {
                        oWBorder = tPoint.point;
                        eyeLeft = tPoint.point;
                        num += 1;
                        if (num == 2) {
                            break;
                        }
                    }
                }
                
                oWMiddle = ffCenterBetweenPoints(eyeLeft, eyeRight);
                oW = ffDistanceBetweenPoints(oWMiddle, oWBorder);
                cPoint = oWMiddle;
                
            }else if ([self.face isEqualToString:DHFacePositionEyeLeft]) {
                
                if (front) {
                    [self p_eyeLeft:dicPerson width:&oW point:&cPoint];
                }else {
                    [self p_eyeRight:dicPerson width:&oW point:&cPoint];
                }
                
            }else if ([self.face isEqualToString:DHFacePositionEyeRight]) {
                
                if (front) {
                    [self p_eyeRight:dicPerson width:&oW point:&cPoint];
                }else {
                    [self p_eyeLeft:dicPerson width:&oW point:&cPoint];
                }
                
            }else if ([self.face isEqualToString:DHFacePositionNoseCenter]) {
                
                CGPoint noseTop = CGPointZero;
                CGPoint noseBottom = CGPointZero;
                
                for (DHTrackPoint *tPoint in [dicPerson objectForKey:POINTS_KEY]) {
                    if ([tPoint.pointKey isEqualToString:NOSE_TOP]) {
                        noseTop = tPoint.point;
                        num += 1;
                        if (num == 3) {
                            break;
                        }
                    }else if ([tPoint.pointKey isEqualToString:NOSE_BOTTOM]) {
                        noseBottom = tPoint.point;
                        num += 1;
                        if (num == 3) {
                            break;
                        }
                    }else if ([tPoint.pointKey isEqualToString:NOSE_LEFT]) {
                        oWBorder = tPoint.point;
                        num += 1;
                        if (num == 3) {
                            break;
                        }
                    }
                }
                
                oWMiddle = ffCenterBetweenPoints(noseTop, noseBottom);
                oW = ffDistanceBetweenPoints(oWMiddle, oWBorder);
                cPoint = oWMiddle;
                
            }else if ([self.face isEqualToString:DHFacePositionNoseLeft]) {
                
                if (front) {
                    [self p_noseLeft:dicPerson width:&oW point:&cPoint];
                }else {
                    [self p_noseRight:dicPerson width:&oW point:&cPoint];
                }
                
            }else if ([self.face isEqualToString:DHFacePositionNoseRight]) {
                
                if (front) {
                    [self p_noseRight:dicPerson width:&oW point:&cPoint];
                }else {
                    [self p_noseLeft:dicPerson width:&oW point:&cPoint];
                }
                
            }else if ([self.face isEqualToString:DHFacePositionNoseBottom]) {
                
                CGPoint noseTop = CGPointZero;
                CGPoint noseBottom = CGPointZero;
                
                for (DHTrackPoint *tPoint in [dicPerson objectForKey:POINTS_KEY]) {
                    if ([tPoint.pointKey isEqualToString:NOSE_TOP]) {
                        noseTop = tPoint.point;
                        num += 1;
                        if (num == 2) {
                            break;
                        }
                    }else if ([tPoint.pointKey isEqualToString:NOSE_BOTTOM]) {
                        noseBottom = tPoint.point;
                        oWMiddle = tPoint.point;
                        num += 1;
                        if (num == 2) {
                            break;
                        }
                    }
                }
                
                oWBorder = ffCenterBetweenPoints(noseTop, noseBottom);
                oW = ffDistanceBetweenPoints(oWMiddle, oWBorder);
                cPoint = oWMiddle;
                
            }else if ([self.face isEqualToString:DHFacePositionMouthCenter]) {
                
                for (DHTrackPoint *tPoint in [dicPerson objectForKey:POINTS_KEY]) {
                    if ([tPoint.pointKey isEqualToString:MOUTH_LEFT]) {
                        oWBorder = tPoint.point;
                        num += 1;
                        if (num == 2) {
                            break;
                        }
                    }else if ([tPoint.pointKey isEqualToString:MOUTH_MIDDLE]) {
                        oWMiddle = tPoint.point;
                        num += 1;
                        if (num == 2) {
                            break;
                        }
                    }
                }
                
                oW = ffDistanceBetweenPoints(oWMiddle, oWBorder);
                cPoint = oWMiddle;
                
            }else if ([self.face isEqualToString:DHFacePositionMouthLeft]) {
                
                if (front) {
                    [self p_mouthLeft:dicPerson width:&oW point:&cPoint];
                }else {
                    [self p_mouthRight:dicPerson width:&oW point:&cPoint];
                }
                
            }else if ([self.face isEqualToString:DHFacePositionMouthRight]) {
                
                if (front) {
                    [self p_mouthRight:dicPerson width:&oW point:&cPoint];
                }else {
                    [self p_mouthLeft:dicPerson width:&oW point:&cPoint];
                }
                
            }else if ([self.face isEqualToString:DHFacePositionMouthOpen]) {
                
                //先判断是否张嘴??
                
            }else if ([self.face isEqualToString:DHFacePositionNeckCenter]) {
                
                //
                for (DHTrackPoint *tPoint in [dicPerson objectForKey:POINTS_KEY]) {
                    if ([tPoint.pointKey isEqualToString:MOUTH_LOWER]) {
                        oWBorder = tPoint.point;
                        break;
                    }
                }
                
                CGRect rect=CGRectFromString([dicPerson objectForKey:RECT_KEY]);
                oWMiddle = CGPointMake(rect.origin.x + rect.size.width / 2, rect.origin.y + rect.size.height);
                
                oW = ffDistanceBetweenPoints(oWMiddle, oWBorder);
                cPoint = oWMiddle;
                
            }else if ([self.face isEqualToString:DHFacePositionBottomCenter]) {
  
            }else if ([self.face isEqualToString:DHFacePositionBottomLeft]) {

            }else if ([self.face isEqualToString:DHFacePositionBottomRight]) {
                
            }
        }
    }
    
    CGFloat radius = oW * self.multiple / DHShowVideoWidth;
    CGPoint point = POINT((cPoint.x + self.offset.x * oW) / DHShowVideoWidth, (cPoint.y + self.offset.y * oW) / DHShowVideoHeight);

    CGFloat scale = self.scale;
    if (self.frameIndex < self.scaleFrames.count) {
        scale = [self.scaleFrames[self.frameIndex] floatValue];
    }
    [self setRadius:radius];
    [self setCenter:point];
    [self setScale:scale];
}

- (void)showFaceWithScale:(CGFloat)scale
{
    [self setScale:scale];
}

- (void)hideFace
{
    [self setScale:0.0f];
}

- (void)p_browLeft:(NSDictionary *)dicPerson width:(CGFloat *)w point:(CGPoint *)p
{
    int num = 0;
    CGPoint oWBorder = CGPointZero;
    CGPoint oWMiddle = CGPointZero;
    
    for (DHTrackPoint *tPoint in [dicPerson objectForKey:POINTS_KEY]) {
        if ([tPoint.pointKey isEqualToString:LEFT_EYEBROW_MIDDLE]) {
            oWMiddle = tPoint.point;
            num += 1;
            if (num == 2) {
                break;
            }
        }else if ([tPoint.pointKey isEqualToString:LEFT_EYEBROW_LEFT]) {
            oWBorder = tPoint.point;
            num += 1;
            if (num == 2) {
                break;
            }
        }
    }
    
    *w = ffDistanceBetweenPoints(oWMiddle, oWBorder);
    *p = oWMiddle;
}

- (void)p_browRight:(NSDictionary *)dicPerson width:(CGFloat *)w point:(CGPoint *)p
{
    int num = 0;
    CGPoint oWBorder = CGPointZero;
    CGPoint oWMiddle = CGPointZero;
    
    for (DHTrackPoint *tPoint in [dicPerson objectForKey:POINTS_KEY]) {
        if ([tPoint.pointKey isEqualToString:RIGHT_EYEBROW_MIDDLE]) {
            oWMiddle = tPoint.point;
            num += 1;
            if (num == 2) {
                break;
            }
        }else if ([tPoint.pointKey isEqualToString:RIGHT_EYEBROW_RIGHT]) {
            oWBorder = tPoint.point;
            num += 1;
            if (num == 2) {
                break;
            }
        }
    }
    
    *w = ffDistanceBetweenPoints(oWMiddle, oWBorder);
    *p = oWMiddle;
}

- (void)p_eyeLeft:(NSDictionary *)dicPerson width:(CGFloat *)w point:(CGPoint *)p
{
    int num = 0;
    CGPoint oWBorder = CGPointZero;
    CGPoint oWMiddle = CGPointZero;
    
    for (DHTrackPoint *tPoint in [dicPerson objectForKey:POINTS_KEY]) {
        if ([tPoint.pointKey isEqualToString:LEFT_EYE_CENTER]) {
            oWMiddle = tPoint.point;
            num += 1;
            if (num == 2) {
                break;
            }
        }else if ([tPoint.pointKey isEqualToString:LEFT_EYE_LEFT]) {
            oWBorder = tPoint.point;
            num += 1;
            if (num == 2) {
                break;
            }
        }
    }
    
    *w = ffDistanceBetweenPoints(oWMiddle, oWBorder);
    *p = oWMiddle;
}

- (void)p_eyeRight:(NSDictionary *)dicPerson width:(CGFloat *)w point:(CGPoint *)p
{
    int num = 0;
    CGPoint oWBorder = CGPointZero;
    CGPoint oWMiddle = CGPointZero;
    
    for (DHTrackPoint *tPoint in [dicPerson objectForKey:POINTS_KEY]) {
        if ([tPoint.pointKey isEqualToString:RIGHT_EYE_CENTER]) {
            oWMiddle = tPoint.point;
            num += 1;
            if (num == 2) {
                break;
            }
        }else if ([tPoint.pointKey isEqualToString:RIGHT_EYE_RIGHT]) {
            oWBorder = tPoint.point;
            num += 1;
            if (num == 2) {
                break;
            }
        }
    }
    
    *w = ffDistanceBetweenPoints(oWMiddle, oWBorder);
    *p = oWMiddle;
}

- (void)p_noseLeft:(NSDictionary *)dicPerson width:(CGFloat *)w point:(CGPoint *)p
{
    int num = 0;
    CGPoint oWBorder = CGPointZero;
    CGPoint oWMiddle = CGPointZero;
    
    CGPoint noseTop = CGPointZero;
    CGPoint noseBottom = CGPointZero;
    
    for (DHTrackPoint *tPoint in [dicPerson objectForKey:POINTS_KEY]) {
        if ([tPoint.pointKey isEqualToString:NOSE_TOP]) {
            noseTop = tPoint.point;
            num += 1;
            if (num == 3) {
                break;
            }
        }else if ([tPoint.pointKey isEqualToString:NOSE_BOTTOM]) {
            noseBottom = tPoint.point;
            num += 1;
            if (num == 3) {
                break;
            }
        }else if ([tPoint.pointKey isEqualToString:NOSE_LEFT]) {
            oWMiddle = tPoint.point;
            num += 1;
            if (num == 3) {
                break;
            }
        }
    }
    
    oWBorder = ffCenterBetweenPoints(noseTop, noseBottom);
    *w = ffDistanceBetweenPoints(oWMiddle, oWBorder);
    *p = oWMiddle;
}

- (void)p_noseRight:(NSDictionary *)dicPerson width:(CGFloat *)w point:(CGPoint *)p
{
    int num = 0;
    CGPoint oWBorder = CGPointZero;
    CGPoint oWMiddle = CGPointZero;
    
    CGPoint noseTop = CGPointZero;
    CGPoint noseBottom = CGPointZero;
    
    for (DHTrackPoint *tPoint in [dicPerson objectForKey:POINTS_KEY]) {
        if ([tPoint.pointKey isEqualToString:NOSE_TOP]) {
            noseTop = tPoint.point;
            num += 1;
            if (num == 3) {
                break;
            }
        }else if ([tPoint.pointKey isEqualToString:NOSE_BOTTOM]) {
            noseBottom = tPoint.point;
            num += 1;
            if (num == 3) {
                break;
            }
        }else if ([tPoint.pointKey isEqualToString:NOSE_RIGHT]) {
            oWMiddle = tPoint.point;
            num += 1;
            if (num == 3) {
                break;
            }
        }
    }
    
    oWBorder = ffCenterBetweenPoints(noseTop, noseBottom);
    *w = ffDistanceBetweenPoints(oWMiddle, oWBorder);
    *p = oWMiddle;
}

- (void)p_mouthLeft:(NSDictionary *)dicPerson width:(CGFloat *)w point:(CGPoint *)p
{
    int num = 0;
    CGPoint oWBorder = CGPointZero;
    CGPoint oWMiddle = CGPointZero;
    
    for (DHTrackPoint *tPoint in [dicPerson objectForKey:POINTS_KEY]) {
        if ([tPoint.pointKey isEqualToString:MOUTH_LEFT]) {
            oWMiddle = tPoint.point;
            num += 1;
            if (num == 2) {
                break;
            }
        }else if ([tPoint.pointKey isEqualToString:MOUTH_MIDDLE]) {
            oWBorder = tPoint.point;
            num += 1;
            if (num == 2) {
                break;
            }
        }
    }
    
    *w = ffDistanceBetweenPoints(oWMiddle, oWBorder);
    *p = oWMiddle;
}

- (void)p_mouthRight:(NSDictionary *)dicPerson width:(CGFloat *)w point:(CGPoint *)p
{
    int num = 0;
    CGPoint oWBorder = CGPointZero;
    CGPoint oWMiddle = CGPointZero;
    
    for (DHTrackPoint *tPoint in [dicPerson objectForKey:POINTS_KEY]) {
        if ([tPoint.pointKey isEqualToString:MOUTH_RIGHT]) {
            oWMiddle = tPoint.point;
            num += 1;
            if (num == 2) {
                break;
            }
        }else if ([tPoint.pointKey isEqualToString:MOUTH_MIDDLE]) {
            oWBorder = tPoint.point;
            num += 1;
            if (num == 2) {
                break;
            }
        }
    }
    
    *w = ffDistanceBetweenPoints(oWMiddle, oWBorder);
    *p = oWMiddle;
}

@end
