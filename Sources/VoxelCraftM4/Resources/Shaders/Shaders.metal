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
    float NdotL = max(dot(N, L), 0.0);

    // Hemispherical ambient (sky tint up, ground tint down)
    float hemi = 0.5 + 0.5 * N.y;
    float3 skyTint    = float3(0.55, 0.70, 0.95);
    float3 groundTint = float3(0.25, 0.20, 0.15);
    float3 ambient    = mix(groundTint, skyTint, hemi) * 0.35;

    float3 diffuse = in.color * NdotL * 0.85;
    float3 color = in.color * ambient + diffuse;

    // Distance fog (exp2)
    float dist = distance(in.worldPos, u.cameraPos);
    float fogDensity = 0.008;
    float fog = exp(-fogDensity * dist);
    fog = clamp(fog, 0.0, 1.0);
    float3 fogColor = float3(0.65, 0.78, 0.95);
    color = mix(fogColor, color, fog);

    // Simple ACES-ish tonemap
    color = color / (color + 1.0);
    return float4(color, 1.0);
}