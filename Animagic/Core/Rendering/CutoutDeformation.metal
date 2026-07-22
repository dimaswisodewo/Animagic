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
    params.surface().set_base_color(color.rgb);
    params.surface().set_emissive_color(color.rgb * half3(0.12));
    params.surface().set_roughness(0.92h);
    params.surface().set_metallic(0.0h);
    params.surface().set_opacity(color.a);
}

[[visible]]
void cutoutGeometryModifier(realitykit::geometry_parameters params)
{
    auto geometry = params.geometry();
    float4 configuration = params.uniforms().custom_parameter();
    float bodyStyle = floor(configuration.x + 0.00001);
    float packedDetail = fract(configuration.x) * 100.0;
    float locomotion = floor(packedDetail + 0.001);
    float behavior = round(fract(packedDetail) * 100.0);
    float activity = configuration.y;
    float phaseOffset = configuration.z;
    float faceDirection = configuration.w;
    // Swift owns the authoritative phase so travel, contact, and deformation cannot drift.
    float phase = phaseOffset;

    float2 sourceUV = geometry.uv0();
    float2 uv = float2(faceDirection < 0.0 ? 1.0 - sourceUV.x : sourceUV.x, sourceUV.y);
    float2 centered = (uv - 0.5) * 2.0;
    float edgeFalloff = smoothstep(0.0, 0.06, uv.x)
        * smoothstep(0.0, 0.06, 1.0 - uv.x)
        * smoothstep(0.0, 0.05, uv.y)
        * smoothstep(0.0, 0.05, 1.0 - uv.y);
    float bodyWeight = 0.72 + 0.28 * edgeFalloff;
    float broadBend = sin(phase * 0.48) * 0.010
        + sin(phase * 0.93 + centered.y * 1.7) * 0.004;
    float breathing = sin(phase * 0.22 + centered.x * 1.4);

    float3 offset = float3(0.0);
    offset.z += broadBend * centered.x * centered.x * bodyWeight;
    offset.y += breathing * (1.0 - centered.x * centered.x) * 0.0025 * bodyWeight;
    if (bodyStyle < 0.5) {
        float wander = sin(phase * 0.55 + centered.x * 2.0);
        offset.z += wander * (1.0 - centered.x * centered.x) * 0.006 * bodyWeight;
        offset.y += breathing * (1.0 - abs(centered.x)) * 0.003 * bodyWeight;
    } else if (bodyStyle < 1.5) {
        float tailWeight = smoothstep(0.15, 1.0, abs(centered.x));
        float swim = sin((uv.x * 10.0) - phase);
        float secondary = sin((uv.x * 5.5) - phase * 0.57 + centered.y);
        offset.z += swim * tailWeight * 0.027 * bodyWeight;
        offset.z += secondary * tailWeight * 0.008 * edgeFalloff;
        offset.y += sin((uv.x * 6.0) - phase * 0.55) * 0.005 * bodyWeight;
    } else if (bodyStyle < 2.5) {
        if (locomotion > 0.5 && locomotion < 1.5) {
            float wingWeight = smoothstep(0.08, 0.88, abs(centered.x));
            float flap = sin(phase) * wingWeight;
            float wingRipple = sin(phase * 1.8 + abs(centered.x) * 4.0);
            offset.z += flap * 0.032 * bodyWeight;
            offset.z += wingRipple * wingWeight * 0.009 * edgeFalloff;
            offset.y -= abs(flap) * abs(centered.x) * 0.008 * bodyWeight;
        } else {
            float sway = sin(phase * 0.65);
            offset.x += sway * (1.0 - uv.y) * 0.006 * bodyWeight;
            offset.z += breathing * 0.007 * bodyWeight;
        }
    } else if (bodyStyle < 3.5) {
        float wingWeight = smoothstep(0.02, 0.72, abs(centered.x));
        float flutter = sin(phase * 1.45 + abs(centered.x) * 1.8);
        float flutterDetail = sin(phase * 2.7 + centered.y * 3.0);
        offset.z += flutter * wingWeight * 0.034 * bodyWeight;
        offset.z += flutterDetail * wingWeight * 0.010 * edgeFalloff;
        offset.x += sign(centered.x) * abs(flutter) * 0.004 * bodyWeight;
    } else if (bodyStyle < 4.5) {
        float spine = sin((uv.x * 5.0) - phase * 0.48);
        float pounce = behavior > 0.5 && behavior < 1.5 ? 1.35 : 0.75;
        float spineDetail = sin((uv.x * 9.0) - phase * 0.76);
        offset.z += spine * (1.0 - abs(centered.y)) * 0.018 * pounce * bodyWeight;
        offset.z += spineDetail * (1.0 - abs(centered.y)) * 0.006 * edgeFalloff;
        offset.y += sin(phase) * (1.0 - uv.y) * 0.005 * bodyWeight;
    } else if (bodyStyle < 5.5) {
        float stride = sin(phase);
        offset.x += stride * (1.0 - uv.y) * 0.004 * bodyWeight;
        offset.z += (breathing * 0.008 + stride * 0.003) * bodyWeight;
    } else if (bodyStyle < 6.5) {
        float hop = max(sin(phase), 0.0);
        float bodyCurve = max(1.0 - centered.x * centered.x, 0.0);
        offset.z += bodyCurve * hop * 0.028 * bodyWeight;
        offset.y -= abs(centered.x) * (1.0 - hop) * 0.007 * bodyWeight;
    } else if (bodyStyle < 7.5) {
        float slither = sin((uv.x * 13.0) - phase);
        float secondary = sin((uv.x * 7.0) - phase * 0.65);
        offset.y += slither * 0.010 * bodyWeight;
        offset.y += secondary * 0.004 * edgeFalloff;
        offset.z += (slither * 0.014 + secondary * 0.007) * bodyWeight;
    } else if (bodyStyle < 8.5) {
        float step = sin((uv.x * 14.0) + phase);
        float bodyRipple = sin(phase * 0.72 + centered.x * 3.0);
        offset.x += step * (1.0 - uv.y) * 0.0045 * bodyWeight;
        offset.z += bodyRipple * 0.008 * bodyWeight;
    } else if (bodyStyle < 9.5) {
        float footfall = sin((uv.x * 17.0) + phase);
        float shellWeight = 1.0 - smoothstep(0.15, 1.0, abs(centered.y));
        offset.x += footfall * (1.0 - uv.y) * 0.007 * bodyWeight;
        offset.z += sin(phase * 0.5) * shellWeight * 0.010 * bodyWeight;
        offset.z += sin(phase * 1.7 + centered.x * 2.0) * shellWeight * 0.004 * edgeFalloff;
    } else if (bodyStyle < 10.5) {
        float flipperWeight = smoothstep(0.12, 0.90, abs(centered.x));
        float stroke = sin(phase * 0.82 + abs(centered.x) * 1.4);
        offset.z += stroke * flipperWeight * 0.025 * bodyWeight;
        offset.y -= abs(stroke) * abs(centered.x) * 0.004 * edgeFalloff;
    } else {
        float pulse = sin(phase * 0.72);
        float radialWeight = max(1.0 - dot(centered, centered) * 0.45, 0.0);
        offset.z += pulse * radialWeight * 0.020 * bodyWeight;
        offset.y += cos(phase * 0.48 + centered.x * 2.0) * 0.006 * edgeFalloff;
    }

    offset *= activity;
    offset = clamp(offset, float3(-0.045), float3(0.045));
    geometry.set_model_position_offset(float3(offset.x * faceDirection, offset.y, offset.z * faceDirection));
}
