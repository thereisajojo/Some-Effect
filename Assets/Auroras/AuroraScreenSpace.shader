Shader "Hidden/AuroraScreenSpace"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        
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
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
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

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                return o;
            }

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            half4 frag (v2f i) : SV_Target
            {
                float2 UV = i.vertex.xy / _ScaledScreenParams.xy;

                // Sample the depth from the Camera depth texture.
                #if UNITY_REVERSED_Z
                    real depth = SampleSceneDepth(UV);
                #else
                    // Adjust Z to match NDC for OpenGL ([-1, 1])
                    real depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(UV));
                #endif

                if(depth > 0.0001)
                {
                    return SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                }

                i.uv = i.uv - 0.5;
                float p = normalize(i.uv).y;
                float p1 = 1.0f - pow (min (1.0f, 1.0f - p), _Exponent1);
                float p3 = 1.0f - pow (min (1.0f, 1.0f + p), _Exponent2);
                float p2 = 1.0f - p1 - p3;
                half4 skyCol = (_Color1 * p1 + _Color2 * p2 + _Color3 * p3) * _Intensity;

                return skyCol;
            }
            ENDHLSL
        }
    }
}
