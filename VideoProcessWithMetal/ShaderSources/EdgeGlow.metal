//
//  EdgeGlow.metal
//  VideoProcessWithMetal
//
//  Created by tomisacat on 08/01/2018.
//  Copyright © 2018 tomisacat. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

constant float kernelWidth = 3.0;
constant float kernelHeight = 3.0;

kernel void edgeGlow(texture2d<float, access::read> inTexture [[ texture(0) ]],
                     texture2d<float, access::write> outTexture [[ texture(1) ]],
                     device const float *time [[ buffer(0) ]],
                     uint2 gid [[ thread_position_in_grid ]])
{
    float4 origin = inTexture.read(gid);
    
    float k[int(kernelWidth * kernelHeight)];
    k[0] = -1.0;
    k[1] = -1.0;
    k[2] = -1.0;
    k[3] = -1.0;
    k[4] = 8.0;
    k[5] = -1.0;
    k[6] = -1.0;
    k[7] = -1.0;
    k[8] = -1.0;
    
    float4 result = float4(0.0);
    float width = inTexture.get_width();
    float height = inTexture.get_height();
    float2 uv = float2(gid) / float2(width, height);
    
    for(float y = 0.0; y < kernelHeight; ++y) {
        for(float x = 0.0; x < kernelWidth; ++x) {
            float2 position = float2(uv.x + float(int(x - kernelWidth / 2.0)) / width,
                                     uv.y + float(int(y - kernelHeight / 2.0)) / height);
            result += inTexture.read(uint2(position * float2(width, height))) * k[int(x + y * kernelWidth)];
        }
    }
    
    if (length(result) <= 0.2) {
        outTexture.write(origin, gid);
    } else {
        outTexture.write(float4(0.0, 1.0, 0.0, 1.0) * sin(*time * 5.0) + origin * cos(*time * 5.0), gid);
    }
}
