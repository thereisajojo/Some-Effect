// 镭射材质（薄膜干涉）
// 由两层颜色构成：从背后折射过来的光，和正面反射的光
// 折射光会染上材质的颜色，混合模式用Multiply，没有光照，先渲染
// 反射的光线不会削弱背景的亮度，用Additive混合，并计算反射环境和高光，后渲染
// 颜色在色相上是连续变化的，并且两个部分的光线在色相盘上刚好是相反的方向，但是为了美术效果，两部分的色相可分别调整而不是绝对的相反
Shader "Custom/Laser"
{
    Properties
    {
        // [Header(Group 0)]
        // [Space(5)]
        _LightSpan0("Light Span", Range(0.0, 1.0)) = 0.5     // 色相范围
        _LightOffset0("Light Offset", Range(0.0, 1.0)) = 0.0 // 色相偏移
        _Saturation0("Saturation", Range(0.0, 1.0)) = 0.5    // 饱和度
        _Brightness0("Brightness", Range(0.0, 1.0)) = 0.5    // 亮度
        
        // [Header(Group 1)]
        // [Space(5)]
        _LightSpan1("Light Span", Range(0.0, 1.0)) = 0.5
        _LightOffset1("Light Offset", Range(0.0, 1.0)) = 0.0
        _Saturation1("Saturation", Range(0.0, 1.0)) = 0.5
        _Brightness1("Brightness", Range(0.0, 1.0)) = 0.5
        
        // [Space(10)]
        [Toggle(_ENABLE_FLOW)] _EnableFlow("Enable Flow", Float) = 0.0
        _FlowSpeed("Flow Speed", Float) = 0.1
        _BaseMap("Noise Map", 2D) = "black" {}
    }
    SubShader
    {
        Tags { "RenderType" = "Transparent" "RenderPipeline" = "UniversalRenderPipeline" "Queue" = "Transparent"}

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float4 _BaseMap_ST;

        float _LightSpan0;
        float _LightOffset0;
        float _Saturation0;
        float _Brightness0;
        float _FlowSpeed;

        float _LightSpan1;
        float _LightOffset1;
        float _Saturation1;
        float _Brightness1;
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

        // 染色层，无光照
        Pass 
        {
            // Tags { "LightMode" = "UniversalForward" }

            Blend DstColor Zero
            ZWrite Off
            Cull Back

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma shader_feature_local _ENABLE_FLOW

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float2 uv           : TEXCOORD0;
                float3 normalOS     : NORMAL;
            };

            struct Varyings
            {
                float4 positionCS   : SV_POSITION;
                float3 positionWS   : TEXCOORD2;
                float2 uv           : TEXCOORD0;
                float3 normalWS     : TEXCOORD1;
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            Varyings vert(Attributes v)
            {
                Varyings o;

                VertexPositionInputs vertexInput = GetVertexPositionInputs(v.positionOS.xyz);
                o.positionCS = vertexInput.positionCS;
                o.positionWS = vertexInput.positionWS;
                o.uv = TRANSFORM_TEX(v.uv, _BaseMap);
                o.normalWS = TransformObjectToWorldNormal(v.normalOS);
                
                return o;
            }

            half4 frag(Varyings i) : SV_Target
            {
                half hueOffset = half(0.0);
                #ifdef _ENABLE_FLOW
                half4 noise0 = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv + float2(_Time.y * _FlowSpeed, 0));
                half4 noise1 = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv + noise0.xy);
                hueOffset = noise1.r - 0.5; // 0~1 -> -0.5~0.5
                #endif

                half3 viewDirWS = GetWorldSpaceNormalizeViewDir(i.positionWS);
                half3 normalWS = normalize(i.normalWS);

                half VdotN = dot(viewDirWS, normalWS);
                half hue = (half(1.0) - VdotN) * _LightSpan0 + _LightOffset0 + hueOffset;
                hue = saturate(hue);
                half3 hsv = half3(hue, _Saturation0, _Brightness0);
                half3 rgb = HSVtoRGB(hsv);

                return half4(rgb, 1.0);
            }
            ENDHLSL
        }
        
        // 折射层，pbr光照
        pass
        {
            Tags { "LightMode" = "UniversalForward" }
            
            Blend One One
            ZWrite Off
            Cull Back
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

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

            void InitializeStandardLitSurfaceData(half3 laserColor, out SurfaceData outSurfaceData)
            {
                outSurfaceData = (SurfaceData)0;
                
                outSurfaceData.albedo = laserColor;
                outSurfaceData.specular = half3(0.0, 0.0, 0.0);
                outSurfaceData.metallic = 1.0; // 金属度和粗糙度基本可以定死
                outSurfaceData.smoothness = 0.9;
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
                o.uv = TRANSFORM_TEX(v.uv, _BaseMap);
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
                half3 viewDirWS = GetWorldSpaceNormalizeViewDir(i.positionWS);
                half3 normalWS = NormalizeNormalPerPixel(i.normalWS);

                half VdotN = dot(viewDirWS, normalWS);
                half hue = (half(1.0) - VdotN) * _LightSpan1 + _LightOffset1;
                half3 hsv = half3(hue, _Saturation1, _Brightness1);
                half3 rgb = HSVtoRGB(hsv);

                SurfaceData surfaceData;
                InitializeStandardLitSurfaceData(rgb, surfaceData);

                InputData inputData;
                InitializeInputData(i, inputData, viewDirWS, normalWS);

                half4 color = UniversalFragmentPBR(inputData, surfaceData);

                color.rgb = MixFog(color.rgb, inputData.fogCoord);

                return half4(color.rgb, 1.0);
            }

            ENDHLSL
        }
    }
    
    CustomEditor "LaserUI"
}
