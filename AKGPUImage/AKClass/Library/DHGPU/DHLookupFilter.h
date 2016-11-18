//
//  DHLookupFilter.h
//  DHOCChat
//
//  Created by AKing on 16/7/19.
//  Copyright © 2016年 AKing. All rights reserved.
//

#import <GPUImage/GPUImage.h>

@interface DHLookupFilter : GPUImageFilterGroup
{
    GPUImagePicture *lookupImageSource;
}

- (id)initWithLUTImgName:(NSString *)imgName;

- (void)process;

@end
