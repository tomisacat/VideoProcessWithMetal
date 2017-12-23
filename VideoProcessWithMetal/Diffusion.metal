//
//  Diffusion.metal
//  VideoProcessWithMetal
//
//  Created by tomisacat on 20/12/2017.
//  Copyright © 2017 tomisacat. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

kernel void diffusion(texture2d<float, access::read> inTexture [[ texture(0) ]],
                      texture2d<float, access::write> outTexture [[ texture(1) ]],
                      texture2d<float, access::read> lastTexture [[ texture(2) ]],
                      device const float *time [[ buffer(0) ]],
                      uint2 gid [[ thread_position_in_grid ]])
{
    float4 l = lastTexture.read(gid - uint2(-1, 0));
    float4 r = lastTexture.read(gid - uint2(1, 0));
    float4 t = lastTexture.read(gid - uint2(0, 1));
    float4 b = lastTexture.read(gid - uint2(0, -1));
    float4 c = lastTexture.read(gid);
    
    float4 m = max(c, max(l, max(r, max(t, b))));
    float4 result = m * 0.95 + inTexture.read(gid) * 0.05;
    outTexture.write(result, gid);
}
