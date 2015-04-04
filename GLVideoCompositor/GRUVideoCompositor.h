//
//  GRUVideoCompositor.h
//  GLVideoCompositor
//
//  Created by Mikhail Grushin on 04/04/15.
//  Copyright (c) 2015 Mikhail Grushin. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AVPlayerItem, AVAudioMix, AVVideoComposition;

@interface GRUVideoCompositor : NSObject

@property (nonatomic, strong, readonly) AVPlayerItem *composedPlayerItem;
@property (nonatomic, strong, readonly) AVAudioMix *composedAudioMix;
@property (nonatomic, strong, readonly) AVVideoComposition *composedVideoComposition;
@property (nonatomic, strong, readonly) NSString *errorMessage;

- (AVPlayerItem *)compileCompositionWithAssets:(NSArray *)assetsArray;

@end
