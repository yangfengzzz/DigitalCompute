//  Copyright (c) 2022 Feng Yang
//
//  I am making my contributions/submissions to this project solely in my
//  personal capacity and am not conveying any rights to any intellectual
//  property of any third parties.

#include <metal_stdlib>
#include "cloth_data.h"
using namespace metal;

constant uint32_t MaxParticlesInSharedMem = 1969;
constant uint32_t blockDim = 1024;
constant uint32_t BlockSize = blockDim;
constant uint32_t WarpsPerBlock = (BlockSize >> 5);

float rsqrt_2(const float v) {
    float halfV = v * 0.5f;
    float threeHalf = 1.5f;
    float r = rsqrt(v);
    for(int i = 0; i < 10; ++i)
        r = r * (threeHalf - halfV * r * r);
    return r;
}

template<typename IParticles>
void accelerateParticles(IParticles curParticles, uint32_t threadIdx,
                         const device DxFrameData& gFrameData,
                         const device DxClothData& gClothData,
                         const device float4* bParticleAccelerations) {
    // might be better to move this into integrate particles
    uint32_t accelerationsOffset = gFrameData.mParticleAccelerationsOffset;

    threadgroup_barrier(mem_flags::mem_threadgroup); // looping with 4 instead of 1 thread per particle

    float sqrIterDt = ~threadIdx & 0x3 ? gFrameData.mIterDt * gFrameData.mIterDt : 0.0f;
    for (uint32_t i = threadIdx; i < gClothData.mNumParticles * 4; i += blockDim) {
        float4 acceleration = bParticleAccelerations[accelerationsOffset + i];

        float4 curPos = curParticles.get(i / 4);
        if (curPos.w > 0.0f) {
            curPos += acceleration * sqrIterDt;
            curParticles.set(i / 4, curPos);
        }
    }

    threadgroup_barrier(mem_flags::mem_threadgroup);
}
