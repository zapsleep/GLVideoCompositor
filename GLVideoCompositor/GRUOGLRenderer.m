//
//  GRUOGLRenderer.m
//  GLVideoCompositor
//
//  Created by Mikhail Grushin on 04/04/15.
//  Copyright (c) 2015 Mikhail Grushin. All rights reserved.
//

#import "GRUOGLRenderer.h"

static const char kPassThroughVertexShader[] = {
    "attribute vec4 position; \n \
    attribute vec2 texCoord; \n \
    uniform mat4 renderTransform; \n \
    varying vec2 texCoordVarying; \n \
    \n \
    uniform float texelWidth;\n\
    uniform float texelHeight;\n\
    \n\
    varying highp vec2 blurCoordinates[7];\n\
    void main() \n \
    { \n \
        gl_Position = position * renderTransform; \n \
        texCoordVarying = texCoord; \n \
        highp vec2 singleStepOffset = vec2(texelWidth, texelHeight);\n \
        blurCoordinates[0] = texCoord.xy; \n \
        blurCoordinates[1] = texCoord.xy + singleStepOffset * 1.407333; \n \
        blurCoordinates[2] = texCoord.xy - singleStepOffset * 1.407333; \n \
        blurCoordinates[3] = texCoord.xy + singleStepOffset * 3.294215; \n \
        blurCoordinates[4] = texCoord.xy - singleStepOffset * 3.294215; \n \
        blurCoordinates[5] = texCoord.xy + singleStepOffset * 5.077123; \n \
        blurCoordinates[6] = texCoord.xy - singleStepOffset * 5.077123; \n \
    }"
};

static const char kPassThroughFragmentShaderY[] = {
    "varying highp vec2 texCoordVarying; \n \
    uniform sampler2D Sampler; \n \
    \n \
    varying highp vec2 blurCoordinates[7]; \n \
    void main() \n \
    { \n \
        gl_FragColor = texture2D(Sampler, texCoordVarying); \n \
//        highp vec4 sum = vec4(0.0); \n \
//        sum.rgb += texture2D(Sampler, blurCoordinates[0]).rgb * 0.204164; \n \
//        sum.rgb += texture2D(Sampler, blurCoordinates[1]).rgb * 0.304005; \n \
//        sum.rgb += texture2D(Sampler, blurCoordinates[2]).rgb * 0.304005; \n \
//        sum.rgb += texture2D(Sampler, blurCoordinates[3]).rgb * 0.093913; \n \
//        sum.rgb += texture2D(Sampler, blurCoordinates[4]).rgb * 0.093913; \n \
//        sum.rgb += texture2D(Sampler, blurCoordinates[5]).rgb * 0.003913; \n \
//        sum.rgb += texture2D(Sampler, blurCoordinates[6]).rgb * 0.003913; \n \
//        gl_FragColor.rgb = sum.rgb; \n \
    }"
};

@implementation GRUOGLRenderer

- (instancetype)init {
    if (self = [super init]) {
        _currentContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        [EAGLContext setCurrentContext:_currentContext];
        
        [self setupOffscreenRenderContext];
        [self loadShaders];
        
        [EAGLContext setCurrentContext:nil];
    }
    
    return self;
}

- (void)dealloc
{
    if (_videoTextureCache) {
        CFRelease(_videoTextureCache);
    }
    if (_offscreenBufferHandle) {
        glDeleteFramebuffers(1, &_offscreenBufferHandle);
        _offscreenBufferHandle = 0;
    }
}

#pragma mark - Public interface

- (void)renderPixelBuffer:(CVPixelBufferRef)destinationPixelBuffer usingForegroundSourceBuffer:(CVPixelBufferRef)foregroundPixelBuffer {
    [EAGLContext setCurrentContext:self.currentContext];
    
    if (foregroundPixelBuffer != NULL) {
        
        CVOpenGLESTextureRef foregroundTexture  = [self bgraTextureForPixelBuffer:foregroundPixelBuffer];
        CVOpenGLESTextureRef destTexture = [self bgraTextureForPixelBuffer:destinationPixelBuffer];
        
        glUseProgram(self.program);
        
        // Set the render transform
        GLfloat preferredRenderTransform [] = {
            self.renderTransform.a, self.renderTransform.b, self.renderTransform.tx, 0.0,
            self.renderTransform.c, self.renderTransform.d, self.renderTransform.ty, 0.0,
            0.0,					   0.0,										1.0, 0.0,
            0.0,					   0.0,										0.0, 1.0,
        };
        
        glUniformMatrix4fv(uniforms[UNIFORM_RENDER_TRANSFORM], 1, GL_FALSE, preferredRenderTransform);
        
        GLfloat size[] = {1.f/CVPixelBufferGetWidth(destinationPixelBuffer), 1.f/CVPixelBufferGetHeight(destinationPixelBuffer)};
        glUniform1f(uniforms[UNIFORM_TEXEL_WIDTH], size[0]);
        glUniform1f(uniforms[UNIFORM_TEXEL_HEIGHT], size[1]);
        
        glBindFramebuffer(GL_FRAMEBUFFER, self.offscreenBufferHandle);
        glViewport(0, 0, (int)CVPixelBufferGetWidth(destinationPixelBuffer), (int)CVPixelBufferGetHeight(destinationPixelBuffer));
        
        // Y planes of foreground and background frame are used to render the Y plane of the destination frame
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, CVOpenGLESTextureGetName(foregroundTexture));
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        // Attach the destination texture as a color attachment to the off screen frame buffer
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, CVOpenGLESTextureGetTarget(destTexture), CVOpenGLESTextureGetName(destTexture), 0);
        
        if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
            NSLog(@"Failed to make complete framebuffer object %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
            goto bail;
        }
        
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);
        
        GLfloat quadVertexData1 [] = {
            -1.0, 1.0,
            1.0, 1.0,
            -1.0, -1.0,
            1.0, -1.0,
        };
        
        // texture data varies from 0 -> 1, whereas vertex data varies from -1 -> 1
        GLfloat quadTextureData1 [] = {
            0.5 + quadVertexData1[0]/2, 0.5 + quadVertexData1[1]/2,
            0.5 + quadVertexData1[2]/2, 0.5 + quadVertexData1[3]/2,
            0.5 + quadVertexData1[4]/2, 0.5 + quadVertexData1[5]/2,
            0.5 + quadVertexData1[6]/2, 0.5 + quadVertexData1[7]/2,
        };
        
        glUniform1i(uniforms[UNIFORM], 0);
        
        glVertexAttribPointer(ATTRIB_VERTEX_Y, 2, GL_FLOAT, 0, 0, quadVertexData1);
        glEnableVertexAttribArray(ATTRIB_VERTEX_Y);
        
        glVertexAttribPointer(ATTRIB_TEXCOORD_Y, 2, GL_FLOAT, 0, 0, quadTextureData1);
        glEnableVertexAttribArray(ATTRIB_TEXCOORD_Y);
        
        // Blend function to draw the foreground frame
//        glEnable(GL_BLEND);
//        glBlendFunc(GL_ONE, GL_ZERO);
        
        // Draw the foreground frame
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
        
        glFlush();
        
    bail:
        CFRelease(foregroundTexture);
        CFRelease(destTexture);
        
        // Periodic texture cache flush every frame
        CVOpenGLESTextureCacheFlush(self.videoTextureCache, 0);
        
        [EAGLContext setCurrentContext:nil];
    }
}

- (void)setupOffscreenRenderContext
{
    //-- Create CVOpenGLESTextureCacheRef for optimal CVPixelBufferRef to GLES texture conversion.
    if (_videoTextureCache) {
        CFRelease(_videoTextureCache);
        _videoTextureCache = NULL;
    }
    CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _currentContext, NULL, &_videoTextureCache);
    if (err != noErr) {
        NSLog(@"Error at CVOpenGLESTextureCacheCreate %d", err);
    }
    
    glDisable(GL_DEPTH_TEST);
    
    glGenFramebuffers(1, &_offscreenBufferHandle);
    glBindFramebuffer(GL_FRAMEBUFFER, _offscreenBufferHandle);
}

- (CVOpenGLESTextureRef)bgraTextureForPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    CVOpenGLESTextureRef bgraTexture = NULL;
    CVReturn err;
    
    if (!_videoTextureCache) {
        NSLog(@"No video texture cache");
        goto bail;
    }
    
    CVOpenGLESTextureCacheFlush(_videoTextureCache, 0);
    
    err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                       _videoTextureCache,
                                                       pixelBuffer,
                                                       NULL,
                                                       GL_TEXTURE_2D, 
                                                       GL_RGBA,
                                                       (int)CVPixelBufferGetWidth(pixelBuffer),
                                                       (int)CVPixelBufferGetHeight(pixelBuffer),
                                                       GL_BGRA,
                                                       GL_UNSIGNED_BYTE,
                                                       0,
                                                       &bgraTexture);
    
    if (!bgraTexture || err) {
        NSLog(@"Error creating BGRA texture using CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
    }
    
bail:
    return bgraTexture;
}

- (CVOpenGLESTextureRef)lumaTextureForPixelBuffer:(CVPixelBufferRef)pixelBuffer
{
    CVOpenGLESTextureRef lumaTexture = NULL;
    CVReturn err;
    
    if (!_videoTextureCache) {
        NSLog(@"No video texture cache");
        goto bail;
    }
    
    // Periodic texture cache flush every frame
    CVOpenGLESTextureCacheFlush(_videoTextureCache, 0);
    
    // CVOpenGLTextureCacheCreateTextureFromImage will create GL texture optimally from CVPixelBufferRef.
    // Y
    err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                       _videoTextureCache,
                                                       pixelBuffer,
                                                       NULL,
                                                       GL_TEXTURE_2D,
                                                       GL_RED_EXT,
                                                       (int)CVPixelBufferGetWidth(pixelBuffer),
                                                       (int)CVPixelBufferGetHeight(pixelBuffer),
                                                       GL_RED_EXT,
                                                       GL_UNSIGNED_BYTE,
                                                       0,
                                                       &lumaTexture);
    
    if (!lumaTexture || err) {
        NSLog(@"Error at creating luma texture using CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
    }
    
bail:
    return lumaTexture;
}

- (CVOpenGLESTextureRef)chromaTextureForPixelBuffer:(CVPixelBufferRef)pixelBuffer
{
    CVOpenGLESTextureRef chromaTexture = NULL;
    CVReturn err;
    
    if (!_videoTextureCache) {
        NSLog(@"No video texture cache");
        goto bail;
    }
    
    // Periodic texture cache flush every frame
    CVOpenGLESTextureCacheFlush(_videoTextureCache, 0);
    
    // CVOpenGLTextureCacheCreateTextureFromImage will create GL texture optimally from CVPixelBufferRef.
    // UV
    err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                       _videoTextureCache,
                                                       pixelBuffer,
                                                       NULL,
                                                       GL_TEXTURE_2D,
                                                       GL_RG_EXT,
                                                       (int)CVPixelBufferGetWidthOfPlane(pixelBuffer, 1),
                                                       (int)CVPixelBufferGetHeightOfPlane(pixelBuffer, 1),
                                                       GL_RG_EXT,
                                                       GL_UNSIGNED_BYTE,
                                                       1,
                                                       &chromaTexture);
    
    if (!chromaTexture || err) {
        NSLog(@"Error at creating chroma texture using CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
    }
    
bail:
    return chromaTexture;
}

#pragma mark -  OpenGL ES 2 shader compilation

- (BOOL)loadShaders
{
    GLuint vertShader, fragShader;
    NSString *vertShaderSource, *fragShaderSource;
    
    // Create the shader program.
    _program = glCreateProgram();
    
    // Create and compile the vertex shader.
    vertShaderSource = [NSString stringWithCString:kPassThroughVertexShader encoding:NSUTF8StringEncoding];
    if (![self compileShader:&vertShader type:GL_VERTEX_SHADER source:vertShaderSource]) {
        NSLog(@"Failed to compile vertex shader");
        return NO;
    }
    
    // Create and compile Y fragment shader.
    fragShaderSource = [NSString stringWithCString:kPassThroughFragmentShaderY encoding:NSUTF8StringEncoding];
    if (![self compileShader:&fragShader type:GL_FRAGMENT_SHADER source:fragShaderSource]) {
        NSLog(@"Failed to compile Y fragment shader");
        return NO;
    }
    
    // Attach vertex shader to programY.
    glAttachShader(_program, vertShader);
    
    // Attach fragment shader to programY.
    glAttachShader(_program, fragShader);
    
    
    // Bind attribute locations. This needs to be done prior to linking.
    
    glBindAttribLocation(_program, ATTRIB_VERTEX_Y, "position");
    glBindAttribLocation(_program, ATTRIB_TEXCOORD_Y, "texCoord");
    
    // Link the program.
    if (![self linkProgram:_program]) {
        NSLog(@"Failed to link program: %d", _program);
        
        if (vertShader) {
            glDeleteShader(vertShader);
            vertShader = 0;
        }
        if (fragShader) {
            glDeleteShader(fragShader);
            fragShader = 0;
        }
        if (_program) {
            glDeleteProgram(_program);
            _program = 0;
        }
        
        return NO;
    }
    
    // Get uniform locations.
    uniforms[UNIFORM] = glGetUniformLocation(_program, "Sampler");
    uniforms[UNIFORM_RENDER_TRANSFORM] = glGetUniformLocation(_program, "renderTransform");
    
    // Release vertex and fragment shaders.
    if (vertShader) {
        glDetachShader(_program, vertShader);
        glDeleteShader(vertShader);
    }
    if (fragShader) {
        glDetachShader(_program, fragShader);
        glDeleteShader(fragShader);
    }
    
    return YES;
}

- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type source:(NSString *)sourceString
{
    if (sourceString == nil) {
        NSLog(@"Failed to load vertex shader: Empty source string");
        return NO;
    }
    
    GLint status;
    const GLchar *source;
    source = (GLchar *)[sourceString UTF8String];
    
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &source, NULL);
    glCompileShader(*shader);
    
    GLint logLength;
    glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(*shader, logLength, &logLength, log);
        NSLog(@"Shader compile log:\n%s", log);
        free(log);
    }
    
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    if (status == 0) {
        glDeleteShader(*shader);
        return NO;
    }
    
    return YES;
}

- (BOOL)linkProgram:(GLuint)prog
{
    GLint status;
    glLinkProgram(prog);
    
    GLint logLength;
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program link log:\n%s", log);
        free(log);
    }
    
    glGetProgramiv(prog, GL_LINK_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}

- (BOOL)validateProgram:(GLuint)prog
{
    GLint logLength, status;
    
    glValidateProgram(prog);
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program validate log:\n%s", log);
        free(log);
    }
    
    glGetProgramiv(prog, GL_VALIDATE_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}

@end
