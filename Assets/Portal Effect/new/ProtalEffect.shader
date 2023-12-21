Shader "Unlit/ProtalEffect"
{
    Properties
    {
        _Intensity("Intensity", Range(0,10)) = 5.0
	
		[Header(Movement)]
		_SpeedX("Speed X", Range(-5,5)) = 1.0
		_SpeedY("Speed Y", Range(-5,5)) = 1.0
		_RadialScale("Radial Scale", Range(0,10)) = 1.0
		_LengthScale("Length Scale", Range(0,10)) = 1.0
		_MovingTex ("MovingTex", 2D) = "white" {}
		_Multiply("Multiply Moving", Range(0,10)) = 1.0
		
		[Header(Shape)]
		_ShapeTex("Shape Texture", 2D) = "white" {}
		_ShapeTexIntensity("Shape tex intensity", Range(0,6)) = 0.5
		
		[Header(Gradient Coloring)]
		_Gradient("Gradient Texture", 2D) = "white" {}
		_Stretch("Gradient Stretch", Range(-2,10)) = 1.0
		_Offset("Gradient Offset", Range(-2,10)) = 1.0

		[Header(Cutoff)]	
		_Cutoff("Outside Cutoff", Range(0,1)) = 1.0
		_Smoothness("Outside Smoothness", Range(0,1)) = 1.0
    	
    	_Tint("Tint", Color) = (1,1,1,1)
    }
    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalRenderPipeline" "Queue" = "Geometry+1" }
        
        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float _Cutoff, _Smoothness;
		float _SpeedX, _SpeedY;
		float _ShapeTexIntensity;
		float _Stretch,_Multiply;
		float _Intensity,_Offset;
		float _RadialScale, _LengthScale;
        float4 _Tint;
        CBUFFER_END

        TEXTURE2D(_MovingTex);  SAMPLER(sampler_MovingTex);
        TEXTURE2D(_ShapeTex);   SAMPLER(sampler_ShapeTex);
        TEXTURE2D(_Gradient);   SAMPLER(sampler_Gradient);

        struct Attributes
		{
			float4 positionOS : POSITION;
			float2 uv : TEXCOORD0;
			UNITY_VERTEX_INPUT_INSTANCE_ID
		};

        struct Varyings
		{
			float4 positionCS : SV_POSITION;
			float2 uv : TEXCOORD0;
			UNITY_VERTEX_INPUT_INSTANCE_ID
			UNITY_VERTEX_OUTPUT_STEREO
		};

        Varyings vert(Attributes input)
		{
			Varyings output = (Varyings)0;

			UNITY_SETUP_INSTANCE_ID(input);
			UNITY_TRANSFER_INSTANCE_ID(input, output);
			UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

			output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
			output.uv = input.uv;
			return output;
		}

        // 极坐标
        float2 Unity_PolarCoordinates(float2 UV, float2 Center, float RadialScale, float LengthScale)
		{
			float2 delta = UV - Center;
			float radius = length(delta) * 2.0 * RadialScale;
			float angle = atan2(delta.y, delta.x) * 1.0 / 6.28318 * LengthScale;
			return float2(radius, angle);
		}

        float GetFinalDistortion(float2 uvProj, float shapeTex)
		{
			float2 polarUV = Unity_PolarCoordinates(uvProj, float2(0.5, 0.5), _RadialScale, _LengthScale);

			// move UV
			float2 movingUV = float2(polarUV.x + (_Time.x * _SpeedX), polarUV.y + (_Time.x * _SpeedY));


			// final moving texture with the distortion
			half4 final = SAMPLE_TEXTURE2D(_MovingTex, sampler_MovingTex, movingUV).r;

			shapeTex *= _ShapeTexIntensity;
			final *= shapeTex;
			return final;
		}

        ENDHLSL

        Pass 
        {
        	Name "ProtalStencilMask"
            Tags { "LightMode" = "SRPDefaultUnlit" }

            ZWrite Off
            Cull Back
            ColorMask 0
            
            Stencil
            {
                comp Always
                ref 1
                pass replace
            }

            HLSLPROGRAM
            #pragma multi_compile_instancing
            
            #pragma vertex vert
            #pragma fragment frag

            half4 frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                
                half shapeTex = SAMPLE_TEXTURE2D(_ShapeTex, sampler_ShapeTex, input.uv).r;
            	float vortexEffect = GetFinalDistortion(input.uv, shapeTex);

				clip(vortexEffect - 0.3);

                return half4(1, 0, 0, 0);
            }
            ENDHLSL
        }

		Pass
		{
			Name "ProtalEffect"
			Tags{ "RenderType" = "Transparent" "LightMode" = "UniversalForward" "Queue" = "Transparent+1" }

			ZWrite Off
			Ztest Off
			Cull Back
			Blend OneMinusDstColor One

			HLSLPROGRAM
			#pragma multi_compile_instancing

			#pragma vertex vert
			#pragma fragment frag

			half4 frag(Varyings input) : SV_Target
			{
				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

				half shapeTex = SAMPLE_TEXTURE2D(_ShapeTex, sampler_ShapeTex, input.uv).r;
				float vortexEffect = GetFinalDistortion(input.uv, shapeTex);

				// clip(vortexEffect - 0.1);

				float4 gradientMap = SAMPLE_TEXTURE2D(_Gradient, sampler_Gradient, (vortexEffect * _Stretch) + _Offset) * _Intensity;
				gradientMap *= vortexEffect;
				gradientMap *= _Tint;

				// add tinting and transparency
				gradientMap.rgb *= _Tint.rgb;
				gradientMap *= _Tint.a;
				gradientMap *= shapeTex;

				// create a cutoff point for the outside of the portal effect
				gradientMap *= smoothstep(_Cutoff - _Smoothness, _Cutoff, vortexEffect * _Multiply);
				// increase intensity
				gradientMap = saturate(gradientMap * 10) * _Intensity;
				return gradientMap;
				// return half4(1,1,1,1);
			}
			ENDHLSL
		}
	}
}