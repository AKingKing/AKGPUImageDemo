//
//  DHLookupFilter.m
//  DHOCChat
//
//  Created by AKing on 16/7/19.
//  Copyright © 2016年 AKing. All rights reserved.
//

#import "DHLookupFilter.h"
#import "UIImage+UIImageReadWithSN.h"

@implementation DHLookupFilter

- (id)initWithLUTImgName:(NSString *)imgName
{
    if (!(self = [super init]))
    {
        return nil;
    }
    

    UIImage *image = [UIImage imageInSnWithName:imgName];
    if (!image) {
        image = [UIImage imageInSnWithName:@"A3.data"];
    }
    
    NSAssert(image, @"To use GPUImageAmatorkaFilter you need to add lookup_amatorka.png from GPUImage/framework/Resources to your application bundle.");
    
    lookupImageSource = [[GPUImagePicture alloc] initWithImage:image];
    GPUImageLookupFilter *lookupFilter = [[GPUImageLookupFilter alloc] init];
    [self addFilter:lookupFilter];
    
    [lookupImageSource addTarget:lookupFilter atTextureLocation:1];
    [lookupImageSource processImage];
    
    self.initialFilters = [NSArray arrayWithObjects:lookupFilter, nil];
    self.terminalFilter = lookupFilter;
    
    return self;
}


- (void)process
{
    if (lookupImageSource) {
        [lookupImageSource processImage];
    }
}

@end
