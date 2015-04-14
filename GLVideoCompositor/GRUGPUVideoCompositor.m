//
//  GRUGPUVideoCompositor.m
//  GLVideoCompositor
//
//  Created by Mikhail Grushin on 04/04/15.
//  Copyright (c) 2015 Mikhail Grushin. All rights reserved.
//

#import "GRUGPUVideoCompositor.h"
#import <CoreVideo/CoreVideo.h>

#import "GRUOGLRenderer.h"
#import "GRUGPUVideoCompositionInstruction.h"

@interface GRUGPUVideoCompositor()
@property (nonatomic, strong) dispatch_queue_t renderingQueue;
@property (nonatomic, strong) dispatch_queue_t renderContextQueue;
@property (nonatomic, strong) AVVideoCompositionRenderContext *renderContext;
@property (nonatomic, assign) CVPixelBufferRef previousBuffer;
@property (nonatomic, strong) GRUOGLRenderer *oglRenderer;
@property (nonatomic, strong) GRUGPUVideoCompositionInstruction *currentInstruction;

@property (nonatomic, assign) BOOL shouldCancelAllRequests;
@property (nonatomic, assign) BOOL renderContextDidChange;

@end

@implementation GRUGPUVideoCompositor

- (instancetype)init {
    self = [super init];
    if (self)
    {
        _renderingQueue = dispatch_queue_create("me.mihailgrushin.gpuvideocompositor.renderingqueue", DISPATCH_QUEUE_SERIAL);
        _renderContextQueue = dispatch_queue_create("me.mihailgrushin.gpuvideocompositor.rendercontextqueue", DISPATCH_QUEUE_SERIAL);
        _previousBuffer = nil;
        _renderContextDidChange = NO;
        _oglRenderer = [[GRUOGLRenderer alloc] init];
    }
    return self;
}

- (void)dealloc {
    
}

- (void)startVideoCompositionRequest:(AVAsynchronousVideoCompositionRequest *)asyncVideoCompositionRequest {
    @autoreleasepool {
        dispatch_async(_renderingQueue,^() {
            
            // Check if all pending requests have been cancelled
            if (_shouldCancelAllRequests) {
                [asyncVideoCompositionRequest finishCancelledRequest];
            } else {
                NSError *err = nil;
                // Get the next rendererd pixel buffer
                CVPixelBufferRef resultPixels = [self newRenderedPixelBufferForRequest:asyncVideoCompositionRequest error:&err];
                
                if (resultPixels) {
                    // The resulting pixelbuffer from OpenGL renderer is passed along to the request
                    [asyncVideoCompositionRequest finishWithComposedVideoFrame:resultPixels];
                    CFRelease(resultPixels);
                } else {
                    [asyncVideoCompositionRequest finishWithError:err];
                }
            }
        });
    }
}

- (void)renderContextChanged:(AVVideoCompositionRenderContext *)newRenderContext {
    dispatch_sync(_renderContextQueue, ^() {
        _renderContext = newRenderContext;
        _renderContextDidChange = YES;
    });
}

- (NSDictionary *)sourcePixelBufferAttributes
{
    return @{ (NSString *)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA],
              (NSString*)kCVPixelBufferOpenGLESCompatibilityKey : [NSNumber numberWithBool:YES]};
}

- (NSDictionary *)requiredPixelBufferAttributesForRenderContext
{
    return @{ (NSString *)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA],
              (NSString*)kCVPixelBufferOpenGLESCompatibilityKey : [NSNumber numberWithBool:YES]};
}

- (void)cancelAllPendingVideoCompositionRequests
{
    // pending requests will call finishCancelledRequest, those already rendering will call finishWithComposedVideoFrame
    _shouldCancelAllRequests = YES;
    
    dispatch_barrier_async(_renderingQueue, ^() {
        // start accepting requests again
        _shouldCancelAllRequests = NO;
    });
}

- (CVPixelBufferRef)newRenderedPixelBufferForRequest:(AVAsynchronousVideoCompositionRequest *)request error:(NSError **)error {
    CVPixelBufferRef dstPixelBuffer = nil;
    
    if (_renderContextDidChange || self.currentInstruction != request.videoCompositionInstruction) {
        self.currentInstruction = request.videoCompositionInstruction;
        _oglRenderer.renderTransform = self.currentInstruction.transform;
        
        _renderContextDidChange = NO;
    }
    
    // Source pixel buffers are used as inputs while rendering the transition
    CVPixelBufferRef foregroundSourceBuffer = [request sourceFrameByTrackID:self.currentInstruction.foregroundTrackID];
    
    // Destination pixel buffer into which we render the output
    dstPixelBuffer = [_renderContext newPixelBuffer];
    
    // Recompute normalized render transform everytime the render context changes
    
    [_oglRenderer renderPixelBuffer:dstPixelBuffer usingForegroundSourceBuffer:foregroundSourceBuffer];
    
    return dstPixelBuffer;
}

@end
