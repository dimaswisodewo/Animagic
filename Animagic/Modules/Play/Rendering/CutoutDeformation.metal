//
//  CutoutDeformation.metal
//  Animagic
//
//  Created by Meynabel Dimas Wisodewo on 14/07/26.
//

#include <metal_stdlib>
#include <RealityKit/RealityKit.h>

using namespace metal;

#define CUTOUT_UNIFORMS(NAME) \
struct NAME { \
    float4 motion; \
    float4 state; \
    float4 reaction; \
    float4 geometry; \
    float4 texture; \
}

// Each layout matches the same-named private Swift definition.
CUTOUT_UNIFORMS(SwimGeometryUniforms);
CUTOUT_UNIFORMS(FlyGeometryUniforms);
CUTOUT_UNIFORMS(FlutterGeometryUniforms);
CUTOUT_UNIFORMS(WalkGeometryUniforms);
CUTOUT_UNIFORMS(StompGeometryUniforms);
CUTOUT_UNIFORMS(WaddleGeometryUniforms);
CUTOUT_UNIFORMS(HopGeometryUniforms);
CUTOUT_UNIFORMS(SlitherGeometryUniforms);
CUTOUT_UNIFORMS(CrawlGeometryUniforms);
CUTOUT_UNIFORMS(ScuttleGeometryUniforms);
CUTOUT_UNIFORMS(GenericGeometryUniforms);

struct CutoutGeometryContext {
    float phase;
    // Retained for state-layout compatibility; archetype behavior owns amplitude.
    float activity;
    float speed;
    float steering;
    float behavior;
    float behaviorProgress;
    float contact;
    float contactProgress;
    float reactionProgress;
    float reactionStrength;
    float irregularity;
    float facing;
    float width;
    float height;
    float surfaceCompensation;
    float2 uv;
    float2 centered;
    float orientedU;
    float orientedX;
};

inline CutoutGeometryContext cutoutContext(
    realitykit::geometry_parameters params,
    float4 motion,
    float4 state,
    float4 reaction,
    float4 geometry,
    float4 texture
) {
    float2 textureOrigin = geometry.zw;
    float2 textureSize = max(texture.xy, float2(0.0001));
    float2 sourceUV = clamp(
        (params.geometry().uv0() - textureOrigin) / textureSize,
        float2(0.0),
        float2(1.0)
    );
    // The back entity is rotated around Y, so its matching artwork point is at 1 - U.
    // Normalize only deformation space; surface texture sampling keeps the authored UV.
    float2 uv = float2(
        texture.z < 0.0 ? 1.0 - sourceUV.x : sourceUV.x,
        sourceUV.y
    );
    float facing = reaction.w;
    float orientedU = facing < 0.0 ? 1.0 - uv.x : uv.x;
    float2 centered = (uv - 0.5) * 2.0;
    return {
        motion.x, motion.y, motion.z, motion.w,
        state.x, state.y, state.z, state.w,
        reaction.x, reaction.y, reaction.z, facing,
        geometry.x, geometry.y, texture.z,
        uv, centered, orientedU, orientedU * 2.0 - 1.0
    };
}

inline void setCutoutOffset(
    realitykit::geometry_parameters params,
    float3 offset,
    CutoutGeometryContext context,
    float limit
) {
    offset = clamp(offset, float3(-limit), float3(limit));
    params.geometry().set_model_position_offset(
        float3(
            offset.x * context.surfaceCompensation,
            offset.y,
            offset.z * context.surfaceCompensation
        )
    );
}

inline float behaviorAmplitude(
    float behavior,
    float moving,
    float energetic,
    float coasting,
    float resting
) {
    if (behavior < 0.5) { return moving; }
    if (behavior < 1.5) { return energetic; }
    if (behavior < 2.5) { return coasting; }
    return resting;
}

inline float behaviorCadence(
    float behavior,
    float moving,
    float energetic,
    float coasting,
    float resting
) {
    return behaviorAmplitude(behavior, moving, energetic, coasting, resting);
}

inline float reactionEnvelope(float progress) {
    return progress > 0.0 && progress < 1.0 ? sin(progress * M_PI_F) : 0.0;
}

inline float localReactionBoost(CutoutGeometryContext context) {
    return 1.0 + reactionEnvelope(context.reactionProgress)
        * context.reactionStrength * 0.25;
}

struct CutoutSurfaceUniforms {
    texture2d<half> surfaceField;
    float4 parameters;
};

struct CardboardSurfaceUniforms {
    texture2d<half> frontTexture;
    texture2d<half> backTexture;
    float4 parameters;
};

[[stitchable]]
void cutoutSurface(
    realitykit::surface_parameters params,
    constant CutoutSurfaceUniforms &uniforms
)
{
    constexpr sampler textureSampler(
        coord::normalized,
        address::clamp_to_zero,
        filter::linear,
        mip_filter::linear
    );
    half4 color = params.textures().custom().sample(
        textureSampler,
        params.geometry().uv0()
    );
    half opacity = color.a;
    if (uniforms.parameters.x > 0.5) {
        float2 fieldUV = params.geometry().uv0();
        if (uniforms.parameters.y > 0.5) {
            fieldUV.x = uniforms.parameters.z + uniforms.parameters.w - fieldUV.x;
        }
        half2 field = uniforms.surfaceField.sample(
            textureSampler,
            fieldUV
        ).rg;
        constexpr half transition = 1.5h / 255.0h;
        opacity *= smoothstep(field.g - transition, field.g + transition, field.r);
    }
    params.surface().set_base_color(color.rgb);
    params.surface().set_emissive_color(color.rgb * half3(0.12));
    params.surface().set_roughness(0.92h);
    params.surface().set_metallic(0.0h);
    params.surface().set_opacity(opacity);
}

[[stitchable]]
void cardboardRimSurface(
    realitykit::surface_parameters params,
    constant CardboardSurfaceUniforms &uniforms
)
{
    constexpr half3 kraftColor = half3(0.479h, 0.242h, 0.091h);
    half3 color = kraftColor;
    half emissiveStrength = 0.025h;
    half roughness = 0.92h;
    if (uniforms.parameters.x > 0.5) {
        constexpr sampler textureSampler(
            coord::normalized,
            address::clamp_to_edge,
            filter::linear,
            mip_filter::linear
        );
        float3 normal = normalize(params.geometry().normal());
        half frontAmount = half(step(0.0, normal.z));
        half3 front = uniforms.frontTexture.sample(
            textureSampler,
            params.geometry().uv0()
        ).rgb;
        float2 backUV = params.geometry().uv0();
        backUV.x = uniforms.parameters.y + uniforms.parameters.z - backUV.x;
        half3 back = uniforms.backTexture.sample(
            textureSampler,
            backUV
        ).rgb;
        half3 artwork = mix(back, front, frontAmount);
        half faceAmount = half(smoothstep(0.15, 0.85, abs(normal.z)));
        color = mix(kraftColor, artwork, faceAmount);
        half bevelHighlight = 4.0h * faceAmount * (1.0h - faceAmount);
        roughness = mix(0.92h, 0.76h, bevelHighlight);
        emissiveStrength = mix(0.025h, 0.08h, faceAmount);
    }
    params.surface().set_base_color(color);
    params.surface().set_emissive_color(color * half3(emissiveStrength));
    params.surface().set_roughness(roughness);
    params.surface().set_metallic(0.0h);
    params.surface().set_opacity(1.0h);
}

[[stitchable]]
void swimGeometryModifier(
    realitykit::geometry_parameters params,
    constant SwimGeometryUniforms &uniforms
) {
    CutoutGeometryContext c = cutoutContext(
        params,
        uniforms.motion,
        uniforms.state,
        uniforms.reaction,
        uniforms.geometry,
        uniforms.texture
    );
    float rear = 1.0 - c.orientedU;
    float rearWeight = smoothstep(0.12, 0.96, rear);
    float flexibleBody = mix(0.12, 1.0, rearWeight);
    float amplitude = behaviorAmplitude(c.behavior, 0.82, 1.18, 0.55, 0.30);
    float cadence = behaviorCadence(c.behavior, 1.0, 1.12, 0.75, 0.60);
    amplitude *= mix(0.72, 1.12, c.speed) * localReactionBoost(c);

    float maxLateral = min(c.width * 0.040, 0.045);
    float maxDepth = min(c.width * 0.080, 0.045);
    float maxVertical = clamp(c.width * 0.018, 0.003, 0.009);
    float travelingWave = sin(c.phase * cadence + rear * 6.4);
    float secondaryWave = sin(c.phase * cadence * 1.7 + rear * 10.5 + c.centered.y);
    float residualWave = sin(c.phase * 0.38 + rear * 4.2);
    float breathing = sin(c.phase * 0.22 + c.centered.y * 0.7);

    float3 offset = float3(0.0);
    offset.x += travelingWave * flexibleBody * maxLateral * amplitude;
    offset.z += travelingWave * flexibleBody * maxDepth * amplitude;
    offset.z += secondaryWave * rearWeight * maxDepth * 0.18 * amplitude;
    offset.z += residualWave * (1.0 - c.speed) * flexibleBody * maxDepth * 0.12;
    offset.y += travelingWave * rearWeight * maxVertical * amplitude;
    offset.y += breathing * (1.0 - rearWeight * 0.35) * maxVertical * 0.24;
    offset.z += c.steering * c.orientedX * c.orientedX * maxDepth * 0.35;

    if (c.reactionStrength > 0.0) {
        float anticipation = c.reactionProgress < 0.133
            ? smoothstep(0.0, 0.133, c.reactionProgress)
            : 0.0;
        float propulsion = c.reactionProgress >= 0.133 && c.reactionProgress < 0.444
            ? sin((c.reactionProgress - 0.133) / 0.311 * M_PI_F)
            : 0.0;
        float settleProgress = clamp((c.reactionProgress - 0.444) / 0.556, 0.0, 1.0);
        float settling = sin(settleProgress * M_PI_F * 3.0) * (1.0 - settleProgress);
        offset.x -= c.centered.x * anticipation * c.width * 0.035 * c.reactionStrength;
        offset.x += c.centered.x * propulsion * c.width * 0.016 * c.reactionStrength;
        offset.z += sin(c.phase * 1.9 + rear * 8.5)
            * rearWeight * maxDepth
            * (propulsion * 0.9 + settling * 0.35)
            * c.reactionStrength;
    }
    setCutoutOffset(params, offset, c, 0.045);
}

[[stitchable]]
void flyGeometryModifier(
    realitykit::geometry_parameters params,
    constant FlyGeometryUniforms &uniforms
) {
    CutoutGeometryContext c = cutoutContext(
        params, uniforms.motion, uniforms.state, uniforms.reaction,
        uniforms.geometry, uniforms.texture
    );
    float outer = smoothstep(0.28, 0.90, abs(c.centered.x));
    float core = 1.0 - smoothstep(0.0, 0.28, abs(c.centered.x));
    float cadence = behaviorCadence(c.behavior, 1.0, 1.25, 0.75, 0.55);
    float amplitude = behaviorAmplitude(c.behavior, 1.0, 1.2, 0.55, 0.30)
        * localReactionBoost(c);
    float stroke = sin(c.phase * cadence);
    float fold = abs(stroke);
    float3 offset = float3(0.0);

    offset.x -= sign(c.centered.x) * fold * outer * c.width * 0.050 * amplitude;
    offset.y += stroke * outer * c.height * 0.025 * amplitude;
    offset.z += stroke * outer * c.width * 0.070 * amplitude;
    offset.z += stroke * core * c.width * 0.009 * amplitude;
    if (c.behavior > 1.5 && c.behavior < 2.5) {
        offset.z += outer * c.width * 0.012;
    }
    offset.z += c.steering * outer * c.width * 0.012;

    if (c.reactionStrength > 0.0) {
        float tuck = 1.0 - smoothstep(0.0, 0.171, c.reactionProgress);
        float lifts = c.reactionProgress >= 0.171
            ? sin((c.reactionProgress - 0.171) * M_PI_F * 4.0)
                * (1.0 - c.reactionProgress)
            : 0.0;
        offset.x -= c.centered.x * outer * tuck * c.width * 0.025;
        offset.z += lifts * outer * c.width * 0.030;
    }
    setCutoutOffset(params, offset, c, 0.045);
}

[[stitchable]]
void flutterGeometryModifier(
    realitykit::geometry_parameters params,
    constant FlutterGeometryUniforms &uniforms
) {
    CutoutGeometryContext c = cutoutContext(
        params, uniforms.motion, uniforms.state, uniforms.reaction,
        uniforms.geometry, uniforms.texture
    );
    float outer = smoothstep(0.22, 0.88, abs(c.centered.x));
    float centerProtection = smoothstep(0.22, 0.48, abs(c.centered.x));
    float cadence = behaviorCadence(c.behavior, 1.35, 1.65, 0.75, 0.60);
    float amplitude = behaviorAmplitude(c.behavior, 1.0, 1.2, 0.55, 0.35)
        * localReactionBoost(c);
    float irregularPhase = c.irregularity * 0.18;
    float sideLag = c.centered.x > 0.0 ? M_PI_F * 0.16 : 0.0;
    float stroke = sin(c.phase * cadence + irregularPhase + sideLag);
    float fold = abs(stroke);
    float3 offset = float3(0.0);
    offset.x -= sign(c.centered.x) * fold * outer * centerProtection
        * c.width * 0.080 * amplitude;
    offset.y += stroke * outer * centerProtection * c.height * 0.030 * amplitude;
    offset.z += stroke * outer * centerProtection * c.width * 0.100 * amplitude;

    if (c.behavior > 2.5) {
        offset.x -= sign(c.centered.x) * outer * c.width * 0.010;
        offset.z += sin(c.phase * 0.25) * (1.0 - outer) * c.width * 0.003;
    }

    if (c.reactionStrength > 0.0) {
        float compression = 1.0 - smoothstep(0.0, 0.2, c.reactionProgress);
        float ripples = sin(c.reactionProgress * M_PI_F * 6.0)
            * (1.0 - c.reactionProgress);
        offset.x -= sign(c.centered.x) * outer * compression * c.width
            * (c.centered.x > 0.0 ? 0.022 : 0.012);
        offset.z += ripples * outer * c.width * 0.028;
    }
    setCutoutOffset(params, offset, c, 0.040);
}

[[stitchable]]
void walkGeometryModifier(
    realitykit::geometry_parameters params,
    constant WalkGeometryUniforms &uniforms
) {
    CutoutGeometryContext c = cutoutContext(
        params, uniforms.motion, uniforms.state, uniforms.reaction,
        uniforms.geometry, uniforms.texture
    );
    float lower = smoothstep(0.35, 0.96, c.uv.y);
    float upperBody = 1.0 - smoothstep(0.0, 0.65, c.uv.y);
    float left = lower * smoothstep(0.05, 0.75, -c.centered.x);
    float right = lower * smoothstep(0.05, 0.75, c.centered.x);
    float cadence = behaviorCadence(c.behavior, 1.0, 1.2, 0.75, 0.55);
    float amplitude = behaviorAmplitude(c.behavior, 1.0, 1.2, 0.55, 0.25)
        * localReactionBoost(c);
    float stride = sin(c.phase * cadence);
    float active = stride >= 0.0 ? left : right;
    float alternate = stride >= 0.0 ? right : left;
    float3 offset = float3(0.0);
    offset.y += alternate * abs(stride) * c.height * 0.025 * amplitude;
    offset.x += stride * lower * c.width * 0.030 * amplitude;
    offset.x -= stride * upperBody * c.width * 0.015 * amplitude;
    offset.z += stride * upperBody * c.width * 0.008 * amplitude;
    offset.y *= 1.0 - active * c.contact;

    if (c.behavior > 0.5 && c.behavior < 1.5) {
        offset.x += upperBody * c.width * 0.010 * (0.5 + 0.5 * stride);
    }
    if (c.reactionStrength > 0.0) {
        float quickStep = sin(c.reactionProgress * M_PI_F * 4.0)
            * (1.0 - c.reactionProgress);
        offset.y += abs(quickStep) * lower * c.height * 0.012;
        offset.x += quickStep * lower * c.width * 0.007;
    }
    setCutoutOffset(params, offset, c, 0.045);
}

[[stitchable]]
void stompGeometryModifier(
    realitykit::geometry_parameters params,
    constant StompGeometryUniforms &uniforms
) {
    CutoutGeometryContext c = cutoutContext(
        params, uniforms.motion, uniforms.state, uniforms.reaction,
        uniforms.geometry, uniforms.texture
    );
    float lower = smoothstep(0.40, 0.96, c.uv.y);
    float body = smoothstep(0.05, 0.55, c.uv.y)
        * smoothstep(0.98, 0.55, c.uv.y);
    float cadence = behaviorCadence(c.behavior, 1.0, 1.1, 0.75, 0.50);
    float amplitude = behaviorAmplitude(c.behavior, 1.0, 1.2, 0.55, 0.25)
        * localReactionBoost(c);
    float transfer = sin(c.phase * cadence);
    float impact = exp(-c.contactProgress * 7.0) * c.contact;
    float recovery = sin(c.contactProgress * M_PI_F * 2.0)
        * exp(-c.contactProgress * 4.0);
    float3 offset = float3(0.0);
    float squash = min(impact + abs(transfer) * 0.35, 1.0);
    offset.y += c.centered.y * body * c.height * 0.040 * squash * amplitude;
    offset.x += c.centered.x * body * c.width * 0.020 * squash * amplitude;
    offset.z += body * c.width * 0.020
        * (transfer * 0.55 + recovery * 0.45) * amplitude;

    if (c.reactionStrength > 0.0) {
        float heavyStep = sin(c.reactionProgress * M_PI_F)
            * (1.0 - c.reactionProgress * 0.35);
        offset.y += lower * heavyStep * c.height * 0.015;
        offset.z += body * heavyStep * c.width * 0.010;
    }
    setCutoutOffset(params, offset, c, 0.045);
}

[[stitchable]]
void waddleGeometryModifier(
    realitykit::geometry_parameters params,
    constant WaddleGeometryUniforms &uniforms
) {
    CutoutGeometryContext c = cutoutContext(
        params, uniforms.motion, uniforms.state, uniforms.reaction,
        uniforms.geometry, uniforms.texture
    );
    float lower = smoothstep(0.48, 0.96, c.uv.y);
    float corner = lower * smoothstep(0.20, 0.82, abs(c.centered.x));
    float centerProtection = smoothstep(0.16, 0.46, abs(c.centered.x));
    float cadence = behaviorCadence(c.behavior, 1.0, 1.2, 0.75, 0.55);
    float amplitude = behaviorAmplitude(c.behavior, 1.0, 1.2, 0.55, 0.30)
        * localReactionBoost(c);
    float sway = sin(c.phase * cadence);
    float activeCorner = corner * (sway * c.centered.x > 0.0 ? 1.0 : 0.35);
    float lateralWeight = mix(0.19, 1.0, centerProtection);
    float3 offset = float3(0.0);
    offset.x += sway * lateralWeight * c.width * 0.035 * amplitude;
    offset.y += activeCorner * abs(sway) * c.height * 0.030 * amplitude;
    offset.z += sway * corner * centerProtection * c.width * 0.004;
    offset.x += c.steering * lower * centerProtection * c.width * 0.0025;

    if (c.behavior > 0.5 && c.behavior < 1.5) {
        offset.y += abs(sway) * lower * c.height * 0.007;
    }
    if (c.reactionStrength > 0.0) {
        float doubleWaddle = sin(c.reactionProgress * M_PI_F * 4.0)
            * (1.0 - c.reactionProgress);
        offset.x += doubleWaddle * centerProtection * c.width * 0.012;
        offset.y += abs(doubleWaddle) * corner * c.height * 0.007;
    }
    setCutoutOffset(params, offset, c, 0.045);
}

[[stitchable]]
void hopGeometryModifier(
    realitykit::geometry_parameters params,
    constant HopGeometryUniforms &uniforms
) {
    CutoutGeometryContext c = cutoutContext(
        params, uniforms.motion, uniforms.state, uniforms.reaction,
        uniforms.geometry, uniforms.texture
    );
    float lower = smoothstep(0.38, 0.96, c.uv.y);
    float centeredY = c.uv.y * 2.0 - 1.0;
    float cadence = behaviorCadence(c.behavior, 1.0, 1.0, 0.75, 0.55);
    float amplitude = behaviorAmplitude(c.behavior, 1.0, 1.0, 0.55, 0.28);
    float3 offset = float3(0.0);

    if (c.behavior > 0.5 && c.behavior < 1.5) {
        float p = c.behaviorProgress;
        if (p < 0.18) {
            float anticipation = smoothstep(0.0, 0.18, p);
            offset.y += centeredY * c.height * 0.070 * anticipation;
            offset.x += c.centered.x * lower * c.width * 0.030 * anticipation;
        } else if (p < 0.38) {
            float takeoff = sin((p - 0.18) / 0.20 * M_PI_F);
            offset.y -= centeredY * c.height * 0.060 * takeoff;
        } else if (p < 0.62) {
            float apex = sin((p - 0.38) / 0.24 * M_PI_F);
            offset.z += apex * (1.0 - abs(c.centered.x)) * c.width * 0.006;
        } else if (p < 0.82) {
            float landing = smoothstep(0.62, 0.82, p);
            offset.y += centeredY * c.height * 0.060 * landing;
            offset.x += c.centered.x * lower * c.width * 0.025 * landing;
        } else {
            float recovery = (p - 0.82) / 0.18;
            float settle = sin(recovery * M_PI_F * 2.0) * (1.0 - recovery);
            offset.y += centeredY * c.height * 0.020 * settle;
        }
    } else {
        float weightShift = sin(c.phase * cadence);
        offset.x += weightShift * lower * c.width * 0.012 * amplitude;
        offset.y += max(weightShift, 0.0) * lower * c.height * 0.008 * amplitude;
        offset.z += weightShift * (1.0 - lower * 0.4) * c.width * 0.006 * amplitude;
    }
    setCutoutOffset(params, offset * localReactionBoost(c), c, 0.045);
}

[[stitchable]]
void slitherGeometryModifier(
    realitykit::geometry_parameters params,
    constant SlitherGeometryUniforms &uniforms
) {
    CutoutGeometryContext c = cutoutContext(
        params, uniforms.motion, uniforms.state, uniforms.reaction,
        uniforms.geometry, uniforms.texture
    );
    float rear = 1.0 - c.orientedU;
    float flexibility = mix(0.25, 1.0, smoothstep(0.0, 0.80, rear));
    float cadence = behaviorCadence(c.behavior, 1.0, 1.35, 0.75, 0.60);
    float amplitude = behaviorAmplitude(c.behavior, 1.0, 1.2, 0.55, 0.35)
        * localReactionBoost(c);
    float wave = sin(c.orientedU * 12.0 - c.phase * cadence);
    float secondary = sin(c.orientedU * 7.0 - c.phase * cadence * 1.7);
    float3 offset = float3(0.0);
    offset.x += wave * flexibility * c.width * 0.050 * amplitude;
    offset.z += wave * flexibility * c.width * 0.040 * amplitude;
    if (c.behavior > 0.5 && c.behavior < 1.5) {
        offset.z += secondary * flexibility * c.width * 0.006;
    }
    offset.y += max(wave, 0.0) * flexibility * c.height * 0.004;

    if (c.reactionStrength > 0.0) {
        float recoil = 1.0 - smoothstep(0.0, 0.28, c.reactionProgress);
        float forwardWave = c.reactionProgress >= 0.28
            ? sin((c.reactionProgress - 0.28) * M_PI_F * 2.0)
                * (1.0 - c.reactionProgress)
            : 0.0;
        offset.x -= c.orientedX * recoil * c.width * 0.018;
        offset.z += forwardWave * flexibility * c.width * 0.020;
    }
    setCutoutOffset(params, offset, c, 0.045);
}

[[stitchable]]
void crawlGeometryModifier(
    realitykit::geometry_parameters params,
    constant CrawlGeometryUniforms &uniforms
) {
    CutoutGeometryContext c = cutoutContext(
        params, uniforms.motion, uniforms.state, uniforms.reaction,
        uniforms.geometry, uniforms.texture
    );
    float lower = smoothstep(0.55, 0.96, c.uv.y);
    float centerProtection = mix(0.35, 1.0, lower);
    float cadence = behaviorCadence(c.behavior, 1.0, 1.3, 0.75, 0.55);
    float amplitude = behaviorAmplitude(c.behavior, 1.0, 1.2, 0.55, 0.30)
        * localReactionBoost(c);
    float bands = sin(c.orientedU * M_PI_F * 8.0 + c.phase * cadence);
    float3 offset = float3(0.0);
    offset.x += bands * lower * c.width * 0.025 * amplitude;
    offset.y += max(bands, 0.0) * lower * (1.0 - c.contact * 0.8)
        * c.height * 0.015 * amplitude;
    offset.z += sin(c.phase * cadence * 0.55) * centerProtection
        * c.width * 0.008 * amplitude;
    if (c.behavior > 0.5 && c.behavior < 1.5) {
        offset.x += sin(c.orientedU * 6.0 - c.phase) * lower * c.width * 0.004;
    }
    if (c.reactionStrength > 0.0) {
        float burst = sin(c.reactionProgress * M_PI_F * 5.0)
            * (1.0 - c.reactionProgress);
        offset.x += burst * lower * c.width * 0.009;
    }
    setCutoutOffset(params, offset, c, 0.045);
}

[[stitchable]]
void scuttleGeometryModifier(
    realitykit::geometry_parameters params,
    constant ScuttleGeometryUniforms &uniforms
) {
    CutoutGeometryContext c = cutoutContext(
        params, uniforms.motion, uniforms.state, uniforms.reaction,
        uniforms.geometry, uniforms.texture
    );
    float outer = smoothstep(0.45, 0.92, abs(c.centered.x));
    float lower = smoothstep(0.45, 0.96, c.uv.y);
    float edge = max(outer, lower * outer);
    float shell = 1.0 - smoothstep(0.45, 0.72, abs(c.centered.x));
    float cadence = behaviorCadence(c.behavior, 1.0, 1.45, 0.75, 0.65);
    float amplitude = behaviorAmplitude(c.behavior, 1.0, 1.2, 0.55, 0.30)
        * localReactionBoost(c);
    float step = sin(c.phase * cadence + abs(c.centered.x) * M_PI_F);
    float3 offset = float3(0.0);
    offset.x += step * edge * c.width * 0.030 * amplitude;
    offset.y += max(step, 0.0) * lower * outer * c.height * 0.015 * amplitude;
    offset.z += sin(c.phase * 0.28) * shell * c.width * 0.003;
    offset.x += c.steering * edge * sign(c.centered.x) * c.width * 0.006;
    offset.z += c.steering * shell * c.width * 0.005;
    if (c.reactionStrength > 0.0) {
        float escape = sin(c.reactionProgress * M_PI_F)
            * (1.0 - c.reactionProgress * 0.35);
        offset.x += escape * edge * c.width * 0.020;
        offset.z += sin(c.reactionProgress * M_PI_F * 3.0)
            * shell * (1.0 - c.reactionProgress) * c.width * 0.006;
    }
    setCutoutOffset(params, offset, c, 0.045);
}

[[stitchable]]
void genericGeometryModifier(
    realitykit::geometry_parameters params,
    constant GenericGeometryUniforms &uniforms
) {
    CutoutGeometryContext c = cutoutContext(
        params, uniforms.motion, uniforms.state, uniforms.reaction,
        uniforms.geometry, uniforms.texture
    );
    float radial = max(1.0 - dot(c.centered, c.centered) * 0.45, 0.0);
    float cadence = behaviorCadence(c.behavior, 1.0, 1.2, 0.75, 0.60);
    float amplitude = behaviorAmplitude(c.behavior, 1.0, 1.2, 0.55, 0.30)
        * localReactionBoost(c);
    float bend = sin(c.phase * cadence + c.centered.y * 0.8 + c.irregularity * 0.15);
    float breathing = sin(c.phase * 0.35);
    float3 offset = float3(0.0);
    offset.x += bend * radial * c.width * 0.015 * amplitude;
    offset.z += bend * radial * c.width * 0.020 * amplitude;
    offset.z += breathing * radial * c.width * 0.0035;
    offset.z += c.steering * c.orientedX * c.width * 0.004;
    if (c.behavior > 0.5 && c.behavior < 1.5) {
        offset.y += c.centered.y * sin(c.phase * 1.2) * c.height * 0.004;
    }
    if (c.reactionStrength > 0.0) {
        float perk = reactionEnvelope(c.reactionProgress);
        offset.y += c.centered.y * perk * c.height * 0.010;
        offset.z += sin(c.reactionProgress * M_PI_F * 2.0)
            * radial * (1.0 - c.reactionProgress) * c.width * 0.010;
    }
    setCutoutOffset(params, offset, c, 0.045);
}
