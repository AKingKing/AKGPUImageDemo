//
//  DHUIElementOverlayFilter.m
//  DHOCChat
//
//  Created by AKing on 16/10/27.
//  Copyright © 2016年 AKing. All rights reserved.
//

#import "DHUIElementOverlayFilter.h"
#import "DHAnimationModel2.h"
#import "DHTrackFaceProgress.h"



@implementation DHUIElementOverlayFilter

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
}


@end
