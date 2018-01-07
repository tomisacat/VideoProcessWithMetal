//
//  Mirror.metal
//  VideoProcessWithMetal
//
//  Created by tomisacat on 07/01/2018.
//  Copyright © 2018 tomisacat. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

float average(float4);

float average(float4 col)
{
    return (col.r + col.g + col.b) / 3.0;
}

kernel void mirror(texture2d<float, access::read> inTexture [[ texture(0) ]],
                   texture2d<float, access::write> outTexture [[ texture(1) ]],
                   uint2 gid [[ thread_position_in_grid ]])
{
    float4 origin = inTexture.read(gid);
    float4 mir = inTexture.read(uint2(inTexture.get_width() - gid.x, gid.y));
    
    if (average(origin) > average(mir))
    {
        outTexture.write(origin, gid);
    }
    else
    {
        outTexture.write(mir, gid);
    }
}
