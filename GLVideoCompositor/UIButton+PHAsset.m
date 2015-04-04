//
//  UIButton+PHAsset.m
//  GLVideoCompositor
//
//  Created by Mikhail Grushin on 04/04/15.
//  Copyright (c) 2015 Mikhail Grushin. All rights reserved.
//

#import "UIButton+PHAsset.h"
#import <Photos/Photos.h>

@implementation UIButton (PHAsset)

- (void)configureImageWithPHAsset:(id)asset {
    PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
    options.resizeMode = PHImageRequestOptionsResizeModeExact;
    CGSize targetSize = CGSizeMake(self.bounds.size.width * 2, self.bounds.size.height * 2);
    [[PHImageManager defaultManager] requestImageForAsset:asset
                                               targetSize:targetSize
                                              contentMode:PHImageContentModeAspectFill
                                                  options:options
                                            resultHandler:^(UIImage *result, NSDictionary *info) {
        BOOL isDegraded = [info[PHImageResultIsDegradedKey] boolValue];
        if (result && !isDegraded) {
            self.imageView.contentMode = UIViewContentModeScaleAspectFill;
            dispatch_async(dispatch_get_main_queue(), ^{
                [self setImage:result forState:UIControlStateNormal];
                [self setTitle:@"" forState:UIControlStateNormal];
                [self setNeedsLayout];
            });
        }
    }];
}

@end
