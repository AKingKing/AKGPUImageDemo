//
//  UIImage+UIImageReadWithSN.m
//  AVTest
//
//  Created by 张伟凯 on 14-5-17.
//  Copyright (c) 2014年 张伟凯. All rights reserved.
//

#import "UIImage+UIImageReadWithSN.h"

#define SN @"Kabc*123."//密码//使用的时候要改成自己的密码


@implementation UIImage (UIImageReadWithSN)
/**
 *  从加密图片获取图片
 *
 *  @param imageName 图片名字
 *
 *  @return 图片
 */
+(UIImage*)imageInSnWithName:(NSString*)imageName{
    //获取加密文件路径
    NSString *imDataStr = [[NSBundle mainBundle] pathForResource:imageName ofType:nil];
    //加密文件转成NSData
    NSData *imageData = [NSData dataWithContentsOfFile: imDataStr ];
    if (!imageData) {
        return nil;
    }
    //密码文件
    NSData *sn = [SN dataUsingEncoding:NSUTF8StringEncoding];
    
    NSUInteger pre = sn.length;
    NSUInteger total = imageData.length;
    NSRange range = {pre , total-pre};
    //除去加密文件
    NSData *imData = [imageData subdataWithRange:range];
    //生成可使用的图片资源
    UIImage *image = [UIImage imageWithData:imData];
    
    return image;
}
@end
