//
//  Drunk.metal
//  VideoProcessWithMetal
//
//  Created by tomisacat on 07/01/2018.
//  Copyright © 2018 tomisacat. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

// zoom blur. code from GPUImage.
kernel void drunk(texture2d<float, access::read> inTexture [[ texture(0) ]],
                  texture2d<float, access::write> outTexture [[ texture(1) ]],
                  device const float *time [[ buffer(0) ]],
                  uint2 gid [[ thread_position_in_grid ]])
{
    float2 uv = float2(gid) / float2(inTexture.get_width(), inTexture.get_height());
    float2 size = float2(inTexture.get_width(), inTexture.get_height());
    float2 offset = 0.01 * (float2(0.5) - uv) * (sin(*time * 3) + 1.0);
    
    float4 result = inTexture.read(gid) * 0.18;
    result += inTexture.read(uint2((uv + offset) * size)) * 0.15;
    result += inTexture.read(uint2((uv + 2.0 * offset) * size)) * 0.12;
    result += inTexture.read(uint2((uv + 3.0 * offset) * size)) * 0.09;
    result += inTexture.read(uint2((uv + 4.0 * offset) * size)) * 0.05;
    result += inTexture.read(uint2((uv - offset) * size)) * 0.15;
    result += inTexture.read(uint2((uv - 2.0 * offset) * size)) * 0.12;
    result += inTexture.read(uint2((uv - 3.0 * offset) * size)) * 0.09;
    result += inTexture.read(uint2((uv - 4.0 * offset) * size)) * 0.05;
    
    outTexture.write(result, gid);
}
