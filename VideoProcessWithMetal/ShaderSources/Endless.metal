//
//  endless.metal
//  VideoProcessWithMetal
//
//  Created by tomisacat on 08/01/2018.
//  Copyright © 2018 tomisacat. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

#define PI 3.141592653589793238462643383279502884197169

kernel void endless(texture2d<float, access::read> inTexture [[ texture(0) ]],
                    texture2d<float, access::write> outTexture [[ texture(1) ]],
                    device const float *time [[ buffer(0) ]],
                    uint2 gid [[ thread_position_in_grid ]])
{
    float2 uv = float2(gid) / float2(inTexture.get_width(), inTexture.get_height());
    float iTime = *time;
    
    // zooming
    uv -= 0.5;
    uv *= (1.0 / pow(4.0, fract(iTime / 2.0)));
    uv += 0.5;
    
    float2 tri = abs(1.0 - (uv * 2.0));
    float zoom = min(pow(2.0, floor(-log2(tri.x))), pow(2.0, floor(-log2(tri.y))));
    float zoom_id = log2(zoom) + 1.0;
    float div = pow(2.0, (-zoom_id - 1.0)) * (-2.0 + pow(2.0, zoom_id));
    float2 uv2 = (uv - div) * zoom;
    uint2 position = uint2(inTexture.get_width() * uv2.x, inTexture.get_height() * uv2.y);
    outTexture.write(inTexture.read(position), gid);
}
