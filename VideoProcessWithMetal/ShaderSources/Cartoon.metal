//
//  SimpleToon.metal
//  VideoProcessWithMetal
//
//  Created by tomisacat on 07/01/2018.
//  Copyright © 2018 tomisacat. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

kernel void cartoon(texture2d<float, access::read> inTexture [[ texture(0) ]],
                    texture2d<float, access::write> outTexture [[ texture(1) ]],
                    uint2 gid [[ thread_position_in_grid ]])
{
    float4 result = floor(inTexture.read(gid) * 3.0) / 3.0;
    outTexture.write(result, gid);
}
