//
//  AVAssetTrack+Transform.h
//  GLVideoCompositor
//
//  Created by Mikhail Grushin on 04/04/15.
//  Copyright (c) 2015 Mikhail Grushin. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>

@interface AVAssetTrack (Transform)

- (CGAffineTransform)properTransformForRenderSize:(CGSize)renderSize;

@end
