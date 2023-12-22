Shader "Unlit/HoleEffect"
{
    Properties
    {
        [MainTexture] _BaseMap("Texture", 2D) = "white" {}
        [MainColor] _BaseColor("Color", Color) = (1, 1, 1, 1)
        _NoiseTex("Noise", 2D) = "white" {}
        _NoiseFactor("Noise Factor", Vector) = (0.1, 0, 0.5, 0.5)
    }
    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalRenderPipeline" "Queue" = "Geometry+2" }

        Pass 
        {
            Tags { "LightMode" = "UniversalForward" }

            ZTest Off
            ZWrite On
            Cull Front

            Stencil
            {
                Ref 1
                Comp Equal
                Pass Zero
                fail Zero
                zfail Zero
            }

            HLSLPROGRAM
            #pragma multi_compile_instancing
            
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv         : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv         : TEXCOORD0;
                float4 ScreenPos : TEXCOORD1;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            CBUFFER_START(UnityPerMaterial)
            float4 _BaseMap_ST;
            half4 _BaseColor;
            float4 _NoiseFactor;
            float _Cutoff;
            CBUFFER_END

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            TEXTURE2D(_NoiseTex);
            SAMPLER(sampler_NoiseTex);

            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;

                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.ScreenPos = ComputeScreenPos(output.positionCS);
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                float2 uv = input.ScreenPos.xy / input.ScreenPos.w;
                float2 noiseUV = uv + _Time.y * _NoiseFactor.xy;
                float2 noise = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, noiseUV).rr * _NoiseFactor.zw;
                half4 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv + noise) * _BaseColor;

                return baseColor;
            }
            ENDHLSL
        }
    }
}
