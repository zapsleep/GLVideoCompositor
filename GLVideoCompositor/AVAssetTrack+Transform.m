//
//  AVAssetTrack+Transform.m
//  GLVideoCompositor
//
//  Created by Mikhail Grushin on 04/04/15.
//  Copyright (c) 2015 Mikhail Grushin. All rights reserved.
//

#import "AVAssetTrack+Transform.h"

#define isPortrait(X) (X==AVAssetTrackOrientationLeft || X==AVAssetTrackOrientationRight)

typedef NS_ENUM(NSUInteger, AVAssetTrackOrientation) {
    AVAssetTrackOrientationFree,
    AVAssetTrackOrientationUp,
    AVAssetTrackOrientationRight,
    AVAssetTrackOrientationLeft,
    AVAssetTrackOrientationDown
};

@implementation AVAssetTrack (Transform)

- (CGAffineTransform)properTransformForRenderSize:(CGSize)renderSize {
    AVAssetTrackOrientation orientation = [self orientation];
    if (orientation == AVAssetTrackOrientationFree) {
        return CGAffineTransformMake(1, 0, 0, 1, 0, 0);
    }
    
    CGSize naturalSize = CGSizeZero;
    if (isPortrait(orientation)) {
        naturalSize = CGSizeMake(self.naturalSize.height, self.naturalSize.width);
    } else {
        naturalSize = self.naturalSize;
    }
    
    CGFloat renderRatio = renderSize.width/renderSize.height;
    CGFloat naturalRatio = naturalSize.width/naturalSize.height;
    
    if (renderRatio == naturalRatio) {
        if (orientation == AVAssetTrackOrientationLeft) {
            return CGAffineTransformMake(0, -1, 1, 0, 0, 0);
        } else if (orientation == AVAssetTrackOrientationRight) {
            return CGAffineTransformMake(0, 1, -1, 0, 0, 0);
        } else if (orientation == AVAssetTrackOrientationDown) {
            return CGAffineTransformMake(-1, 0, 0, -1, 0, 0);
        } else if (orientation == AVAssetTrackOrientationUp) {
            return CGAffineTransformMake(1, 0, 0, 1, 0, 0);
        }
    } else {
        CGFloat widthRatio = naturalSize.width/renderSize.width;
        CGFloat heightRatio = naturalSize.height/renderSize.height;
        
        if (widthRatio > heightRatio) {
            CGFloat newHeight = renderSize.width/naturalRatio;
            CGFloat component = newHeight/renderSize.height;
            if (orientation == AVAssetTrackOrientationLeft) {
                return CGAffineTransformMake(0, -1, component, 0, 0, 0);
            } else if (orientation == AVAssetTrackOrientationRight) {
                return CGAffineTransformMake(0, 1, -component, 0, 0, 0);
            } else if (orientation == AVAssetTrackOrientationDown) {
                return CGAffineTransformMake(-1, 0, 0, -component, 0, 0);
            } else if (orientation == AVAssetTrackOrientationUp) {
                return CGAffineTransformMake(1, 0, 0, component, 0, 0);
            }
        } else {
            CGFloat newWidth = naturalRatio*renderSize.height;
            CGFloat component = newWidth/renderSize.width;
            if (orientation == AVAssetTrackOrientationLeft) {
                return CGAffineTransformMake(0, -component, 1, 0, 0, 0);
            } else if (orientation == AVAssetTrackOrientationRight) {
                return CGAffineTransformMake(0, 1, -component, 0, 0, 0);
            } else if (orientation == AVAssetTrackOrientationDown) {
                return CGAffineTransformMake(-1, 0, 0, -component, 0, 0);
            } else if (orientation == AVAssetTrackOrientationUp) {
                return CGAffineTransformMake(1, 0, 0, component, 0, 0);
            }
        }
    }
    
    return CGAffineTransformMake(1, 0, 0, 1, 0, 0);
}

- (AVAssetTrackOrientation)orientation {
    if (self.preferredTransform.a > 0.f && self.preferredTransform.d > 0.f) {
        return AVAssetTrackOrientationUp;
    } else if (self.preferredTransform.a < 0.f && self.preferredTransform.d < 0.f) {
        return AVAssetTrackOrientationDown;
    } else if (self.preferredTransform.a == 0.f && self.preferredTransform.d == 0.f &&
               (self.preferredTransform.b == 1.f || self.preferredTransform.c == -1.f)) {
        return AVAssetTrackOrientationLeft;
    } else if (self.preferredTransform.a == 0.f && self.preferredTransform.d == 0.f &&
               (self.preferredTransform.b == -1.f || self.preferredTransform.c == 1.f)) {
        return AVAssetTrackOrientationRight;
    } else {
        return AVAssetTrackOrientationFree;
    }
}

@end
