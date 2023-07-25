Shader "Hidden/GlitchPostProcess"
{
    Properties
    {
        _MainTex("Base Map", 2D) = "white"
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }
        
        HLSLINCLUDE
        
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        
        struct Attributes
        {
            float4 positionOS   : POSITION;
            float2 uv           : TEXCOORD0;
        };

        struct Varyings
        {
            float4 positionHCS  : SV_POSITION;
            float2 uv           : TEXCOORD0;
        };

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

        Varyings vert(Attributes input)
        {
            Varyings output;
            output.positionHCS = TransformObjectToHClip(input.positionOS.xyz);
            output.uv = input.uv;
            return output;
        }       
        
        ENDHLSL

        // Pass 0, 结合RGB Split的错位图块故障（Image Block Glitch）
        Pass
        {
            Cull Off
            ZWrite Off
            ZTest Always
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            float _Speed;
            float2 _BlockSize;
            float _MaxRGBSplitX;
            float _MaxRGBSplitY;

            inline float randomNoise(float2 seed)
            {
                return frac(sin(dot(seed * floor(_Time.y * _Speed), float2(17.13, 3.71))) * 43758.5453123);
            }

            inline float randomNoise(float seed)
            {
                return randomNoise(float2(seed, 1.0));
            }

            half4 frag(Varyings input) : SV_Target
            {
                half2 block = randomNoise(floor(input.uv * _BlockSize));

                float displaceNoise = pow(block.x, 8.0) * pow(block.x, 3.0);
                float splitRGBNoise = pow(randomNoise(7.2341), 17.0);
                float offsetX = displaceNoise - splitRGBNoise * _MaxRGBSplitX;
                float offsetY = displaceNoise - splitRGBNoise * _MaxRGBSplitY;

                float noiseX = 0.05 * randomNoise(12.0);
                float noiseY = 0.05 * randomNoise(7.0);
                float2 offset = float2(offsetX * noiseX, offsetY* noiseY);

                half4 colorR = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
                half4 colorG = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv + offset);
                half4 colorB = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv - offset);

                return half4(colorR.r , colorG.g, colorB.z, (colorR.a + colorG.a + colorB.a));
            }
            ENDHLSL
        }
        
        // Pass 1, 扫描线抖动故障（Scan Line Jitter Glitch）
        Pass
        {
            Cull Off
            ZWrite Off
            ZTest Always
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            float2 _ScanLineJitter;

            float randomNoise(float x, float y)
            {
                return frac(sin(dot(float2(x, y), float2(12.9898, 78.233))) * 43758.5453);
            }

            half4 frag(Varyings input): SV_Target
            {
                float jitter = randomNoise(input.uv.y, _Time.x) * 2 - 1;
                jitter *= step(_ScanLineJitter.y, abs(jitter)) * _ScanLineJitter.x;

                half4 sceneColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, frac(input.uv + float2(jitter, 0)));

                return sceneColor;
            }
            
            ENDHLSL
        }
        
        // Pass 2, 错位线条故障（Line Block Glitch）
        Pass
        {
            Cull Off
            ZWrite Off
            ZTest Always
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            float _TimeX;
            float _Frequency;
            float _LinesWidth;
            float _Amount;
            float _Offset;
            float _Alpha;

            float randomNoise(float2 c)
	        {
		        return frac(sin(dot(c.xy, float2(12.9898, 78.233))) * 43758.5453);
	        }

            float trunc(float x, float num_levels)
	        {
		        return floor(x * num_levels) / num_levels;
	        }

            float2 trunc(float2 x, float2 num_levels)
	        {
		        return floor(x * num_levels) / num_levels;
	        }

            float3 rgb2yuv(float3 rgb)
	        {
		        float3 yuv;
		        yuv.x = dot(rgb, float3(0.299, 0.587, 0.114));
		        yuv.y = dot(rgb, float3(-0.14713, -0.28886, 0.436));
		        yuv.z = dot(rgb, float3(0.615, -0.51499, -0.10001));
		        return yuv;
	        }
	        
	        float3 yuv2rgb(float3 yuv)
	        {
		        float3 rgb;
		        rgb.r = yuv.x + yuv.z * 1.13983;
		        rgb.g = yuv.x + dot(float2(-0.39465, -0.58060), yuv.yz);
		        rgb.b = yuv.x + yuv.y * 2.03211;
		        return rgb;
	        }

            half4 frag(Varyings input): SV_Target
            {
                float2 uv = input.uv;
                half strength = 0.5 + 0.5 * cos(_Time.y  * _Frequency);

                _TimeX *= strength;
                float truncTime = trunc(_Time.y, 4.0);
                float uv_trunc = randomNoise(trunc(uv.yy, float2(8, 8)) + 100 * truncTime);
                float uv_randomTrunc = 6.0 * trunc(_Time.y, 24.0 * uv_trunc);

                float blockLine_random = 0.5 * randomNoise(trunc(uv.yy + uv_randomTrunc, float2(8 * _LinesWidth, 8 * _LinesWidth)));
                blockLine_random += 0.5 * randomNoise(trunc(uv.yy + uv_randomTrunc, float2(7, 7)));
                blockLine_random = blockLine_random * 2.0 - 1.0;
                blockLine_random = sign(blockLine_random) * saturate((abs(blockLine_random) - _Amount) / (0.4));
                blockLine_random = lerp(0, blockLine_random, _Offset);

                float2 uv_blockLine = uv;
                uv_blockLine = saturate(uv_blockLine + float2(0.1 * blockLine_random, 0));
                half4 blockLineColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, abs(uv_blockLine));

                half3 blockLineColor_yuv = rgb2yuv(blockLineColor.rgb);
                blockLineColor_yuv.y /= 1.0 - 3.0 * abs(blockLine_random) * saturate(0.5 - blockLine_random);
                blockLineColor_yuv.z += 0.125 * blockLine_random * saturate(blockLine_random - 0.5);
                half3 blockLineColor_rgb = yuv2rgb(blockLineColor_yuv);

                half4 sceneColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
                return lerp(sceneColor, half4(blockLineColor_rgb, blockLineColor.a), _Alpha);
            }
            
            ENDHLSL
        }
    }
}
