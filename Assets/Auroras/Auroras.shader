Shader "Aurora/AuroraSky"
{
    Properties
    {
        [Header(Sky Setting)]
        _Color1 ("Top Color", Color) = (1, 1, 1, 0)
        _Color2 ("Horizon Color", Color) = (1, 1, 1, 0)
        _Color3 ("Bottom Color", Color) = (1, 1, 1, 0)
        _Exponent1 ("Exponent Factor for Top Half", Float) = 1.0
        _Exponent2 ("Exponent Factor for Bottom Half", Float) = 1.0
        _Intensity ("Intensity Amplifier", Float) = 1.0


        [Header(Star Setting)]
        [HDR]_StarColor ("Star Color", Color) = (1,1,1,0)
        _StarIntensity("Star Intensity", Range(0,1)) = 0.5
        _StarSpeed("Star Speed", Range(0,1)) = 0.5

        [Header(Cloud Setting)]
        [HDR]_CloudColor ("Cloud Color", Color) = (1,1,1,0)
        _CloudIntensity("Cloud Intensity", Range(0,1)) = 0.5
        _CloudSpeed("CloudSpeed", Range(0,1)) = 0.5

        [Header(Aurora Setting)]
        [HDR]_AuroraColor ("Aurora Color", Color) = (1,1,1,0)
        _AuroraIntensity("Aurora Intensity", Range(0,1)) = 0.5
        _AuroraSpeed("AuroraSpeed", Range(0,1)) = 0.5
        _SurAuroraColFactor("Sur Aurora Color Factor", Range(0,1)) = 0.5

        [Header(Envirment Setting)]
        [HDR]_MountainColor ("Mountain Color", Color) = (1,1,1,0)
        _MountainFactor("Mountain Factor", Range(0,1)) = 0.5
        _MountainHeight("Mountain Height", Range(0,2)) = 0.5
    }
    
    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalRenderPipeline" }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        ENDHLSL

        Pass {
            Tags { "LightMode" = "UniversalForward" }

            ZWrite On
            Cull Off

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float2 texcoord     : TEXCOORD0;
                float3 normal       : NORMAL;
            };

            struct Varyings
            {
                float4 positionCS   : SV_POSITION;
                float2 texcoord     : TEXCOORD0;
                float3 positionWS   : TEXCOORD1;
                float3 positionOS   : TEXCOORD2; 
            };

            // 环境背景颜色
            half4 _Color1;
            half4 _Color2;
            half4 _Color3;
            half _Intensity;
            half _Exponent1;
            half _Exponent2;

            //星星 
            half4 _StarColor;
            half _StarIntensity;
            half _StarSpeed;

            // 云
            half4 _CloudColor;
            half _CloudIntensity;
            half _CloudSpeed;

            // 极光
            half4 _AuroraColor;
            half _AuroraIntensity;
            half _AuroraSpeed;
            half _SurAuroraColFactor;
            
            // 远景山
            half4 _MountainColor;
            float _MountainFactor;
            half _MountainHeight;

            Varyings vert(Attributes v)
            {
                Varyings o;

                VertexPositionInputs vertexInput = GetVertexPositionInputs(v.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(v.normal);
                o.positionOS = v.positionOS;
                o.positionWS = vertexInput.positionWS;
                o.positionCS = vertexInput.positionCS;
                o.texcoord = v.texcoord;
                return o;
            }

            // 星空散列哈希
            float StarAuroraHash(float3 x)
            {
                float3 p = float3(dot(x, float3(214.1, 127.7, 125.4)),
                                  dot(x, float3(260.5, 183.3, 954.2)),
                                  dot(x, float3(209.5, 571.3, 961.2)));

                return -0.001 + _StarIntensity * frac(sin(p) * 43758.5453123);
            }

            // 星空噪声
            float StarNoise(float3 st)
            {
                // 卷动星空
                st += float3(0, _Time.y * _StarSpeed, 0);

                // fbm
                float3 i = floor(st);
                float3 f = frac(st);

                float3 u = f * f * (3.0 - 1.0 * f);

                return lerp(lerp(dot(StarAuroraHash(i + float3(0.0, 0.0, 0.0)), f - float3(0.0, 0.0, 0.0)),
                                 dot(StarAuroraHash(i + float3(1.0, 0.0, 0.0)), f - float3(1.0, 0.0, 0.0)), u.x),
                            lerp(dot(StarAuroraHash(i + float3(0.0, 1.0, 0.0)), f - float3(0.0, 1.0, 0.0)),
                                 dot(StarAuroraHash(i + float3(1.0, 1.0, 0.0)), f - float3(1.0, 1.0, 0.0)), u.y), u.z);
            }

            // 云散列哈希
            float CloudHash (float2 st)
            {
                return frac(sin(dot(st.xy, float2(12.9898, 78.233))) * 43758.5453123);
            }

            // 云噪声
            float CloudNoise (float2 st,int flow)
            {
                // 云卷动
                st += float2(0, _Time.y * _CloudSpeed * flow);

                float2 i = floor(st);
                float2 f = frac(st);

                float a = CloudHash(i);
                float b = CloudHash(i + float2(1.0, 0.0));
                float c = CloudHash(i + float2(0.0, 1.0));
                float d = CloudHash(i + float2(1.0, 1.0));

                float2 u = f * f * (3.0 - 2.0 * f);

                return lerp(a, b, u.x) + (c - a)* u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
            }

            // 云分型
            float CloudFbm (float2 st,int flow)
            {
                float value = 0.0;
                float amplitude = 0.5;
                float frequency = 0.0;

                for (int i = 0; i < 6; i++)
                {
                    value += amplitude * CloudNoise(st, flow);
                    st *= 2.;
                    amplitude *= .5;
                }
                return value;
            }
            
            half4 frag(Varyings i) : SV_Target
            {
                // float p = normalize(i.texcoord).y;
                float p = i.positionOS.y;
                float p1 = 1.0f - pow (min (1.0f, 1.0f - p), _Exponent1);
                float p3 = 1.0f - pow (min (1.0f, 1.0f + p), _Exponent2);
                float p2 = 1.0f - p1 - p3;
                int reflection = p < 0 ? -1 : 1;
                
                // 星星
                float star = StarNoise(float3(i.positionOS.x, i.positionOS.y * reflection, i.positionOS.z) * 64);
                float4 starOriCol = float4(_StarColor.r + 3.25 * sin(i.positionOS.x) + 2.45 * (sin(_Time.y * _StarSpeed) + 1) * 0.5,
                                           _StarColor.g + 3.85 * sin(i.positionOS.y) + 1.45 * (sin(_Time.y * _StarSpeed) + 1) * 0.5,
                                           _StarColor.b + 3.45 * (i.positionOS.z) + 4.45 * (sin(_Time.y * _StarSpeed) + 1) * 0.5,
                                           _StarColor.a + 3.85 * star);
                star = star > 0.8 ? star : smoothstep(0.81, 0.98, star);
                float4 starCol = half4((starOriCol * star).rgb, star);
                // return starCol;

                //混合
                float4 skyCol = (_Color1 * p1 + _Color2 * p2 + _Color3 * p3) * _Intensity;
                starCol = reflection == 1 ? starCol : starCol * 0.5;
                skyCol = lerp(skyCol, starCol, starCol.a);
                return skyCol;
            }
            ENDHLSL
        }
    }
}