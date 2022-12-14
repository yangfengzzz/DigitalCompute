//  Copyright (c) 2022 Feng Yang
//
//  I am making my contributions/submissions to this project solely in my
//  personal capacity and am not conveying any rights to any intellectual
//  property of any third parties.

#include "engine.h"
#include "image.h"
#include "logging.h"
#include "vox.shader/common.h"
#import <Foundation/NSBundle.h>

namespace vox {
Engine::Engine() {
    NSError *error = NULL;
    
    _device = MTLCreateSystemDefaultDevice();
    
    // Load all the shader files with a .metal file extension in the project.
    id <MTLLibrary> defaultLibrary = [_device newLibraryWithURL:[NSBundle.mainBundle
                                                                 URLForResource:@"vox.shader"
                                                                 withExtension:@"metallib"]
                                                          error:&error];
    // Load the image processing function from the library and create a pipeline from it.
    id <MTLFunction> kernelFunction = [defaultLibrary newFunctionWithName:@"grayscaleKernel"];
    _computePipelineState = [_device newComputePipelineStateWithFunction:kernelFunction
                                                                   error:&error];
    
    // Compute pipeline state creation could fail if kernelFunction failed to load from
    // the library. If the Metal API validation is enabled, you automatically get more
    // information about what went wrong. (Metal API validation is enabled by default
    // when you run a debug build from Xcode.)
    if (_computePipelineState) {
        LOGI("Failed to create compute pipeline state: {}", [error.description cStringUsingEncoding:NSUTF8StringEncoding])
    }
    
    // Load the vertex and fragment functions, and use them to configure a render
    // pipeline.
    id <MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"vertexShader"];
    id <MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"samplingShader"];
    
    MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineStateDescriptor.label = @"Simple Render Pipeline";
    pipelineStateDescriptor.vertexFunction = vertexFunction;
    pipelineStateDescriptor.fragmentFunction = fragmentFunction;
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = colorPixelFormat();
    
    _renderPipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor
                                                                   error:&error];
    if (_renderPipelineState) {
        LOGI("Failed to create render pipeline state: {}", [error.description cStringUsingEncoding:NSUTF8StringEncoding])
    }
    
    NSURL *imageFileLocation = [[NSBundle bundleWithPath:@"vox.compute"] URLForResource:@"Image"
                                                       withExtension:@"tga"];
    
    AAPLImage *image = [[AAPLImage alloc] initWithTGAFileAtLocation:imageFileLocation];
    
    if (!image) {
        return;
    }
    
    MTLTextureDescriptor *textureDescriptor = [[MTLTextureDescriptor alloc] init];
    textureDescriptor.textureType = MTLTextureType2D;
    // Indicate that each pixel has a Blue, Green, Red, and Alpha channel,
    //   each in an 8-bit unnormalized value (0 maps to 0.0, while 255 maps to 1.0)
    textureDescriptor.pixelFormat = MTLPixelFormatBGRA8Unorm;
    textureDescriptor.width = image.width;
    textureDescriptor.height = image.height;
    
    // The image kernel only needs to read the incoming image data.
    
    textureDescriptor.usage = MTLTextureUsageShaderRead;
    _inputTexture = [_device newTextureWithDescriptor:textureDescriptor];
    
    // The output texture needs to be written by the image kernel and sampled
    // by the rendering code.
    
    textureDescriptor.usage = MTLTextureUsageShaderWrite | MTLTextureUsageShaderRead;
    _outputTexture = [_device newTextureWithDescriptor:textureDescriptor];
    
    MTLRegion region = {{0, 0, 0}, {textureDescriptor.width, textureDescriptor.height, 1}};
    
    // Calculate the size of each texel times the width of the textures.
    NSUInteger bytesPerRow = 4 * textureDescriptor.width;
    
    // Copy the bytes from the data object into the texture.
    [_inputTexture replaceRegion:region
                     mipmapLevel:0
                       withBytes:image.data.bytes
                     bytesPerRow:bytesPerRow];
    if (_inputTexture && !error) {
        LOGI("Failed to create inpute texture: {}", [error.description cStringUsingEncoding:NSUTF8StringEncoding])
    }
    
    // Set the compute kernel's threadgroup size to 16 x 16.
    _threadgroupSize = MTLSizeMake(16, 16, 1);
    
    // Calculate the number of rows and columns of threadgroups given the size of the
    // input image. Ensure that the grid covers the entire image (or more).
    _threadgroupCount.width = (_inputTexture.width + _threadgroupSize.width - 1) / _threadgroupSize.width;
    _threadgroupCount.height = (_inputTexture.height + _threadgroupSize.height - 1) / _threadgroupSize.height;
    // The image data is 2D, so set depth to 1.
    _threadgroupCount.depth = 1;
    
    // Create the command queue.
    _commandQueue = [_device newCommandQueue];
}

void Engine::compute(id <MTLCommandBuffer> commandBuffer) {
    // Process the input image.
    id <MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
    [computeEncoder setComputePipelineState:_computePipelineState];
    [computeEncoder setTexture:_inputTexture
                       atIndex:AAPLTextureIndexInput];
    [computeEncoder setTexture:_outputTexture
                       atIndex:AAPLTextureIndexOutput];
    [computeEncoder dispatchThreadgroups:_threadgroupCount
                   threadsPerThreadgroup:_threadgroupSize];
    [computeEncoder endEncoding];
}

void Engine::render(id <MTLRenderCommandEncoder> renderEncoder) {
    static const AAPLVertex quadVertices[] =
    {
        // Pixel positions, Texture coordinates
        {{250, -250}, {1.f, 1.f}},
        {{-250, -250}, {0.f, 1.f}},
        {{-250, 250}, {0.f, 0.f}},
        
        {{250, -250}, {1.f, 1.f}},
        {{-250, 250}, {0.f, 0.f}},
        {{250, 250}, {1.f, 0.f}},
    };
    
    // Set the region of the drawable to draw into.
    [renderEncoder setViewport:(MTLViewport) {0.0, 0.0,
        static_cast<double>(_viewportSize.x), static_cast<double>(_viewportSize.y), -1.0, 1.0}];
    [renderEncoder setRenderPipelineState:_renderPipelineState];
    // Encode the vertex data.
    [renderEncoder setVertexBytes:quadVertices
                           length:sizeof(quadVertices)
                          atIndex:AAPLVertexInputIndexVertices];
    // Encode the viewport data.
    [renderEncoder setVertexBytes:&_viewportSize
                           length:sizeof(_viewportSize)
                          atIndex:AAPLVertexInputIndexViewportSize];
    // Encode the output texture from the previous stage.
    [renderEncoder setFragmentTexture:_outputTexture
                              atIndex:AAPLTextureIndexOutput];
    // Draw the quad.
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                      vertexStart:0
                      vertexCount:6];
}

void Engine::resize(uint32_t width, uint32_t height) {
    // Save the size of the drawable to pass to the render pipeline.
    _viewportSize.x = width;
    _viewportSize.y = height;
}

}
