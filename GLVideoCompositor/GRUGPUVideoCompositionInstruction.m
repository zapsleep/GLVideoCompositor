//
//  GRUGPUVideoCompositionInstruction.m
//  GLVideoCompositor
//
//  Created by Mikhail Grushin on 04/04/15.
//  Copyright (c) 2015 Mikhail Grushin. All rights reserved.
//

#import "GRUGPUVideoCompositionInstruction.h"

@implementation GRUGPUVideoCompositionInstruction

@synthesize timeRange = _timeRange;
@synthesize enablePostProcessing = _enablePostProcessing;
@synthesize containsTweening = _containsTweening;
@synthesize requiredSourceTrackIDs = _requiredSourceTrackIDs;
@synthesize passthroughTrackID = _passthroughTrackID;
@synthesize foregroundTrackID = _foregroundTrackID;

- (id)initForegroundTrackID:(CMPersistentTrackID)passthroughTrackID forTimeRange:(CMTimeRange)timeRange withTransform:(CGAffineTransform)transform {
    if (self = [super init]) {
        _foregroundTrackID = passthroughTrackID;
        _requiredSourceTrackIDs = nil;
        _timeRange = timeRange;
        _containsTweening = NO;
        _enablePostProcessing = NO;
        _transform = transform;
    }
    
    return self;
}

@end
