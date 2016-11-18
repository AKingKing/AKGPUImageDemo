//
//  DHUIElementFilter.m
//  DHOCChat
//
//  Created by AKing on 16/7/19.
//  Copyright © 2016年 AKing. All rights reserved.
//

#import "DHUIElementFilter.h"
#import "DHTrackFaceProgress.h"
#import "DHAnimationModel2.h"


@implementation DHUIElementFilter

- (id)init
{
    self = [super init];
    if (self) {
        
    }
    
    return self;
}


- (void)calculateArrPersons:(NSArray *)arrPersons frontFacingCamera:(BOOL)front
{
    
    [DHTrackFaceProgress calculateFace:self
                            arrPersons:arrPersons
                     frontFacingCamera:front];
    
    //    if (arrPersons.count > 0) {
    //
    //        //只做第一个的人脸处理,,
    //        NSDictionary *dicPerson = arrPersons.firstObject;
    //        if ([dicPerson objectForKey:POINTS_KEY]) {
    //
    //            //恢复参照,,
    //            self.uiImageView.layer.anchorPoint = CGPointMake(0.5f, 0.5f);
    //            self.uiImageView.transform = CGAffineTransformIdentity;
    //
    //            CGPoint cPoint = CGPointZero;
    //            CGFloat imgWidth = 0;
    //            CGFloat imgHeight = 0;
    //            CGFloat imgRadian = 0;
    //
    //            [DHTrackFaceProgress calculateFace:self.face
    //                                        points:dicPerson
    //                             frontFacingCamera:front
    //                                        multiple:self.multiple
    //                                       imgSize:self.imgSize
    //                                        offset:self.offset
    //                                        center:&cPoint
    //                                         width:&imgWidth
    //                                        height:&imgHeight
    //                                        radian:&imgRadian];
    //
    //
    //            if ([self.face isEqualToString:DHFacePositionBottomCenter]){
    //
    //                self.uiImageView.frame = RECT((DHShowVideoWidth - imgWidth) / 2, 0, imgWidth, imgHeight);
    //                self.uiImageView.bottom = DHShowVideoHeight;
    //
    //            }else {
    //
    //                self.uiImageView.bounds = RECT(0, 0, imgWidth, imgHeight);
    //                self.uiImageView.center = cPoint;
    //                [self.uiImageView dh_setAnchorPoint:self.anchor forView:self.uiImageView];
    //                self.uiImageView.transform = CGAffineTransformRotate(CGAffineTransformIdentity, -imgRadian);
    //            }
    //            
    //            
    //        }
    //    }
}





































@end
