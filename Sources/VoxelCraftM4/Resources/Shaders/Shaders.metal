#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float4x4 viewProjection;
    float4x4 model;
    float3 cameraPos;
    float _pad;
    float3 lightDir;
    float _pad2;
};

struct VertexIn {
    float3 position [[attribute(0)]];
    float3 normal   [[attribute(1)]];
    float3 color    [[attribute(2)]];
};

struct VertexOut {
    float4 position [[position]];
    float3 worldPos;
    float3 normal;
    float3 color;
};

vertex VertexOut vs_main(VertexIn in [[stage_in]],
                         constant Uniforms &u [[buffer(1)]]) {
    VertexOut out;
    float4 worldPos = u.model * float4(in.position, 1.0);
    out.worldPos = worldPos.xyz;
    out.position = u.viewProjection * worldPos;
    out.normal   = normalize((u.model * float4(in.normal, 0.0)).xyz);
    out.color    = in.color;
    return out;
}

fragment float4 fs_main(VertexOut in [[stage_in]],
                        constant Uniforms &u [[buffer(1)]]) {
    float3 N = normalize(in.normal);
    float3 L = normalize(-u.lightDir);

    // Sun direct light
    float NdotL = max(dot(N, L), 0.0);
    float3 sunColor = float3(1.0, 0.96, 0.86) * 1.4;
    float3 direct = in.color * NdotL * sunColor;

    // Hemispherical sky/ground ambient (much stronger)
    float hemi = 0.5 + 0.5 * N.y;
    float3 skyTint    = float3(0.55, 0.78, 1.0);
    float3 groundTint = float3(0.30, 0.25, 0.20);
    float3 ambient    = mix(groundTint, skyTint, hemi) * in.color * 0.85;

    // Cheap face-direction tint to make cubes pop a bit
    float3 axisTint = float3(1.0);
    if (abs(N.x) > 0.5) axisTint = float3(0.85);   // sides slightly darker
    else if (N.y >  0.5) axisTint = float3(1.10);  // tops bright
    else if (N.y < -0.5) axisTint = float3(0.65);  // bottoms dark

    float3 color = (direct + ambient) * axisTint;

    // Distance fog (sky-blue)
    float dist = distance(in.worldPos, u.cameraPos);
    float fog = exp(-0.0035 * dist);
    fog = clamp(fog, 0.0, 1.0);
    float3 fogColor = float3(0.62, 0.80, 0.98);
    color = mix(fogColor, color, fog);

    // ACES-ish tonemap + gamma is implicit via sRGB target
    color = (color * (2.51 * color + 0.03)) / (color * (2.43 * color + 0.59) + 0.14);
    color = clamp(color, 0.0, 1.0);
    return float4(color, 1.0);
}