// 镭射材质（薄膜干涉） 不透明
// 由两层颜色构成：从背后折射过来的光，和正面反射的光
// 折射光作为 Diffusion Color
// 反射光作为 Specular Color，修改 BRDF.hlsl 中的 InitializeBRDFData 函数
// 由于使用的是金属度粗糙度工作流，surfaceData 中的 specular 参数没有用，我们可以拿它来传参数
Shader "Custom/Laser-Opaque"
{
    Properties
    {
        [ToggleOff] _EnvironmentReflections("Environment Reflections", Float) = 1.0
        [Toggle(_LASER_OPAQUE)] _Laser("Opaque Laser", Float) = 1.0
        // _BaseMap("Base Map", 2D) = "white" {}
        
        _Metallic("Metallic", Range(0, 1)) = 1.0
        _Smoothness("Smoothness", Range(0, 1)) = 0.9
        
        [Header(Group 0)]
        [Space(5)]
        _LightSpan0("Light Span", Range(0.0, 1.0)) = 0.5     // 色相范围
        _LightOffset0("Light Offset", Range(0.0, 1.0)) = 0.0 // 色相偏移
        _Saturation0("Saturation", Range(0.0, 1.0)) = 0.5    // 饱和度
        _Brightness0("Brightness", Range(0.0, 1.0)) = 0.5    // 亮度
        
        [Header(Group 1)]
        [Space(5)]
        _LightSpan1("Light Span", Range(0.0, 1.0)) = 0.5
        _LightOffset1("Light Offset", Range(0.0, 1.0)) = 0.0
        _Saturation1("Saturation", Range(0.0, 1.0)) = 0.5
        _Brightness1("Brightness", Range(0.0, 1.0)) = 0.5
    }
    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalRenderPipeline"}

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        CBUFFER_START(UnityPerMaterial)
        // float4 _BaseMap_ST;

        float _LightSpan0;
        float _LightOffset0;
        float _Saturation0;
        float _Brightness0;

        float _LightSpan1;
        float _LightOffset1;
        float _Saturation1;
        float _Brightness1;

        float _Metallic;
        float _Smoothness;
        CBUFFER_END

        // 色相转RGB
        half3 HUEtoRGB(half H)
        {
            half R = abs(H * 6 - 3) - 1;
            half G = 2 - abs(H * 6 - 2);
            half B = 2 - abs(H * 6 - 4);
            return saturate(half3(R, G, B));
        }

        // HSV转RGB
        half3 HSVtoRGB(half3 HSV)
        {
            half3 RGB = HUEtoRGB(HSV.x);
            return ((RGB - 1) * HSV.y + 1) * HSV.z;
        }
        ENDHLSL
        
        pass
        {
            Tags { "LightMode" = "UniversalForward" }
            
            ZWrite On
            Cull Back
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma shader_feature_local _LASER_OPAQUE
            #pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF
            // #pragma shader_feature_local _RECEIVE_SHADOWS_OFF
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fog

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float2 uv           : TEXCOORD0;
                float3 normalOS     : NORMAL;
            };

            struct Varyings
            {
                float4 positionCS   : SV_POSITION;
                float3 positionWS   : TEXCOORD0;
                float2 uv           : TEXCOORD1;
                float3 normalWS     : TEXCOORD2;
                half  fogFactor     : TEXCOORD3;

                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
                    float4 shadowCoord              : TEXCOORD4;
                #endif

                DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, vertexSH, 5);
            };

            void InitializeStandardLitSurfaceData(half3 diffusion, half3 specular, out SurfaceData outSurfaceData)
            {
                outSurfaceData = (SurfaceData)0;
                
                outSurfaceData.albedo = diffusion;
                outSurfaceData.specular = specular;
                outSurfaceData.metallic = _Metallic; // 金属度和粗糙度基本可以定死
                outSurfaceData.smoothness = _Smoothness;
                outSurfaceData.occlusion = 1.0;
                outSurfaceData.emission = 0.0;
            }

            void InitializeInputData(Varyings input, out InputData inputData, half3 viewDirWS, half3 normalWS)
            {
                inputData = (InputData)0;

                inputData.positionWS = input.positionWS;
                inputData.normalWS = normalWS;
                inputData.viewDirectionWS = viewDirWS;

                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
                    inputData.shadowCoord = input.shadowCoord;
                #elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
                    inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
                #else
                    inputData.shadowCoord = float4(0, 0, 0, 0);
                #endif

                inputData.fogCoord = InitializeInputDataFog(float4(input.positionWS, 1.0), input.fogFactor);

                inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.vertexSH, inputData.normalWS);

                inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
                inputData.shadowMask = SAMPLE_SHADOWMASK(input.staticLightmapUV);
            }

            Varyings vert(Attributes v)
            {
                Varyings o;

                VertexPositionInputs vertexInput = GetVertexPositionInputs(v.positionOS.xyz);
                o.positionCS = vertexInput.positionCS;
                o.positionWS = vertexInput.positionWS;
                // o.uv = TRANSFORM_TEX(v.uv, _BaseMap);
                o.uv = v.uv;
                o.normalWS = TransformObjectToWorldNormal(v.normalOS);

                half fogFactor = 0;
                #if !defined(_FOG_FRAGMENT)
                    fogFactor = ComputeFogFactor(vertexInput.positionCS.z);
                #endif
                o.fogFactor = fogFactor;

                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
                    o.shadowCoord = GetShadowCoord(vertexInput);
                #endif

                OUTPUT_LIGHTMAP_UV(i.staticLightmapUV, unity_LightmapST, o.staticLightmapUV);
                OUTPUT_SH(o.normalWS.xyz, o.vertexSH);
                
                return o;
            }

            half4 frag(Varyings i) : SV_Target
            {
                // half4 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv);

                half3 viewDirWS = GetWorldSpaceNormalizeViewDir(i.positionWS);
                half3 normalWS = NormalizeNormalPerPixel(i.normalWS);

                half VdotN = dot(viewDirWS, normalWS);

                half hue0 = (half(1.0) - VdotN) * _LightSpan0 + _LightOffset0;
                half3 hsv0 = half3(hue0, _Saturation0, _Brightness0);
                half3 rgb0 = HSVtoRGB(hsv0);

                half3 rgb1 = half3(0, 0, 0);
            // #ifdef _SPECULAR_SETUP
                half hue1 = (half(1.0) - VdotN) * _LightSpan1 + _LightOffset1;
                half3 hsv1 = half3(hue1, _Saturation1, _Brightness1);
                rgb1 = HSVtoRGB(hsv1);
            // #endif

                SurfaceData surfaceData;
                InitializeStandardLitSurfaceData(rgb0, rgb1, surfaceData);

                InputData inputData;
                InitializeInputData(i, inputData, viewDirWS, normalWS);

                half4 color = UniversalFragmentPBR(inputData, surfaceData);

                color.rgb = MixFog(color.rgb, inputData.fogCoord);

                return half4(color.rgb, 1.0);
            }

            ENDHLSL
        }
    }
}
