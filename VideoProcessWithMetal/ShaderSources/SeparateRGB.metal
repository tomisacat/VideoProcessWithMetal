//
//  SeparateRGB.metal
//  VideoProcessWithMetal
//
//  Created by tomisacat on 03/08/2017.
//  Copyright © 2017 tomisacat. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

float hash(float);
float noise(float3);

float hash(float n) {
    return fract(sin(n) * 43758.5453);
}

float noise(float3 x) {
    float3 p = floor(x);
    float3 f = fract(x);
    
    f = f * f * (3.0 - 2.0 * f);
    
    float n = p.x + p.y * 57.0 + 113.0 * p.z;
    
    float res = mix(mix(mix(hash(n + 0.0), hash(n + 1.0), f.x),
                        mix(hash(n + 57.0), hash(n + 58.0), f.x), f.y),
                    mix(mix(hash(n + 113.0), hash(n + 114.0), f.x),
                        mix(hash(n + 170.0), hash(n + 171.0), f.x), f.y), f.z);
    return res;
}

kernel void separateRGB(texture2d<float, access::read> inTexture [[ texture(0) ]],
                        texture2d<float, access::write> outTexture [[ texture(1) ]],
                        device const float *time [[ buffer(0) ]],
                        uint2 gid [[ thread_position_in_grid ]]) {
    float2 uv = float2(gid);
    uv.x /= inTexture.get_width();
    uv.y /= inTexture.get_height();
    
    float iGlobalTime = *time;
    float blurx = noise(float3(iGlobalTime * 10.0, 0.0, 0.0)) * 2.0 - 1.0;
    float offsetx = blurx * 0.025;
    
    float blury = noise(float3(iGlobalTime * 10.0, 1.0, 0.0)) * 2.0 - 1.0;
    float offsety = blury * 0.01;
    
    float2 ruv = uv + float2(offsetx, offsety);
    float2 guv = uv + float2(-offsetx, -offsety);
    float2 buv = uv + float2(0.00, 0.0);
    
    float r = inTexture.read(uint2(ruv * float2(inTexture.get_width(), inTexture.get_height()))).r;
    float g = inTexture.read(uint2(guv * float2(inTexture.get_width(), inTexture.get_height()))).g;
    float b = inTexture.read(uint2(buv * float2(inTexture.get_width(), inTexture.get_height()))).b;
    
    outTexture.write(float4(r, g, b, 1.0), gid);
}
