//
//  Transform.metal
//  VideoProcessWithMetal
//
//  Created by tomisacat on 05/01/2018.
//  Copyright © 2018 tomisacat. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

float2x2 rot(float);

float2x2 rot(float a)
{
    float c = cos(a);
    float s = sin(a);
    
    return float2x2(float2(c, s), float2(-s, c));
}

kernel void colorTransform(texture2d<float, access::read> inTexture [[ texture(0) ]],
                           texture2d<float, access::write> outTexture [[ texture(1) ]],
                           device const float *time [[ buffer(0) ]],
                           uint2 gid [[ thread_position_in_grid ]])
{
    float2 uv = float2(gid) / float2(inTexture.get_width(), inTexture.get_height());
    
    float hs = step(0.3, sin(*time + 2.0 + 4.0 * sin(*time * 9.0))) * (sin(uv.y * 10.0 + *time * 5.0) + sin(*time) * sin(*time * 20.0) * 0.5) * 0.05;
    uv.x += hs;
    float vs = step(0.8, sin(*time + 2.0 * sin(*time * 4.0))) * (sin(*time) * sin(*time * 20.0) + cos(*time) * sin(*time * 200.0) * 0.1);
    uv.y = fract(uv.y + vs);
    
    float3 c = inTexture.read(gid).rgb;
    c.xy = rot(*time * 0.3) * c.xy;
    c.yz = rot(*time * 0.5) * c.yz;
    c.xy = rot(*time * 0.7) * c.xy;
    c.yz = rot(*time * 0.9) * c.yz;
    
    outTexture.write(float4(floor(5.0 * abs(c)) * 0.2, 1.0), gid);
}

