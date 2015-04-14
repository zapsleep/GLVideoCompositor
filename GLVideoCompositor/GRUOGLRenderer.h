//
//  GRUOGLRenderer.h
//  GLVideoCompositor
//
//  Created by Mikhail Grushin on 04/04/15.
//  Copyright (c) 2015 Mikhail Grushin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GLKit/GLKit.h>
#import <OpenGLES/ES2/glext.h>
#import <CoreVideo/CoreVideo.h>

enum
{
    UNIFORM,
    UNIFORM_RENDER_TRANSFORM,
    UNIFORM_TEXEL_WIDTH,
    UNIFORM_TEXEL_HEIGHT,
   	NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];

enum
{
    ATTRIB_VERTEX_Y,
    ATTRIB_TEXCOORD_Y,
   	NUM_ATTRIBUTES
};

@interface GRUOGLRenderer : NSObject

@property GLuint program;
@property (nonatomic, assign) CGAffineTransform renderTransform;
@property (nonatomic, assign) CVOpenGLESTextureCacheRef videoTextureCache;
@property (nonatomic, strong) EAGLContext *currentContext;
@property (nonatomic, assign) GLuint offscreenBufferHandle;

- (void)renderPixelBuffer:(CVPixelBufferRef)destinationPixelBuffer usingForegroundSourceBuffer:(CVPixelBufferRef)foregroundPixelBuffer;

@end
