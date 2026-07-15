//
//  CutoutDeformation.metal
//  Animagic
//
//  Created by Meynabel Dimas Wisodewo on 14/07/26.
//

#include <metal_stdlib>
#include <RealityKit/RealityKit.h>

using namespace metal;

[[visible]]
void cutoutSurface(realitykit::surface_parameters params)
{
    constexpr sampler textureSampler(coord::normalized, address::clamp_to_edge, filter::linear, mip_filter::linear);
    half4 color = params.textures().custom().sample(textureSampler, params.geometry().uv0());
    params.surface().set_emissive_color(color.rgb);
    params.surface().set_opacity(color.a);
}

[[visible]]
void cutoutGeometryModifier(realitykit::geometry_parameters params)
{
    auto geometry = params.geometry();
    float4 configuration = params.uniforms().custom_parameter();
    float archetype = floor(configuration.x + 0.001);
    float behavior = round(fract(configuration.x) * 100.0);
    float activity = configuration.y;
    float phaseOffset = configuration.z;
    float faceDirection = configuration.w;
    float gaitFrequency = archetype < 0.5 ? 3.8 :
        archetype < 1.5 ? 5.6 :
        archetype < 2.5 ? 8.2 :
        archetype < 3.5 ? 3.8 :
        archetype < 4.5 ? 2.0 :
        archetype < 5.5 ? 2.7 :
        archetype < 6.5 ? 3.2 : 6.5;
    float cadence = behavior < 0.5 ? 1.0 :
        behavior < 1.5 ? 1.75 :
        behavior < 2.5 ? 0.55 : 0.18;
    float phase = phaseOffset + params.uniforms().time() * gaitFrequency * cadence;

    float2 sourceUV = geometry.uv0();
    float2 uv = float2(faceDirection < 0.0 ? 1.0 - sourceUV.x : sourceUV.x, sourceUV.y);
    float2 centered = (uv - 0.5) * 2.0;
    float edgeFalloff = smoothstep(0.0, 0.12, uv.x)
        * smoothstep(0.0, 0.12, 1.0 - uv.x)
        * smoothstep(0.0, 0.1, uv.y)
        * smoothstep(0.0, 0.1, 1.0 - uv.y);

    float3 offset = float3(0.0);
    if (archetype < 0.5) {
        float tailWeight = smoothstep(0.15, 1.0, abs(centered.x));
        float swim = sin((uv.x * 10.0) - phase);
        offset.z = swim * tailWeight * 0.018 * edgeFalloff;
        offset.y = sin((uv.x * 6.0) - phase * 0.55) * 0.003 * edgeFalloff;
    } else if (archetype < 1.5) {
        float wingWeight = smoothstep(0.08, 0.88, abs(centered.x));
        float flap = sin(phase) * wingWeight;
        offset.z = flap * 0.020 * edgeFalloff;
        offset.y = -abs(flap) * abs(centered.x) * 0.005 * edgeFalloff;
    } else if (archetype < 2.5) {
        float wingWeight = smoothstep(0.02, 0.72, abs(centered.x));
        float flutter = sin(phase * 1.45 + abs(centered.x) * 1.8);
        offset.z = flutter * wingWeight * 0.024 * edgeFalloff;
        offset.x = sign(centered.x) * abs(flutter) * 0.002 * edgeFalloff;
    } else if (archetype < 3.5) {
        float spine = sin((uv.x * 5.0) - phase * 0.48);
        float pounce = behavior > 0.5 && behavior < 1.5 ? 1.35 : 0.75;
        offset.z = spine * (1.0 - abs(centered.y)) * 0.010 * pounce * edgeFalloff;
        offset.y = sin(phase) * (1.0 - uv.y) * 0.003 * edgeFalloff;
    } else if (archetype < 4.5) {
        float stride = sin(phase);
        float breathing = sin(phase * 0.22);
        offset.x = stride * (1.0 - uv.y) * 0.0025 * edgeFalloff;
        offset.z = (breathing * 0.004 + stride * 0.0015) * edgeFalloff;
    } else if (archetype < 5.5) {
        float hop = max(sin(phase), 0.0);
        float bodyCurve = max(1.0 - centered.x * centered.x, 0.0);
        offset.z = bodyCurve * hop * 0.017 * edgeFalloff;
        offset.y = -abs(centered.x) * (1.0 - hop) * 0.004 * edgeFalloff;
    } else if (archetype < 6.5) {
        float slither = sin((uv.x * 13.0) - phase);
        float secondary = sin((uv.x * 7.0) - phase * 0.65);
        offset.y = slither * 0.006 * edgeFalloff;
        offset.z = (slither * 0.008 + secondary * 0.004) * edgeFalloff;
    } else {
        float footfall = sin((uv.x * 17.0) + phase);
        float shellWeight = 1.0 - smoothstep(0.15, 1.0, abs(centered.y));
        offset.x = footfall * (1.0 - uv.y) * 0.004 * edgeFalloff;
        offset.z = sin(phase * 0.5) * shellWeight * 0.004 * edgeFalloff;
    }

    offset *= activity;
    geometry.set_model_position_offset(float3(offset.x * faceDirection, offset.y, offset.z * faceDirection));
}
