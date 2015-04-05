//
//  GRUGPUVideoCompositionInstruction.h
//  GLVideoCompositor
//
//  Created by Mikhail Grushin on 04/04/15.
//  Copyright (c) 2015 Mikhail Grushin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface GRUGPUVideoCompositionInstruction : NSObject<AVVideoCompositionInstruction>

@property CMPersistentTrackID foregroundTrackID;
@property CMPersistentTrackID backgroundTrackID;
@property CGAffineTransform transform;

- (id)initForegroundTrackID:(CMPersistentTrackID)passthroughTrackID forTimeRange:(CMTimeRange)timeRange withTransform:(CGAffineTransform)transform;

@end
