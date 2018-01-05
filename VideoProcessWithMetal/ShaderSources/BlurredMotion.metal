//
//  BlurredMotion.metal
//  VideoProcessWithMetal
//
//  Created by tomisacat on 05/01/2018.
//  Copyright © 2018 tomisacat. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

kernel void blurredMotion(texture2d<float, access::read> inTexture [[ texture(0) ]],
                          texture2d<float, access::write> outTexture [[ texture(1) ]],
                          texture2d<float, access::read> lastTexture [[ texture(2) ]],
                          device const float *time [[ buffer(0) ]],
                          uint2 gid [[ thread_position_in_grid ]])
{
    float4 buf = lastTexture.read(gid);
    float4 bri = inTexture.read(gid);
    outTexture.write(buf * 0.9 + bri * 0.1, gid);
}
