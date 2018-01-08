//
//  CRT.metal
//  VideoProcessWithMetal
//
//  Created by tomisacat on 08/01/2018.
//  Copyright © 2018 tomisacat. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

float rand(float);
float pattern(float2, float);

float rand(float x)
{
    return fract(sin(x * 10000.0));
}

float pattern(float2 uv, float time)
{
    return 1.0 + sin((uv.y + rand(uv.x + time) * 0.02) * 100.0 + time * 100.0) * 0.2;
}

kernel void crt(texture2d<float, access::read> inTexture [[ texture(0) ]],
                texture2d<float, access::write> outTexture [[ texture(1) ]],
                device const float *time [[ buffer(0) ]],
                uint2 gid [[ thread_position_in_grid ]])
{
    float width = inTexture.get_width();
    float height = inTexture.get_height();
    float2 size = float2(width, height);
    float2 uv = float2(gid) / size;
    
    float2 st = uv;
    st.x += (rand(uv.y + *time) - 0.5) * abs(rand(floor(*time))) * 0.05;
    st.x = (st.x - 0.5) * 1.2 + 0.5;
    st.x += step(0.8, fract(*time)) * sin(*time * 20.0 + uv.y * 10.0) * 0.02;
    st.y = fract(uv.y + sin(floor(*time) * 10000.0) * (*time));
    
    uint2 position = uint2(st * size);
    float3 c = inTexture.read(position).rgb;
    c *= step(0.0, st.x) - step(1.0, st.x);
    float2 offset = float2(0.2, 0.1);
    c.r *= pattern(uv + offset, *time);
    c.g *= pattern(uv, *time);
    c.b *= pattern(uv - offset, *time);
    
    outTexture.write(float4(c, 1.0), gid);
}
