//
//  GRUVideoCompositor.m
//  GLVideoCompositor
//
//  Created by Mikhail Grushin on 04/04/15.
//  Copyright (c) 2015 Mikhail Grushin. All rights reserved.
//

#import "GRUVideoCompositor.h"
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

#import "AVAssetTrack+Transform.h"

@interface GRUVideoCompositor()

@property (nonatomic, strong) NSMutableArray *loadedAssets;

@property (nonatomic, strong) AVPlayerItem *playerItem;
@property (nonatomic, strong) AVMutableAudioMix *audioMix;
@property (nonatomic, strong) AVMutableVideoComposition *videoComposition;
@property (nonatomic, strong) AVMutableComposition *composition;
@property (nonatomic) CGSize *naturalSizes;

@property (nonatomic, strong) AVMutableCompositionTrack *primaryCompositionVideoTrack;
@property (nonatomic, strong) AVMutableCompositionTrack *secondaryCompositionVideoTrack;
@property (nonatomic, strong) AVMutableCompositionTrack *primaryCompositionAudioTrack;
@property (nonatomic, strong) AVMutableCompositionTrack *secondaryCompositionAudioTrack;

@end

@implementation GRUVideoCompositor

- (void)dealloc {
    _errorMessage = nil;
}

#pragma mark - Public interface

- (AVPlayerItem *)compileCompositionWithAssets:(NSArray *)assetsArray {
    _errorMessage = @"";
    if (!assetsArray.count) {
        _errorMessage = @"Assets array shouldn't be empty";
        return nil;
    }
    
    self.composition = [AVMutableComposition composition];
    self.loadedAssets = @[].mutableCopy;
    self.naturalSizes = malloc(assetsArray.count * sizeof(CGSize));
    
    if (![self prepareCompositionTracksWithAssets:assetsArray]) {
        _errorMessage = [@"Failed to prepare composition tracks: " stringByAppendingString:_errorMessage];
        return nil;
    }
    
    //prepare audio mix
    
    self.videoComposition = [self prepareVideoComposition];
    if (!self.videoComposition) {
        _errorMessage = [@"Failed to prepare video composition: " stringByAppendingString:_errorMessage];
        return nil;
    }
    
    self.playerItem = [AVPlayerItem playerItemWithAsset:self.composition];
    self.playerItem.videoComposition = self.videoComposition;
    if (self.audioMix.inputParameters.count) {
        self.playerItem.audioMix = self.audioMix;
    }
    if ([self.playerItem respondsToSelector:@selector(setSeekingWaitsForVideoCompositionRendering:)]) {
        self.playerItem.seekingWaitsForVideoCompositionRendering = YES;
    }
    
    self.playerItem.audioTimePitchAlgorithm = AVAudioTimePitchAlgorithmVarispeed;
    
    free(self.naturalSizes);
    
    return self.playerItem;
}

#pragma mark - Private interface

- (BOOL)prepareCompositionTracksWithAssets:(NSArray *)assets {
    return [self prepareVideoTracksWithAssets:assets] & [self prepareAudioTracks];
}

- (BOOL)prepareVideoTracksWithAssets:(NSArray *)assetsArray {
    self.primaryCompositionVideoTrack = [self.composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    
    void(^errorBlock)(NSString *) = ^(NSString *errorMsg) {
        _errorMessage = [errorMsg copy];
    };
    
    CMTime insertionTime = kCMTimeZero;
    for (AVAsset *asset in assetsArray) {
        NSUInteger idx = [assetsArray indexOfObject:asset];
        
        if ([asset tracksWithMediaType:AVMediaTypeVideo].count) {
            AVAssetTrack *videoTrack = [asset tracksWithMediaType:AVMediaTypeVideo][0];
            CMTimeRange trackTimeRange = CMTimeRangeMake(kCMTimeZero, videoTrack.timeRange.duration);
            
            NSError *error;
            [self.primaryCompositionVideoTrack insertTimeRange:trackTimeRange ofTrack:videoTrack atTime:insertionTime error:&error];
            if (error) {
                errorBlock([error description]);
                return NO;
            }
            
            CGSize naturalSize = videoTrack.naturalSize;
            CGAffineTransform preferredTransform = videoTrack.preferredTransform;
            if (preferredTransform.a == 0.f && preferredTransform.d == 0.f &&
                (preferredTransform.b == 1.f || preferredTransform.b == -1.f) &&
                (preferredTransform.c == 1.f || preferredTransform.c == -1.f)) {
                
                naturalSize = CGSizeMake(naturalSize.height, naturalSize.width);
            }
            self.naturalSizes[self.loadedAssets.count] = naturalSize;
            
            [self.loadedAssets addObject:asset];
            insertionTime = CMTimeAdd(insertionTime, trackTimeRange.duration);
        } else {
            NSString *msg = [NSString stringWithFormat:@"no video track in asset at index %lu", (unsigned long)idx];
            errorBlock(msg);
            return NO;
        }
    }
    
    NSMutableArray *sizeValues = @[].mutableCopy;
    for (int i = 0; i < self.loadedAssets.count; ++i) {
        CGSize size = self.naturalSizes[i];
        NSValue *value = [NSValue valueWithCGSize:size];
        [sizeValues addObject:value];
    }
    
    self.composition.naturalSize = [self renderSizeWithArrayOfVideoDimensions:sizeValues];
    
    return YES;
}

- (BOOL)prepareAudioTracks {
//    self.primaryCompositionAudioTrack = [self.composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    
    
    
    return YES;
}

- (AVMutableVideoComposition *)prepareVideoComposition {
    AVMutableVideoComposition *videoComposition = [AVMutableVideoComposition videoComposition];
    CGSize renderSize = self.composition.naturalSize;
    
    CMTime insertionTime = kCMTimeZero;
    NSMutableArray *instructions = @[].mutableCopy;
    for (AVAsset *asset in self.loadedAssets) {
        AVAssetTrack *videoTrack = [asset tracksWithMediaType:AVMediaTypeVideo][0];
        AVMutableVideoCompositionInstruction *instruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
        
        CMTimeRange timeRange = CMTimeRangeMake(insertionTime, videoTrack.timeRange.duration);
        instruction.timeRange = timeRange;
        
        AVMutableVideoCompositionLayerInstruction *layerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:self.primaryCompositionVideoTrack];
        [layerInstruction setTransform:[videoTrack properTransformForRenderSize:renderSize] atTime:insertionTime];
        instruction.layerInstructions = @[layerInstruction];
        
        [instructions addObject:instruction];
        insertionTime = CMTimeAdd(insertionTime, videoTrack.timeRange.duration);
    }
    
    if (instructions.count) {
        videoComposition.instructions = instructions;
    }
    videoComposition.renderSize = self.composition.naturalSize;
    videoComposition.frameDuration = CMTimeMake(1, 30);
    
    return videoComposition;
}

- (CGSize)renderSizeWithArrayOfVideoDimensions:(NSArray *)videoDimensions {
    CGSize maxPortrait = CGSizeZero;
    CGSize maxLandscape = CGSizeZero;
    NSUInteger count = videoDimensions.count;
    
    for (int i = 0; i < count; ++i) {
        NSValue *naturalSizeValue = videoDimensions[i];
        CGSize naturalSize = [naturalSizeValue CGSizeValue];
        if (naturalSize.width < naturalSize.height) { //portrait
            if (maxPortrait.width < naturalSize.width)
                maxPortrait.width = naturalSize.width;
            if (maxPortrait.height < naturalSize.height)
                maxPortrait.height = naturalSize.height;
        } else { //landscape
            if (maxLandscape.width < naturalSize.width)
                maxLandscape.width = naturalSize.width;
            if (maxLandscape.height < naturalSize.height)
                maxLandscape.height = naturalSize.height;
        }
    }
    
    
    CGFloat playerViewAspect;
    CGSize screenSize = [[UIScreen mainScreen] bounds].size;
    if (screenSize.height < screenSize.width) {
        playerViewAspect = screenSize.height/screenSize.width;
    } else {
        playerViewAspect = screenSize.width/screenSize.height;
    }
    
    if (maxLandscape.height/maxLandscape.width < playerViewAspect) {
        maxLandscape.height = maxLandscape.width*playerViewAspect;
    } else {
        maxLandscape.width = maxLandscape.height/playerViewAspect;
    }
    
    return (CGSizeEqualToSize(maxLandscape, CGSizeZero))?maxPortrait:maxLandscape;
}

#pragma mark - Accessors

- (AVPlayerItem *)composedPlayerItem {
    return _playerItem;
}

- (AVAudioMix *)composedAudioMix {
    return _audioMix;
}

- (AVVideoComposition *)composedVideoComposition {
    return _videoComposition;
}

@end
