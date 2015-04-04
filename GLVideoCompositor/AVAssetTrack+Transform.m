//
//  AVAssetTrack+Transform.m
//  GLVideoCompositor
//
//  Created by Mikhail Grushin on 04/04/15.
//  Copyright (c) 2015 Mikhail Grushin. All rights reserved.
//

#import "AVAssetTrack+Transform.h"

@implementation AVAssetTrack (Transform)

- (CGAffineTransform)properTransformForRenderSize:(CGSize)renderSize {
    CGAffineTransform preferredTransform = self.preferredTransform;
    CGSize naturalSize = [self properNaturalSize];
    
    CGFloat widthRatio = renderSize.width/naturalSize.width;
    CGFloat heightRatio = renderSize.height/naturalSize.height;
    CGFloat scale = 1.f;
    if (widthRatio != 1.f || heightRatio != 1.f) {
        if (widthRatio >= heightRatio)
            scale = heightRatio;
        else
            scale = widthRatio;
    }
    
    CGAffineTransform scaleTransform = CGAffineTransformConcat(preferredTransform, CGAffineTransformMakeScale(scale, scale));
    CGFloat tx = renderSize.width/2.f - naturalSize.width*scale/2.f;
    CGFloat ty = renderSize.height/2.f - naturalSize.height*scale/2.f;
    CGAffineTransform transitionTransform = CGAffineTransformConcat(scaleTransform, CGAffineTransformMakeTranslation(tx, ty));
    
    return transitionTransform;
}

- (CGSize)properNaturalSize {
    if (self.naturalSize.width >= self.naturalSize.height) {
        return self.naturalSize;
    } else {
        return CGSizeMake(self.naturalSize.height, self.naturalSize.width);
    }
}

@end
