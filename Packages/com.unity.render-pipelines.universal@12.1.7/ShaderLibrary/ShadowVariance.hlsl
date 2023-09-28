#ifndef _VARIANCE_SHADOW_INCLUDED
#define _VARIANCE_SHADOW_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"

float4x4 _StaticSoftWorldToMainLightMatrix; // 软阴影变换矩阵
float    _MinVariance; // 最小方差，用于消除伪影
float    _BleedingValue; // 用于消除漏光的值
float    _MaxDistance;

TEXTURE2D(_VarianceShadowMap);
SAMPLER(sampler_VarianceShadowMap);

// Where to split the value. 8 bits works well for most situations.
float linStep(float min, float max, float v)
{
    return clamp((v - min) / (max - min), 0, 1);
}

// 减少光渗(Light Bleeding)，去除[0, Amount]的尾部，并线性缩放(Amount, 1].
// Amount参数是可编辑的，可以有效地设置漏光的强度。它与场景尺度无关，但漏光较多的场景通常需要较高的值。
// 最优设置与场景中遮挡物和接收阴影物的深度比有关。这个参数需要注意，因为设置太高会减少阴影细节。
float ReduceLightBleeding(float p_max, float Amount)
{
    return linStep(Amount, 1, p_max);
} 

// 切比雪夫
float ChebyshevUpperBound(float2 Moments, float t, float minVariance)
{
    // 深度比期望值小，认为没有被遮挡，返回1
    float p = t <= Moments.x;
    // Compute variance.
    float Variance = Moments.y - Moments.x * Moments.x;
    Variance = max(Variance, minVariance);
    // Compute probabilistic upper bound.
    float d = t - Moments.x;
    float p_max = Variance / (Variance + d*d);
    p_max = ReduceLightBleeding(p_max, _BleedingValue);
    return max(p, p_max);
}

half StaticSoftShadow(float depth, float2 moments)
{
    half shadow = ChebyshevUpperBound(moments, depth, _MinVariance);
    half shadowStrength = GetMainLightShadowParams().x;
    shadow = LerpWhiteTo(shadow, shadowStrength);
    return shadow;
}

void GetShadowUVAndDepth(float4x4 lightMatrix, float3 positionWS, out float2 shadowUV, out float depth)
{
    float4 shadowCoord = mul(lightMatrix, float4(positionWS, 1.0f));
    shadowUV = shadowCoord.xy / shadowCoord.w;
    shadowUV = shadowUV * 0.5 + 0.5;
    depth = shadowCoord.z / shadowCoord.w;
    depth = depth * 0.5 + 0.5;
}

half MainLightShadow(float3 positionWS)
{
    // half realtimeShadow = MainLightRealtimeShadow(shadowCoord);

    float2 softShadowUV;
    float softDepth;
    GetShadowUVAndDepth(_StaticSoftWorldToMainLightMatrix, positionWS, softShadowUV, softDepth);

    half2 depthResult = SAMPLE_TEXTURE2D_LOD(_VarianceShadowMap, sampler_VarianceShadowMap, softShadowUV, 3).rg;
    half shadow = StaticSoftShadow(softDepth, depthResult);

    float dis = distance(positionWS, _WorldSpaceCameraPos);

    return dis > _MaxDistance ? half(1.0) : shadow;

// #ifdef MAIN_LIGHT_CALCULATE_SHADOWS
//     half shadowFade = GetMainLightShadowFade(positionWS);
// #else
//     half shadowFade = half(1.0);
// #endif
//
//     return MixRealtimeAndBakedShadows(shadow, 0, shadowFade);
}

#endif