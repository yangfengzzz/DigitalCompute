//  Copyright (c) 2022 Feng Yang
//
//  I am making my contributions/submissions to this project solely in my
//  personal capacity and am not conveying any rights to any intellectual
//  property of any third parties.

#pragma once

#import <Metal/Metal.h>
#import <simd/simd.h>

namespace vox {
    class Engine {
    public:
        Engine();
        
        void compute(id <MTLCommandBuffer> commandBuffer);

        void render(id <MTLRenderCommandEncoder> renderEncoder);

        void resize(uint32_t width, uint32_t height);

        inline id <MTLDevice> device() {
            return _device;
        }

        inline id <MTLCommandQueue> commandQueue() {
            return _commandQueue;
        }

        inline MTLPixelFormat colorPixelFormat() {
            return MTLPixelFormatBGRA8Unorm_sRGB;
        }

    private:
        // The device object (aka GPU) used to process images.
        id <MTLDevice> _device;

        id <MTLComputePipelineState> _computePipelineState;
        id <MTLRenderPipelineState> _renderPipelineState;

        id <MTLCommandQueue> _commandQueue;

        // Texture object that serves as the source for image processing.
        id <MTLTexture> _inputTexture;

        // Texture object that serves as the output for image processing.
        id <MTLTexture> _outputTexture;

        // The current size of the viewport, used in the render pipeline.
        vector_uint2 _viewportSize;

        // Compute kernel dispatch parameters
        MTLSize _threadgroupSize;
        MTLSize _threadgroupCount;

    };

}

