struct Attributes
{
    float4 positionOS         : POSITION;
    float3 normalOS           : NORMAL;
    // float4 tangentOS          : TANGENT;
    float2 texcoord           : TEXCOORD0;
    float2 staticLightmapUV   : TEXCOORD1;
    float2 dynamicLightmapUV  : TEXCOORD2;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 positionCS    : SV_POSITION;
    float4 uv            : TEXCOORD0;
    float3 positionWS    : TEXCOORD1;
    float3 normalWS      : TEXCOORD2;
    half  fogFactor      : TEXCOORD3;
#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    float4 shadowCoord   : TEXCOORD4;
#endif
    DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, vertexSH, 5);
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

void InitializeStandardLitSurfaceData(float2 uv, out SurfaceData outSurfaceData)
{
    half4 albedoAlpha = half4(SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv));
    half alpha = albedoAlpha.a * _Color.a;
    #if defined(_ALPHATEST_ON)
    clip(alpha - _Cutoff);
    #endif
    outSurfaceData.alpha = alpha;

    outSurfaceData.albedo = albedoAlpha.rgb * _Color.rgb;

    outSurfaceData.metallic = _Metallic;
    outSurfaceData.specular = half3(0.0, 0.0, 0.0);

    outSurfaceData.smoothness = _Glossiness;
    outSurfaceData.normalTS = half3(0.0h, 0.0h, 1.0h);
    outSurfaceData.occlusion = half(1.0h);
    outSurfaceData.emission = half3(0.0h, 0.0h, 0.0h);

    // #if defined(_CLEARCOAT) || defined(_CLEARCOATMAP)
    // half2 clearCoat = SampleClearCoat(uv);
    // outSurfaceData.clearCoatMask       = clearCoat.r;
    // outSurfaceData.clearCoatSmoothness = clearCoat.g;
    // #else
    outSurfaceData.clearCoatMask       = half(0.0);
    outSurfaceData.clearCoatSmoothness = half(0.0);
    // #endif

    // #if defined(_DETAIL)
    // half detailMask = SAMPLE_TEXTURE2D(_DetailMask, sampler_DetailMask, uv).a;
    // float2 detailUv = uv * _DetailAlbedoMap_ST.xy + _DetailAlbedoMap_ST.zw;
    // outSurfaceData.albedo = ApplyDetailAlbedo(detailUv, outSurfaceData.albedo, detailMask);
    // outSurfaceData.normalTS = ApplyDetailNormal(detailUv, outSurfaceData.normalTS, detailMask);
    // #endif
}

void InitializeInputData(Varyings input, half3 normalTS, out InputData inputData)
{
    inputData = (InputData)0;

    inputData.positionWS = input.positionWS;

    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);

    inputData.normalWS = input.normalWS;

    inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
    inputData.viewDirectionWS = viewDirWS;

#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    inputData.shadowCoord = input.shadowCoord;
#elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
    inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
#else
    inputData.shadowCoord = float4(0, 0, 0, 0);
#endif
    inputData.fogCoord = InitializeInputDataFog(float4(input.positionWS, 1.0), input.fogFactor);

    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
    inputData.shadowMask = SAMPLE_SHADOWMASK(input.staticLightmapUV);

    #if defined(DEBUG_DISPLAY)
    #if defined(LIGHTMAP_ON)
    inputData.staticLightmapUV = input.staticLightmapUV;
    #else
    inputData.vertexSH = input.vertexSH;
    #endif
    #endif
}

Varyings vert(Attributes input)
{
    Varyings output = (Varyings)0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    // 短绒毛
    half3 direction = lerp(input.normalOS, _Gravity * _GravityStrength + input.normalOS * (1 - _GravityStrength), _FUR_OFFSET);
    #ifdef _DEBUG_LAYERMAP
    direction = half3(0, 0, 0);
    #endif
    // 长毛
    float3 positionOS = input.positionOS.xyz + direction * _FurLength * _FUR_OFFSET;
    output.positionWS = TransformObjectToWorld(positionOS);
    output.positionCS = TransformWorldToHClip(output.positionWS);

    output.uv.xy = TRANSFORM_TEX(input.texcoord, _MainTex);
    output.uv.zw = TRANSFORM_TEX(input.texcoord, _LayerTex);
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS);
    output.normalWS = normalInput.normalWS;

    half fogFactor = 0;
    #if !defined(_FOG_FRAGMENT)
    fogFactor = ComputeFogFactor(vertexInput.positionCS.z);
    #endif
    output.fogFactor = fogFactor;

    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    #if defined(_MAIN_LIGHT_SHADOWS_SCREEN) && !defined(_SURFACE_TYPE_TRANSPARENT)
    output.shadowCoord = ComputeScreenPos(output.positionCS);
    #else
    output.shadowCoord = TransformWorldToShadowCoord(output.positionWS);
    #endif
    #endif

    OUTPUT_LIGHTMAP_UV(input.staticLightmapUV, unity_LightmapST, output.staticLightmapUV);
    OUTPUT_SH(output.normalWS.xyz, output.vertexSH);

    return output;
}

// 1.修改了原 UniversalFragmentPBR 函数，在末尾加上布料散射，类似于边缘光
// 2.修改 BRDF 中的 DirectBRDFSpecular，修改法线分布项D，因为布料高光正好相反，NoH越大高光反而越弱
half4 frag(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
    half3 normalWS = NormalizeNormalPerPixel(input.normalWS);
    half NdotV = dot(normalWS, viewDirWS);
    
    SurfaceData surfaceData;
    InitializeStandardLitSurfaceData(input.uv.xy, surfaceData);

    InputData inputData;
    InitializeInputData(input, surfaceData.normalTS, inputData);

    half4 color = UniversalFragmentPBR(inputData, surfaceData, _FabricScatterColor.rgb, _FabricScatterScale);
    color.rgb = color.rgb * lerp(lerp(_ShadowColor.rgb, 1, _FUR_OFFSET), 1, _ShadowLerp);

    float2 uvFlow = SAMPLE_TEXTURE2D(_FlowMap, sampler_FlowMap, input.uv.xy).rg * 2 - 1; // 0 ~ 1 -> -1 ~ 1
    half alpha = SAMPLE_TEXTURE2D(_LayerTex, sampler_LayerTex, input.uv.zw + _UVOffset * uvFlow * _FUR_OFFSET).r;
    alpha = step(lerp(0, _CutoffEnd, _FUR_OFFSET), alpha);
    alpha *= max(1 - _FUR_OFFSET * _FUR_OFFSET + NdotV - _EdgeFade, 0.0); // 1 - x²形状比较软润,更像皮毛

    color.rgb = MixFog(color.rgb, inputData.fogCoord);
    color.a = alpha;

    #ifdef _DEBUG_LAYERMAP
    color = SAMPLE_TEXTURE2D(_LayerTex, sampler_LayerTex, input.uv.zw);
    #endif

    return color;
}
